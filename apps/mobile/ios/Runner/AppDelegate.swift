import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let cameraCapture = NativeCameraCapture()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
      return ["type": "image", "path": target.path]
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
      return ["type": "video", "path": target.path]
    } catch {
      return FlutterError(code: "video_copy_failed", message: error.localizedDescription, details: nil)
    }
  }

  private func finish(_ value: Any?) {
    let result = pendingResult
    pendingResult = nil
    result?(value)
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
