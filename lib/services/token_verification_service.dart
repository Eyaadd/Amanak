import 'dart:async';
import 'package:amanak/services/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service to periodically verify FCM tokens and ensure they're up to date
class TokenVerificationService {
  static final TokenVerificationService _instance =
      TokenVerificationService._internal();

  factory TokenVerificationService() => _instance;

  TokenVerificationService._internal();

  Timer? _verificationTimer;
  final FCMService _fcmService = FCMService();

  /// Initialize the token verification service
  Future<void> initialize() async {
    // Verify token immediately
    await verifyToken();

    // Set up periodic verification (every 24 hours)
    _verificationTimer?.cancel();
    _verificationTimer =
        Timer.periodic(const Duration(hours: 24), (_) => verifyToken());
  }

  /// Verify the FCM token and refresh if needed
  Future<void> verifyToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastVerification = prefs.getInt('fcm_token_last_verification');
      final now = DateTime.now().millisecondsSinceEpoch;

      // If token was verified in the last 12 hours, skip
      if (lastVerification != null &&
          now - lastVerification < 12 * 60 * 60 * 1000) {
        print('FCM token was verified recently, skipping verification');
        return;
      }

      // Verify and refresh token if needed
      final isValid = await _fcmService.verifyToken();

      if (!isValid) {
        print('FCM token is invalid, refreshing...');
        await _fcmService.refreshAndSaveToken();
      } else {
        print('FCM token is valid');
      }

      // Update last verification timestamp
      await prefs.setInt('fcm_token_last_verification', now);
    } catch (e) {
      print('Error verifying FCM token: $e');
    }
  }

  /// Stop the verification timer
  void dispose() {
    _verificationTimer?.cancel();
    _verificationTimer = null;
  }
}
