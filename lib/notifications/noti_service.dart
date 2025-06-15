import 'dart:async';
import 'dart:io';

import 'package:amanak/firebase/firebase_manager.dart';
import 'package:amanak/models/pill_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class NotiService {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final NotiService _instance = NotiService._internal();
  bool _isInitialized = false;
  String? _localTimezone;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Singleton pattern
  factory NotiService() {
    return _instance;
  }

  NotiService._internal();

  bool get isInitialized => _isInitialized;
  String? get localTimezone => _localTimezone;

  // Constants
  static const int PILL_REMINDER_ID_PREFIX = 100000;
  static const int PILL_ADVANCE_REMINDER_ID_PREFIX = 200000;
  static const int MISSED_NOTIFICATION_ID_PREFIX = 300000;
  static const int LOCATION_NOTIFICATION_ID_PREFIX = 400000;
  static const int PILL_TAKEN_NOTIFICATION_ID_PREFIX = 500000;
  static const int GRACE_PERIOD_MINUTES =
      30; // Grace period for marking pill as taken

  // Initialize notifications and timezone data
  Future<void> initNotification() async {
    if (_isInitialized) return; // prevent re-initialization

    // Initialize timezone data
    tz_data.initializeTimeZones();
    _localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(_localTimezone!));

    // Request permissions for iOS
    if (Platform.isIOS) {
      await notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    // Request permissions for Android 13+
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Check if the implementation supports permission requests
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();

        // Enable notifications to wake up the app from terminated state
        await androidImplementation.requestExactAlarmsPermission();

        // Configure for background notifications
        await androidImplementation.createNotificationChannel(
          AndroidNotificationChannel(
            'high_importance_channel',
            'High Importance Notifications',
            description: 'This channel is used for important notifications.',
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
            showBadge: true,
          ),
        );

        // Create channel for pill reminders
        await androidImplementation.createNotificationChannel(
          AndroidNotificationChannel(
            'pill_reminder_channel',
            'Pill Reminders',
            description: 'Notifications for pill reminders',
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
          ),
        );

        // Create channel for missed pills
        await androidImplementation.createNotificationChannel(
          AndroidNotificationChannel(
            'missed_pill_channel',
            'Missed Pills',
            description: 'Notifications for missed pills',
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
          ),
        );

        // Create channel for taken pills
        await androidImplementation.createNotificationChannel(
          AndroidNotificationChannel(
            'taken_pill_channel',
            'Taken Pills',
            description: 'Notifications for taken pills',
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
          ),
        );
      }
    }

    // Initialize Firebase Cloud Messaging
    await _initFirebaseMessaging();

    // Prepare Android initialization settings
    const initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Prepare iOS initialization settings
    const initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialize settings
    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    // Initialize plugin
    await notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      // Handle background notifications
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _isInitialized = true;
    print('Notification service initialized with background support');
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - could navigate to specific screen
    final String? payload = response.payload;
    if (payload != null) {
      print('Notification tapped with payload: $payload');
      // Handle the payload - e.g., navigate to a specific screen
    }
  }

  // This static function will be called when a notification is tapped in the background
  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    // Handle the notification tap in background
    final String? payload = response.payload;
    if (payload != null) {
      print('Background notification tapped with payload: $payload');

      // Parse payload to determine action
      if (payload.startsWith('take:')) {
        // Handle pill taking action in background
        _handleBackgroundPillAction(payload);
      } else if (payload.startsWith('check_missed:')) {
        // Handle missed pill check in background
        _handleBackgroundMissedCheck(payload);
      }
    }
  }

  // Handle pill actions in background
  static Future<void> _handleBackgroundPillAction(String payload) async {
    try {
      final parts = payload.split(':');
      if (parts.length >= 2) {
        final pillId = parts[1];
        // In a real implementation, you would use a background Isolate or WorkManager
        // to handle database operations in the background
        print('Background action for pill ID: $pillId');
      }
    } catch (e) {
      print('Error handling background pill action: $e');
    }
  }

  // Handle missed pill check in background
  static Future<void> _handleBackgroundMissedCheck(String payload) async {
    try {
      final parts = payload.split(':');
      if (parts.length >= 2) {
        final pillId = parts[1];
        // In a real implementation, you would use a background Isolate or WorkManager
        // to handle database operations in the background
        print('Background missed check for pill ID: $pillId');
      }
    } catch (e) {
      print('Error handling background missed check: $e');
    }
  }

  // Notification details for pill reminders
  NotificationDetails _pillReminderDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'pill_reminder_channel',
        'Pill Reminders',
        channelDescription: 'Notifications for pill reminders',
        importance: Importance.high,
        priority: Priority.high,
        // Use default sound if custom sound is not available
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // Notification details for missed pills
  NotificationDetails missedPillDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'missed_pill_channel',
        'Missed Pills',
        channelDescription: 'Notifications for missed pills',
        importance: Importance.high,
        priority: Priority.high,
        // Use default sound if custom sound is not available
        playSound: true,
        color: Colors.red,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // Notification details for taken pills
  NotificationDetails takenPillDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'taken_pill_channel',
        'Taken Pills',
        channelDescription: 'Notifications for taken pills',
        importance: Importance.high,
        priority: Priority.high,
        // Use default sound if custom sound is not available
        playSound: true,
        color: Colors.green,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // Schedule notifications for a pill
  Future<void> schedulePillNotifications(PillModel pill) async {
    try {
      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get user data for personalized notifications
      final userData = await FirebaseManager.getNameAndRole(currentUser.uid);
      final userName = userData['name'] ?? 'User';
      final userRole = userData['role'] ?? '';

      // Only schedule pill reminders for elders, not for guardians
      if (userRole != 'guardian') {
        // Get user timezone or default to local timezone
        final userTimezone = userData['timezone'] ?? 'local';
        final tzLocation = userTimezone == 'local'
            ? tz.getLocation(_localTimezone!)
            : tz.getLocation(userTimezone);

        // Calculate notification times for each day of the pill duration
        final startDate = pill.dateTime;
        final int duration = pill.duration;

        // Calculate ID ranges for this pill using a safe hash code
        final int safeHashCode = pill.id.hashCode % 10000; // Limit to 4 digits
        final int reminderIdBase = PILL_REMINDER_ID_PREFIX + safeHashCode;
        final int dueIdBase = PILL_ADVANCE_REMINDER_ID_PREFIX + safeHashCode;
        final int missedIdBase = MISSED_NOTIFICATION_ID_PREFIX + safeHashCode;

        // For each day in the duration
        for (int day = 0; day < duration; day++) {
          // Calculate the date for this day
          final pillDate = startDate.add(Duration(days: day));

          // Calculate the exact time for the pill on this day
          final pillTime = tz.TZDateTime(
            tzLocation,
            pillDate.year,
            pillDate.month,
            pillDate.day,
            pill.alarmHour,
            pill.alarmMinute,
          );

          // Calculate the reminder time (5 minutes before)
          final reminderTime = pillTime.subtract(Duration(minutes: 5));

          // Only schedule if the time is in the future
          final now = tz.TZDateTime.now(tzLocation);
          if (reminderTime.isAfter(now)) {
            // Schedule 5-minute advance reminder
            await _scheduleNotification(
              id: dueIdBase + day,
              title: "Medicine Reminder",
              body:
                  "${userName}, don't forget to take ${pill.name} after 5 minutes.",
              scheduledTime: reminderTime,
              details: _pillReminderDetails(),
              payload: "reminder:${pill.id}:${day}",
            );
          }

          // Only schedule if the time is in the future
          if (pillTime.isAfter(now)) {
            // Schedule exact time reminder
            await _scheduleNotification(
              id: reminderIdBase + day,
              title: "Medicine Time",
              body:
                  "${userName}, it's time to take your medicine: ${pill.name}.",
              scheduledTime: pillTime,
              details: _pillReminderDetails(),
              payload: "take:${pill.id}:${day}",
            );

            // Schedule a check for missed pill 5 minutes after the scheduled time
            final checkTime = pillTime.add(Duration(
                minutes:
                    6)); // 6 minutes after to ensure 5 minute threshold is passed
            await _scheduleMissedPillCheck(
                pill, day, checkTime, missedIdBase + day);
          }
        }
      } else {
        print('User is a guardian, not scheduling pill reminders');
      }
    } catch (e) {
      print('Error scheduling pill notifications: $e');
    }
  }

  // Check if a pill was missed and notify guardian if necessary
  Future<void> checkMissedPill(String pillId, int day) async {
    try {
      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get the pill from Firebase
      final pillsCollection =
          FirebaseManager.getPillsCollection(currentUser.uid);
      final pillDoc = await pillsCollection.doc(pillId).get();

      if (!pillDoc.exists) return;

      final pill = pillDoc.data()!;

      // Get user data to check role
      final userData = await FirebaseManager.getNameAndRole(currentUser.uid);
      final userRole = userData['role'] ?? '';

      // Check if pill was taken
      if (!pill.taken) {
        // Pill was missed - mark it as missed in Firebase
        final missedPill = pill.copyWith(missed: true);
        await FirebaseManager.updatePill(missedPill);

        // Only notify guardian, not the elder themselves
        if (userRole != 'guardian') {
          // Notify guardian about the missed pill
          await notifyGuardianOfMissedPill(currentUser.uid, missedPill);
        }
      }
    } catch (e) {
      print('Error checking missed pill: $e');
    }
  }

  // Notify guardian about a pill being taken
  Future<void> notifyGuardianOfTakenPill(String userId, PillModel pill) async {
    try {
      // Get user data to find guardian
      final userData = await FirebaseManager.getNameAndRole(userId);
      final sharedUserEmail = userData['sharedUsers'] ?? '';
      final elderName = userData['name'] ?? 'Elder';

      if (sharedUserEmail.isEmpty) return;

      // Find guardian by email
      final guardianData =
          await FirebaseManager.getUserByEmail(sharedUserEmail);
      if (guardianData == null) return;

      final guardianId = guardianData['id'] ?? '';
      if (guardianId.isEmpty) return;

      // Log notification attempt
      print(
          'Attempting to send taken pill notification to guardian $guardianId for ${pill.name}');

      // Send local notification if guardian is the current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == guardianId) {
        await showNotification(
          id: PILL_TAKEN_NOTIFICATION_ID_PREFIX + pill.id.hashCode % 10000,
          title: "Medicine Taken",
          body: "Your shared user ${elderName} marked ${pill.name} as done.",
          details: takenPillDetails(),
        );
        print(
            'Sent local taken pill notification to guardian for ${pill.name}');
      }

      // Always send FCM notification to ensure cross-device delivery
      await sendFcmNotification(
        userId: guardianId,
        title: "Medicine Taken",
        body: "Your shared user ${elderName} marked ${pill.name} as done.",
        data: {
          'type': 'pill_taken',
          'pillId': pill.id,
          'pillName': pill.name,
          'elderName': elderName,
        },
      );

      print('Sent taken pill FCM notification to guardian for ${pill.name}');
    } catch (e) {
      print('Error notifying guardian of taken pill: $e');
    }
  }

  // Notify guardian about a missed pill
  Future<void> notifyGuardianOfMissedPill(String userId, PillModel pill) async {
    try {
      // Get user data to find guardian
      final userData = await FirebaseManager.getNameAndRole(userId);
      final sharedUserEmail = userData['sharedUsers'] ?? '';
      final elderName = userData['name'] ?? 'Elder';

      if (sharedUserEmail.isEmpty) return;

      // Find guardian by email
      final guardianData =
          await FirebaseManager.getUserByEmail(sharedUserEmail);
      if (guardianData == null) return;

      final guardianId = guardianData['id'] ?? '';
      if (guardianId.isEmpty) return;

      // Log notification attempt
      print(
          'Attempting to send missed pill notification to guardian $guardianId for ${pill.name}');

      // Send local notification if guardian is the current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == guardianId) {
        await showNotification(
          id: MISSED_NOTIFICATION_ID_PREFIX + pill.id.hashCode % 10000,
          title: "Pill Missed Alert",
          body:
              "Your shared user ${elderName} missed their medicine: ${pill.name}.",
          details: missedPillDetails(),
        );
        print(
            'Sent local missed pill notification to guardian for ${pill.name}');
      }

      // Always send FCM notification to ensure cross-device delivery
      await sendFcmNotification(
        userId: guardianId,
        title: "Pill Missed Alert",
        body:
            "Your shared user ${elderName} missed their medicine: ${pill.name}.",
        data: {
          'type': 'pill_missed',
          'pillId': pill.id,
          'pillName': pill.name,
          'elderName': elderName,
        },
      );

      print('Sent missed pill FCM notification to guardian for ${pill.name}');
    } catch (e) {
      print('Error notifying guardian: $e');
    }
  }

  // Schedule a notification to check if pill was missed
  Future<void> _scheduleMissedPillCheck(PillModel pill, int day,
      tz.TZDateTime checkTime, int notificationId) async {
    // Schedule the check using Android alarm manager or similar mechanism
    // For now, we'll use the local notifications plugin, but in a real app
    // you'd want to use a more reliable background mechanism
    await _scheduleNotification(
      id: notificationId,
      title: "Checking medication status",
      body: "Checking if ${pill.name} was taken",
      scheduledTime: checkTime,
      details: _pillReminderDetails(),
      payload: "check_missed:${pill.id}:${day}",
    );
  }

  // Schedule a single notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    required NotificationDetails details,
    String? payload,
  }) async {
    await notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  // Cancel all notifications for a specific pill
  Future<void> cancelPillNotifications(String pillId) async {
    // Calculate ID ranges for this pill using a safe hash code
    final int safeHashCode = pillId.hashCode % 10000; // Limit to 4 digits
    final int reminderIdBase = PILL_REMINDER_ID_PREFIX + safeHashCode;
    final int dueIdBase = PILL_ADVANCE_REMINDER_ID_PREFIX + safeHashCode;
    final int missedIdBase = MISSED_NOTIFICATION_ID_PREFIX + safeHashCode;

    // Cancel all potential notifications for this pill (up to 30 days)
    for (int day = 0; day < 30; day++) {
      await notificationsPlugin.cancel(reminderIdBase + day);
      await notificationsPlugin.cancel(dueIdBase + day);
      await notificationsPlugin.cancel(missedIdBase + day);
    }
  }

  // Show an immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required NotificationDetails details,
    String? payload,
  }) async {
    if (!_isInitialized) await initNotification();

    await notificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Check for pending notifications and deliver them
  Future<void> checkPendingNotifications() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

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

      // Process each notification
      for (final doc in pendingNotifications.docs) {
        final data = doc.data();
        final title = data['title'] as String;
        final body = data['body'] as String;

        // Show the notification
        await showNotification(
          id: doc.id.hashCode % 10000,
          title: title,
          body: body,
          details: NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription:
                  'This channel is used for important notifications.',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        );

        // Mark as delivered
        await doc.reference.update({'delivered': true});
        print('Delivered pending notification: $title');
      }
    } catch (e) {
      print('Error checking pending notifications: $e');
    }
  }

  // Reschedule all pill notifications (call when app starts or timezone changes)
  Future<void> rescheduleAllPillNotifications() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get all pills for current user
      final pills = await FirebaseManager.getPills();

      // Schedule notifications for each pill
      for (final pill in pills) {
        await schedulePillNotifications(pill);
      }
    } catch (e) {
      print('Error rescheduling notifications: $e');
    }
  }

  // Get local timezone
  String _getLocalTimeZone() {
    return tz.local.name;
  }

  // Test function to verify notifications are working
  Future<void> testNotification() async {
    if (!_isInitialized) await initNotification();

    // Test immediate notification
    await notificationsPlugin.show(
      9999,
      "Test Notification",
      "This is a test notification to verify the system is working",
      _pillReminderDetails(),
      payload: "test_notification",
    );

    print('Test notification sent');

    // Test scheduled notification (30 seconds from now)
    final now = tz.TZDateTime.now(tz.local);
    final scheduledTime = now.add(const Duration(seconds: 30));

    await _scheduleNotification(
      id: 9998,
      title: "Test Scheduled Notification",
      body: "This notification was scheduled for 30 seconds after the test",
      scheduledTime: scheduledTime,
      details: _pillReminderDetails(),
      payload: "test_scheduled",
    );

    print('Test scheduled notification set for 30 seconds from now');
  }

  // Initialize Firebase Cloud Messaging
  Future<void> _initFirebaseMessaging() async {
    try {
      // Request permission for FCM
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('FCM Authorization status: ${settings.authorizationStatus}');

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        await _saveFcmToken(token);
      }

      // Listen for token refreshes
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _saveFcmToken(newToken);
      });

      // Handle FCM messages when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print(
              'Message also contained a notification: ${message.notification}');
          _showFcmNotification(message);
        }
      });
    } catch (e) {
      print('Error initializing FCM: $e');
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveFcmToken(String token) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Save token to user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'fcmToken': token});

      print('FCM token saved to Firestore');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Show notification from FCM message
  void _showFcmNotification(RemoteMessage message) {
    try {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null) {
        notificationsPlugin.show(
          message.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription:
                  'This channel is used for important notifications.',
              importance: Importance.high,
              priority: Priority.high,
              icon: android?.smallIcon,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      }
    } catch (e) {
      print('Error showing FCM notification: $e');
    }
  }

  // Send FCM notification to a specific user
  Future<void> sendFcmNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user document to retrieve FCM token
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        print('User document not found');
        return;
      }

      final userData = userDoc.data();
      if (userData == null) return;

      final fcmToken = userData['fcmToken'];
      if (fcmToken == null || fcmToken.isEmpty) {
        print('FCM token not found for user $userId');
        return;
      }

      // Prepare notification payload
      final message = {
        'token': fcmToken,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': data ?? {},
      };

      // Try to send via Cloud Functions if available
      // Note: Cloud Functions often have connectivity issues with emulators
      try {
        // Try with default region (us-central1)
        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
        final callable = functions.httpsCallable('sendNotification');
        print(
            'Attempting to call Cloud Function: us-central1/sendNotification');
        final result = await callable.call(message);
        print('FCM notification sent via Cloud Functions: ${result.data}');
      } catch (functionError) {
        // Fall back to direct FCM (only works in development with Firebase Admin SDK)
        print('Cloud Function not available: $functionError');
        print(
            'This error is common when testing on emulators without Google Play Services');

        // Log the message details
        print('Would send FCM message: $message');
        print('FCM notification attempted for user $userId');

        // Store the notification in Firestore for delivery when user comes online
        await FirebaseFirestore.instance
            .collection('pending_notifications')
            .add({
          'userId': userId,
          'title': title,
          'body': body,
          'data': data,
          'timestamp': FieldValue.serverTimestamp(),
          'delivered': false,
        });
        print('Notification stored in Firestore for later delivery');
      }
    } catch (e) {
      print('Error sending FCM notification: $e');
    }
  }
}
