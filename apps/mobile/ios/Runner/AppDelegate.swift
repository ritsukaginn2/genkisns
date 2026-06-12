import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let cameraCapture = NativeCameraCapture()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Clean up pending camera result if app backgrounded while picker is open
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillBackground),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc private func appWillBackground() {
    cameraCapture.cancelPending()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "genki_sns/camera",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "capture" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.cameraCapture.capture(result: result)
    }

    let iCloudChannel = FlutterMethodChannel(
      name: "genki_sns/icloud",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    iCloudChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "containerPath":
        // url(forUbiquityContainerIdentifier:) may block while provisioning the
        // container — Apple forbids calling it on the main thread (watchdog kill).
        DispatchQueue.global(qos: .userInitiated).async {
          let url = FileManager.default.url(forUbiquityContainerIdentifier: nil)
          DispatchQueue.main.async {
            if let url = url {
              result(url.path)
            } else {
              result(FlutterError(code: "icloud_unavailable", message: "iCloud container is unavailable.", details: nil))
            }
          }
        }
      case "downloadBackup":
        let timeoutMillis = (call.arguments as? [String: Any])?["timeoutMillis"] as? Int ?? 20000
        ICloudBackupDownloader.download(timeoutMillis: timeoutMillis, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// iCloud Drive stores files lazily: after a reinstall (or once a file is
/// evicted) the backup exists in the cloud but only a placeholder is on disk, so
/// Dart's `File.exists()` returns false until the real contents are pulled down.
/// This forces the backup's gating files (and media) to download before Dart
/// reads them.
enum ICloudBackupDownloader {
  static func download(timeoutMillis: Int, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let fm = FileManager.default

      // Resolve the container off the main thread too — this call can block.
      guard let container = fm.url(forUbiquityContainerIdentifier: nil) else {
        DispatchQueue.main.async { result(false) }
        return
      }
      let backupRoot = container
        .appendingPathComponent("Documents", isDirectory: true)
        .appendingPathComponent("GenkiSNS", isDirectory: true)
        .appendingPathComponent("V1Backup", isDirectory: true)

      // The marker + database files gate whether a backup is considered valid,
      // so target them by their known logical paths (enumeration can surface
      // ".icloud" placeholders instead).
      let databaseDir = backupRoot.appendingPathComponent("database", isDirectory: true)
      let gatingFiles = [
        backupRoot.appendingPathComponent("backup.marker"),
        databaseDir.appendingPathComponent("genki_sns_v1.db"),
        databaseDir.appendingPathComponent("genki_sns_v1.db-wal"),
        databaseDir.appendingPathComponent("genki_sns_v1.db-shm"),
        databaseDir.appendingPathComponent("genki_sns_v1.db-journal"),
      ]
      let mediaDir = backupRoot.appendingPathComponent("post_media", isDirectory: true)

      func startDownloads() {
        for url in gatingFiles {
          try? fm.startDownloadingUbiquitousItem(at: url)
        }
        // mediaDir itself may be a placeholder — download it first before enumerating.
        try? fm.startDownloadingUbiquitousItem(at: mediaDir)
        if let enumerator = fm.enumerator(at: mediaDir, includingPropertiesForKeys: nil) {
          for case let url as URL in enumerator {
            try? fm.startDownloadingUbiquitousItem(at: url)
          }
        }
      }

      func isPending(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
              let status = values.ubiquitousItemDownloadingStatus else {
          // Item is not in iCloud (e.g. does not exist yet) — nothing to wait on.
          return false
        }
        return status != .current
      }

      func hasPending() -> Bool {
        for url in gatingFiles where isPending(url) {
          return true
        }
        if let enumerator = fm.enumerator(at: mediaDir, includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey, .isDirectoryKey]) {
          for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true { continue }
            if isPending(url) { return true }
          }
        }
        return false
      }

      let deadline = Date().addingTimeInterval(Double(timeoutMillis) / 1000.0)
      startDownloads()
      while Date() < deadline {
        if !hasPending() { break }
        startDownloads()
        Thread.sleep(forTimeInterval: 0.4)
      }
      DispatchQueue.main.async { result(true) }
    }
  }
}

final class NativeCameraCapture: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
  private var pendingResult: FlutterResult?

  func capture(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard self.pendingResult == nil else {
        result(FlutterError(code: "camera_busy", message: "Camera is already open.", details: nil))
        return
      }
      guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
        result(FlutterError(code: "camera_unavailable", message: "Camera is unavailable.", details: nil))
        return
      }
      guard let presenter = Self.topViewController() else {
        result(FlutterError(code: "no_presenter", message: "Cannot present camera.", details: nil))
        return
      }

      let availableTypes = UIImagePickerController.availableMediaTypes(for: .camera) ?? []
      let mediaTypes = ["public.image", "public.movie"].filter { availableTypes.contains($0) }
      guard !mediaTypes.isEmpty else {
        result(FlutterError(code: "media_unavailable", message: "Camera media types are unavailable.", details: nil))
        return
      }

      self.pendingResult = result
      let picker = UIImagePickerController()
      picker.sourceType = .camera
      picker.mediaTypes = mediaTypes
      picker.videoQuality = .typeHigh
      picker.delegate = self
      presenter.present(picker, animated: true)
    }
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true) {
      self.finish(nil)
    }
  }

  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    picker.dismiss(animated: true) {
      if let image = info[.originalImage] as? UIImage {
        self.finish(self.persist(image: image))
        return
      }
      if let videoURL = info[.mediaURL] as? URL {
        self.finish(self.copyVideo(from: videoURL))
        return
      }
      self.finish(
        FlutterError(code: "unknown_media", message: "Camera did not return a supported media file.", details: nil)
      )
    }
  }

  private func persist(image: UIImage) -> Any {
    guard let data = image.jpegData(compressionQuality: 0.92) else {
      return FlutterError(code: "image_encode_failed", message: "Failed to encode captured image.", details: nil)
    }
    let target = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("jpg")
    do {
      try data.write(to: target, options: [.atomic])
      return [
        "type": "image",
        "path": target.path,
        "width": Int(image.size.width),
        "height": Int(image.size.height)
      ]
    } catch {
      return FlutterError(code: "image_write_failed", message: error.localizedDescription, details: nil)
    }
  }

  private func copyVideo(from source: URL) -> Any {
    let target = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(source.pathExtension.isEmpty ? "mov" : source.pathExtension)
    do {
      if FileManager.default.fileExists(atPath: target.path) {
        try FileManager.default.removeItem(at: target)
      }
      try FileManager.default.copyItem(at: source, to: target)
      let asset = AVAsset(url: target)
      let track = asset.tracks(withMediaType: .video).first
      let naturalSize = track?.naturalSize.applying(track?.preferredTransform ?? .identity) ?? .zero
      return [
        "type": "video",
        "path": target.path,
        "width": Int(abs(naturalSize.width)),
        "height": Int(abs(naturalSize.height))
      ]
    } catch {
      return FlutterError(code: "video_copy_failed", message: error.localizedDescription, details: nil)
    }
  }

  private func finish(_ value: Any?) {
    let result = pendingResult
    pendingResult = nil
    result?(value)
  }

  func cancelPending() {
    if pendingResult != nil {
      finish(FlutterError(code: "camera_cancelled", message: "Camera was interrupted.", details: nil))
    }
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
