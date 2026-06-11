import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class LLMClient {
  static const String _baseUrl = 'https://api.genki-sns.com';
  static const String _installationIdKey = 'genki_llm_installation_id';
  static const String _installationIdDevKey = 'genki_llm_installation_id_dev';

  late String _installationId;
  late SharedPreferences _prefs;
  final bool _isDevelopment;

  LLMClient({bool isDevelopment = false}) : _isDevelopment = isDevelopment;

  /// Initialize the LLM client - call this once at app startup
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _installationId = await _getOrCreateInstallationId();
    logger.i('LLM Client initialized with installation_id: $_installationId');
  }

  /// Get or create installation ID
  Future<String> _getOrCreateInstallationId() async {
    final key = _isDevelopment ? _installationIdDevKey : _installationIdKey;
    var id = _prefs.getString(key);

    if (id == null) {
      try {
        id = await _registerInstallation();
        await _prefs.setString(key, id);
        logger.i('Created new installation ID: $id');
      } catch (e) {
        logger.e('Failed to register installation: $e');
        // Fallback: use temporary UUID (will try again next time)
        id = const Uuid().v4().replaceAll('-', '').substring(0, 32);
      }
    }

    return id;
  }

  /// Register installation with backend
  Future<String> _registerInstallation() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/v1/installations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'platform': 'ios',
          'app_version': '1.0',
          'device_model': 'iPhone',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['installation_id'] as String;
      } else {
        throw Exception('Failed to register: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Installation registration error: $e');
      rethrow;
    }
  }

  /// Create LLM interaction job
  Future<InteractionJobResponse> createInteractionJob({
    required String postId,
    required String? text,
    required int imageCount,
    required List<String> friendIds,
    required String userName,
    required String? userBio,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/v1/interactions/jobs'),
        headers: {
          'Content-Type': 'application/json',
          'X-Installation-Id': _installationId,
        },
        body: jsonEncode({
          'post_id': postId,
          'text': text,
          'image_count': imageCount,
          'friend_ids': friendIds,
          'user': {
            'nickname': userName,
            'bio': userBio ?? '',
          },
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 202 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return InteractionJobResponse.fromJson(data);
      } else if (response.statusCode == 402) {
        // Quota exceeded
        throw QuotaExceededException(jsonDecode(response.body)['detail'] ?? 'Quota exceeded');
      } else if (response.statusCode == 429) {
        // Rate limited
        throw RateLimitedException(jsonDecode(response.body)['detail'] ?? 'Rate limited');
      } else {
        throw Exception('Failed to create job: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Create job error: $e');
      rethrow;
    }
  }

  /// Poll job result (with exponential backoff)
  Future<InteractionJobDetailResponse?> getJobResult(
    String jobId, {
    int maxAttempts = 30,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    int attempt = 0;

    while (attempt < maxAttempts) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/v1/interactions/jobs/$jobId'),
          headers: {
            'X-Installation-Id': _installationId,
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final result = InteractionJobDetailResponse.fromJson(data);

          if (result.status == JobStatus.completed || result.status == JobStatus.failed) {
            return result;
          }

          // Job still processing, wait and retry
          attempt++;
          final delayMs = (initialDelay.inMilliseconds *
                          (1.5 * attempt).toInt()).clamp(500, 5000);
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          throw Exception('Failed to get job: ${response.statusCode}');
        }
      } catch (e) {
        logger.e('Get job error (attempt $attempt): $e');
        if (attempt >= maxAttempts - 1) {
          rethrow;
        }
        attempt++;
      }
    }

    return null; // Timeout
  }

  /// Get current entitlements
  Future<EntitlementResponse> getEntitlements() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/v1/entitlements?installation_id=$_installationId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return EntitlementResponse.fromJson(data);
      } else {
        throw Exception('Failed to get entitlements: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Get entitlements error: $e');
      rethrow;
    }
  }

  /// Verify Apple IAP purchase
  Future<EntitlementResponse> verifyPurchase({
    required String receiptJws,
    required String productId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/v1/purchases/verify'),
        headers: {
          'Content-Type': 'application/json',
          'X-Installation-Id': _installationId,
        },
        body: jsonEncode({
          'receipt_jws': receiptJws,
          'product_id': productId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return EntitlementResponse.fromJson(data);
      } else {
        throw Exception('Purchase verification failed: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Verify purchase error: $e');
      rethrow;
    }
  }

  String get installationId => _installationId;
}

// --- Models ---

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

  InteractionJobDetailResponse({
    required this.jobId,
    required this.status,
    this.result,
    this.reason,
  });

  factory InteractionJobDetailResponse.fromJson(Map<String, dynamic> json) {
    return InteractionJobDetailResponse(
      jobId: json['job_id'],
      status: _parseJobStatus(json['status']),
      result: json['result'] != null ? JobResult.fromJson(json['result']) : null,
      reason: json['reason'],
    );
  }
}

class JobResult {
  final int aiLikeCount;
  final List<CommentData> comments;

  JobResult({
    required this.aiLikeCount,
    required this.comments,
  });

  factory JobResult.fromJson(Map<String, dynamic> json) {
    return JobResult(
      aiLikeCount: json['ai_like_count'] ?? 0,
      comments: (json['comments'] as List<dynamic>?)
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

  CommentData({
    required this.actorId,
    required this.content,
    required this.likeCount,
  });

  factory CommentData.fromJson(Map<String, dynamic> json) {
    return CommentData(
      actorId: json['actor_id'],
      content: json['content'],
      likeCount: json['like_count'] ?? 0,
    );
  }
}

class EntitlementResponse {
  final String installationId;
  final String subscriptionStatus; // free | pro | trial
  final int quotaRemaining;
  final int quotaTotal;
  final DateTime nextResetAt;
  final DateTime? subscriptionExpiresAt;

  EntitlementResponse({
    required this.installationId,
    required this.subscriptionStatus,
    required this.quotaRemaining,
    required this.quotaTotal,
    required this.nextResetAt,
    this.subscriptionExpiresAt,
  });

  factory EntitlementResponse.fromJson(Map<String, dynamic> json) {
    return EntitlementResponse(
      installationId: json['installation_id'],
      subscriptionStatus: json['subscription_status'],
      quotaRemaining: json['quota_remaining'] ?? 0,
      quotaTotal: json['quota_total'] ?? 0,
      nextResetAt: DateTime.parse(json['next_reset_at']),
      subscriptionExpiresAt: json['subscription_expires_at'] != null
          ? DateTime.parse(json['subscription_expires_at'])
          : null,
    );
  }

  bool get isPro => subscriptionStatus == 'pro';
  bool get isFree => subscriptionStatus == 'free';
  bool get hasQuota => quotaRemaining > 0;
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
