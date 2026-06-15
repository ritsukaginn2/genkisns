import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';

import '../../models.dart';

final Logger _logger = Logger();

class LLMClient {
  /// Backend base URL. Override for local development with:
  /// `flutter run --dart-define=GENKI_API_BASE=http://<mac-lan-ip>:8787`
  /// (a physical iPhone cannot reach the Mac via `localhost`).
  static const String _configuredBaseUrl = String.fromEnvironment(
    'GENKI_API_BASE',
    defaultValue: '',
  );
  static const String _installationIdKey = 'genki_llm_installation_id';
  static const String _installationIdDevKey = 'genki_llm_installation_id_dev';

  final String _baseUrl;
  late String _installationId;
  late SharedPreferences _prefs;
  final bool _isDevelopment;
  Future<void>? _initFuture;
  InstallationStatusResponse? _latestInstallationStatus;

  LLMClient({bool isDevelopment = false, String? baseUrl})
    : _isDevelopment = isDevelopment,
      _baseUrl = baseUrl ?? _configuredBaseUrl;

  bool get isBackendConfigured => _baseUrl.trim().isNotEmpty;

  InstallationStatusResponse? get latestInstallationStatus =>
      _latestInstallationStatus;

  /// Initialize the LLM client. Idempotent: safe to call from app startup and
  /// again lazily from any request method.
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _installationId = await _getOrCreateInstallationId();
      _logger.i(
        'LLM Client initialized with installation_id: $_installationId',
      );
    } on Object {
      // Clear the cached future so a later call can retry.
      _initFuture = null;
      rethrow;
    }
  }

  /// Get or create installation ID
  Future<String> _getOrCreateInstallationId() async {
    final key = _isDevelopment ? _installationIdDevKey : _installationIdKey;
    final storedId = _prefs.getString(key);
    var id = storedId ?? const Uuid().v4().replaceAll('-', '').substring(0, 32);

    if (storedId == null) {
      await _prefs.setString(key, id);
      _logger.i('Created local installation ID: $id');
    }

    if (isBackendConfigured) {
      try {
        final registered = await _registerInstallation(id);
        final registeredId = registered.installationId;
        if (registeredId != id) {
          id = registeredId;
          await _prefs.setString(key, id);
        }
        _latestInstallationStatus = registered;
      } catch (e) {
        _logger.w('Failed to refresh installation with backend: $e');
      }
    }

    return id;
  }

  /// Register installation with backend
  Future<InstallationStatusResponse> _registerInstallation(
    String installationId,
  ) async {
    try {
      final response = await http
          .post(
            _endpoint('/v1/installations'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'installation_id': installationId,
              'platform': 'ios',
              'app_version': '1.0',
              'device_model': 'iPhone',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return InstallationStatusResponse.fromJson(data);
      } else {
        throw Exception('Failed to register: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Installation registration error: $e');
      rethrow;
    }
  }

  Future<InstallationStatusResponse> getInstallationStatus() async {
    await init();
    final response = await http
        .get(
          _endpoint('/v1/installations/me'),
          headers: {'X-Installation-Id': _installationId},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get installation status: ${response.statusCode}',
      );
    }
    final status = InstallationStatusResponse.fromJson(
      jsonDecode(response.body),
    );
    _latestInstallationStatus = status;
    return status;
  }

  /// Create LLM interaction job
  Future<InteractionJobResponse> createInteractionJob({
    required String postId,
    required String? text,
    required int imageCount,
    required bool hasVideo,
    required int videoCount,
    required List<AiFriend> friends,
    required String userName,
    required String? userBio,
  }) async {
    await init();
    try {
      final response = await http
          .post(
            _endpoint('/v1/interactions/jobs'),
            headers: {
              'Content-Type': 'application/json',
              'X-Installation-Id': _installationId,
            },
            body: jsonEncode({
              'post_id': postId,
              'text': text,
              'media': {
                'image_count': imageCount,
                'has_video': hasVideo,
                'video_count': videoCount,
              },
              'friends': [
                for (final friend in friends)
                  {
                    'id': friend.id,
                    'name': friend.name,
                    'relationship': friend.relationship,
                    'personality': friend.personality,
                    'speaking_style': friend.speakingStyle,
                  },
              ],
              'user': {'nickname': userName, 'bio': userBio ?? ''},
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 202 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['fallback_required'] == true || data['status'] == 'failed') {
          throw BackendFallbackException(data['reason'] ?? 'fallback_required');
        }
        return InteractionJobResponse.fromJson(data);
      } else if (response.statusCode == 402) {
        // Quota exceeded
        throw QuotaExceededException(
          jsonDecode(response.body)['detail'] ?? 'Quota exceeded',
        );
      } else if (response.statusCode == 429) {
        // Rate limited
        throw RateLimitedException(
          jsonDecode(response.body)['detail'] ?? 'Rate limited',
        );
      } else {
        throw Exception('Failed to create job: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Create job error: $e');
      rethrow;
    }
  }

  /// Poll job result with exponential backoff.
  /// Fails fast on HTTP errors (e.g. 404 — retrying cannot help); only the
  /// still-processing case is retried.
  Future<InteractionJobDetailResponse?> getJobResult(
    String jobId, {
    int maxAttempts = 30,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    await init();
    var delayMs = initialDelay.inMilliseconds;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final response = await http
          .get(
            _endpoint('/v1/interactions/jobs/$jobId'),
            headers: {'X-Installation-Id': _installationId},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to get job: ${response.statusCode}');
      }

      final result = InteractionJobDetailResponse.fromJson(
        jsonDecode(response.body),
      );
      if (result.status == JobStatus.completed ||
          result.status == JobStatus.failed) {
        return result;
      }

      // Job still processing — wait, then back off exponentially.
      await Future.delayed(Duration(milliseconds: delayMs));
      delayMs = (delayMs * 3 ~/ 2).clamp(500, 5000);
    }

    return null; // Timeout
  }

  String get installationId => _installationId;

  Uri _endpoint(String path) {
    final trimmed = _baseUrl.trim();
    if (trimmed.isEmpty) {
      throw BackendUnavailableException('GENKI_API_BASE is not configured');
    }
    final base = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    return Uri.parse('$base$path');
  }
}

// --- Models ---

class InstallationStatusResponse {
  final String installationId;
  final String status;
  final String? statusReason;
  final bool backendAvailable;
  final DateTime? updatedAt;

  InstallationStatusResponse({
    required this.installationId,
    required this.status,
    required this.backendAvailable,
    this.statusReason,
    this.updatedAt,
  });

  factory InstallationStatusResponse.fromJson(Map<String, dynamic> json) {
    final updatedAt = json['updated_at'];
    return InstallationStatusResponse(
      installationId: json['installation_id'] as String,
      status: json['status'] as String? ?? 'allowed',
      statusReason: json['status_reason'] as String?,
      backendAvailable: json['backend_available'] != false,
      updatedAt: updatedAt is String ? DateTime.tryParse(updatedAt) : null,
    );
  }

  bool get isAllowed => status == 'allowed';
  bool get isLimited => status == 'limited';
  bool get isBlocked => status == 'blocked';
}

enum JobStatus { queued, processing, completed, failed }

class InteractionJobResponse {
  final String jobId;
  final JobStatus status;
  final int? estimatedWaitSeconds;

  InteractionJobResponse({
    required this.jobId,
    required this.status,
    this.estimatedWaitSeconds,
  });

  factory InteractionJobResponse.fromJson(Map<String, dynamic> json) {
    return InteractionJobResponse(
      jobId: json['job_id'],
      status: _parseJobStatus(json['status']),
      estimatedWaitSeconds: json['estimated_wait_seconds'],
    );
  }
}

class InteractionJobDetailResponse {
  final String jobId;
  final JobStatus status;
  final JobResult? result;
  final String? reason;
  final bool fallbackRequired;

  InteractionJobDetailResponse({
    required this.jobId,
    required this.status,
    this.result,
    this.reason,
    this.fallbackRequired = false,
  });

  factory InteractionJobDetailResponse.fromJson(Map<String, dynamic> json) {
    return InteractionJobDetailResponse(
      jobId: json['job_id'],
      status: _parseJobStatus(json['status']),
      result: json['result'] != null
          ? JobResult.fromJson(json['result'])
          : null,
      reason: json['reason'],
      fallbackRequired: json['fallback_required'] == true,
    );
  }
}

class JobResult {
  final int aiLikeCount;
  final List<CommentData> comments;

  JobResult({required this.aiLikeCount, required this.comments});

  factory JobResult.fromJson(Map<String, dynamic> json) {
    return JobResult(
      aiLikeCount: json['ai_like_count'] ?? 0,
      comments:
          (json['comments'] as List<dynamic>?)
              ?.map((c) => CommentData.fromJson(c))
              .toList() ??
          [],
    );
  }
}

class CommentData {
  final String actorId;
  final String content;
  final int likeCount;

  /// Seconds after job creation when this comment should be revealed, so the
  /// client can stagger delivery for a real-person feel. Null when absent.
  final int? delaySeconds;

  CommentData({
    required this.actorId,
    required this.content,
    required this.likeCount,
    this.delaySeconds,
  });

  factory CommentData.fromJson(Map<String, dynamic> json) {
    final rawDelay = json['delay_seconds'];
    return CommentData(
      actorId: json['actor_id'],
      content: json['content'],
      likeCount: json['like_count'] ?? 0,
      delaySeconds: rawDelay is num ? rawDelay.toInt() : null,
    );
  }
}

JobStatus _parseJobStatus(String status) {
  return JobStatus.values.firstWhere(
    (s) => s.name == status,
    orElse: () => JobStatus.queued,
  );
}

// --- Exceptions ---

class QuotaExceededException implements Exception {
  final String message;
  QuotaExceededException(this.message);

  @override
  String toString() => message;
}

class RateLimitedException implements Exception {
  final String message;
  RateLimitedException(this.message);

  @override
  String toString() => message;
}

class BackendFallbackException implements Exception {
  final String reason;
  BackendFallbackException(this.reason);

  @override
  String toString() => reason;
}

class BackendUnavailableException implements Exception {
  final String message;
  BackendUnavailableException(this.message);

  @override
  String toString() => message;
}
