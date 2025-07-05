import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amanak/notifications/noti_service.dart';

/// A centralized service for handling Firebase Cloud Messaging (FCM) operations
/// including token management, permission requests, and notification sending.
class FCMService {
  static final FCMService _instance = FCMService._internal();

  factory FCMService() => _instance;

  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  bool _isInitialized = false;

  // Getter for initialization state
  bool get isInitialized => _isInitialized;

  /// Initialize the FCM service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('FCM Service initialization deferred: User not authenticated');
        _isInitialized = false;
        return;
      }

      // Request permissions
      await requestNotificationPermissions();

      // Get and save token
      await refreshAndSaveToken();

      // Listen for token refreshes
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _saveFcmToken(newToken);
        _storeTokenLocally(newToken);
      });

      _isInitialized = true;
      print('FCM Service initialized successfully');
    } catch (e) {
      print('Error initializing FCM service: $e');
      _isInitialized = false;
    }
  }

  /// Request notification permissions
  Future<NotificationSettings> requestNotificationPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
    );

    print('FCM Authorization status: ${settings.authorizationStatus}');
    return settings;
  }

  /// Get the current FCM token, refresh if needed, and save it
  Future<String?> refreshAndSaveToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('FCM Token obtained: ${token.substring(0, 10)}...');
        await _saveFcmToken(token);
        await _storeTokenLocally(token);
        return token;
      }
    } catch (e) {
      print('Error refreshing FCM token: $e');
    }
    return null;
  }

  /// Save FCM token to Firestore
  Future<void> _saveFcmToken(String token) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('Cannot save FCM token: User not authenticated');
        return;
      }

      // Update the user document with the token
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });

        print('FCM token saved to Firestore');
      } catch (firestoreError) {
        // If the document doesn't exist yet, create it
        if (firestoreError is FirebaseException &&
            firestoreError.code == 'not-found') {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .set({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
            'email': currentUser.email ?? '',
            'id': currentUser.uid,
          }, SetOptions(merge: true));

          print('FCM token saved to new Firestore document');
        } else {
          throw firestoreError;
        }
      }
    } catch (e) {
      print('Error saving FCM token to Firestore: $e');
    }
  }

  /// Store token locally for verification
  Future<void> _storeTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      await prefs.setInt(
          'fcm_token_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error storing FCM token locally: $e');
    }
  }

  /// Verify if the stored token is still valid
  Future<bool> verifyToken() async {
    try {
      // Check if token exists in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('fcm_token');
      final timestamp = prefs.getInt('fcm_token_timestamp');

      if (storedToken == null || timestamp == null) {
        print('No stored FCM token found');
        return false;
      }

      // Check if token is older than 7 days (Firebase FCM tokens typically expire after ~60 days,
      // but we check more frequently to be safe)
      final tokenAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (tokenAge > 7 * 24 * 60 * 60 * 1000) {
        // 7 days in milliseconds
        print('FCM token is older than 7 days, refreshing');
        await refreshAndSaveToken();
        return true;
      }

      // Get current token from Firebase
      final currentToken = await _firebaseMessaging.getToken();

      // If tokens don't match, update with the new one
      if (currentToken != storedToken) {
        print('FCM token mismatch, updating token');
        if (currentToken != null) {
          await _saveFcmToken(currentToken);
          await _storeTokenLocally(currentToken);
        }
        return false;
      }

      return true;
    } catch (e) {
      print('Error verifying FCM token: $e');
      return false;
    }
  }

  /// Send FCM notification to a specific user
  Future<bool> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
    bool highPriority = true,
  }) async {
    try {
      // Ensure service is initialized
      if (!await ensureInitialized()) {
        print('Cannot send notification: FCM service not initialized');
        return false;
      }

      // Get user document to retrieve FCM token
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        print('User document not found for FCM notification');
        return false;
      }

      final userData = userDoc.data();
      if (userData == null) return false;

      final fcmToken = userData['fcmToken'];
      if (fcmToken == null || fcmToken.isEmpty) {
        print('FCM token not found for user $userId');
        return false;
      }

      // Prepare notification message with high priority settings
      final message = {
        'token': fcmToken,
        'notification': {
          'title': title,
          'body': body,
          if (imageUrl != null) 'imageUrl': imageUrl,
        },
        'data': {
          ...data ?? {},
          'title': title, // Duplicate in data for data-only messages
          'body': body, // Duplicate in data for data-only messages
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        'android': {
          'priority': highPriority ? 'high' : 'normal',
          'ttl': 60 * 1000, // 1 minute expiration for high priority
          'notification': {
            'channel_id': 'high_importance_channel',
            'priority': highPriority ? 'high' : 'normal',
            'default_vibrate_timings': true,
            'default_sound': true,
          },
        },
        'apns': {
          'headers': {
            'apns-priority':
                highPriority ? '10' : '5', // 10 = immediate delivery
            'apns-push-type': 'alert'
          },
          'payload': {
            'aps': {
              'sound': 'default',
              'badge': 1,
              'content-available': 1,
              'mutable-content': 1,
            }
          }
        },
      };

      // Try to send via Cloud Functions
      try {
        // Ensure user is authenticated before calling Cloud Functions
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          print('Cannot call Cloud Function: User not authenticated');
          throw Exception('User not authenticated');
        }

        // Force token refresh to ensure we have a valid token
        await currentUser.getIdToken(true);

        final functions = FirebaseFunctions.instance;
        final callable = functions.httpsCallable('sendNotification');
        final result = await callable.call(message);
        print('FCM notification sent via Cloud Functions: ${result.data}');

        // Store notification in Firestore for the recipient
        await _storeNotificationForUser(userId, title, body, data);
        return true;
      } catch (functionError) {
        print('Cloud Function error: $functionError');

        // Store for later delivery
        await FirebaseFirestore.instance
            .collection('pending_notifications')
            .add({
          'userId': userId,
          'title': title,
          'body': body,
          'data': data,
          'timestamp': FieldValue.serverTimestamp(),
          'delivered': false,
          'attempts': 1,
          'lastAttempt': FieldValue.serverTimestamp(),
          'error': functionError.toString(),
        });
        print(
            'Notification stored in pending_notifications for later delivery');

        // Try direct notification if it's a message
        if (data != null && data['type'] == 'message') {
          try {
            final notiService = NotiService();
            if (!notiService.isInitialized) {
              await notiService.initNotification();
            }

            await notiService.showNotification(
              id: 1000 + userId.hashCode % 10000,
              title: title,
              body: body,
              notificationDetails: notiService.messageDetails(),
              payload:
                  "message:${data['chatId'] ?? ''}:${data['senderId'] ?? ''}:${data['senderName'] ?? ''}",
            );
            print('Showed local notification as fallback');
          } catch (e) {
            print('Error showing local notification: $e');
          }
        }

        return false;
      }
    } catch (e) {
      print('Error sending FCM notification: $e');
      return false;
    }
  }

  /// Store notification for a specific user
  Future<void> _storeNotificationForUser(String userId, String title,
      String body, Map<String, dynamic>? data) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'message': body,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': data != null ? data['type'] : null,
        'data': data,
      });
    } catch (e) {
      print('Error storing notification for user $userId: $e');
    }
  }

  /// Check for pending notifications and try to deliver them
  Future<void> checkPendingNotifications() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('Cannot check pending notifications: User not authenticated');
        return;
      }

      // Ensure we have a valid authentication token
      await currentUser.getIdToken(true);

      // Get pending notifications for this user
      final pendingNotifications = await FirebaseFirestore.instance
          .collection('pending_notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('delivered', isEqualTo: false)
          .get();

      if (pendingNotifications.docs.isEmpty) {
        print('No pending notifications found');
        return;
      }

      print('Found ${pendingNotifications.docs.length} pending notifications');

      // Try to deliver each notification
      for (final doc in pendingNotifications.docs) {
        final data = doc.data();
        final title = data['title'];
        final body = data['body'];
        final notificationData = data['data'];

        // Try to send the notification again
        final success = await sendNotification(
          userId: currentUser.uid,
          title: title,
          body: body,
          data: notificationData,
        );

        if (success) {
          // Mark as delivered if successful
          await doc.reference.update({
            'delivered': true,
            'deliveredAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Increment attempt counter
          final attempts = (data['attempts'] ?? 0) + 1;
          await doc.reference.update({
            'attempts': attempts,
            'lastAttempt': FieldValue.serverTimestamp(),
          });

          // If we've tried too many times, mark as failed
          if (attempts >= 5) {
            await doc.reference.update({
              'status': 'failed',
              'failedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      print('Error checking pending notifications: $e');
    }
  }

  /// Ensure the FCM service is initialized
  Future<bool> ensureInitialized() async {
    if (_isInitialized) return true;

    try {
      await initialize();
      return _isInitialized;
    } catch (e) {
      print('Error ensuring FCM service is initialized: $e');
      return false;
    }
  }
}
