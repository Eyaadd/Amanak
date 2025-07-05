import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:math';

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
import 'package:amanak/main.dart'; // Import for navigatorKey
import 'package:http/http.dart' as http;
import 'package:amanak/services/encryption_service.dart';
import 'package:amanak/services/fcm_service.dart';
// import 'package:dotenv/dotenv.dart';

class NotiService {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final NotiService _instance = NotiService._internal();
  bool _isInitialized = false;
  String? _localTimezone;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FCMService _fcmService = FCMService();

  // Track if the app is in foreground
  bool _isInForeground = false;

  // Add encryption service
  final EncryptionService _encryptionService = EncryptionService();

  // Singleton pattern
  factory NotiService() {
    return _instance;
  }

  NotiService._internal();

  bool get isInitialized => _isInitialized;
  String? get localTimezone => _localTimezone;
  bool get isInForeground => _isInForeground;

  // Update foreground state
  void setForegroundState(bool isInForeground) {
    _isInForeground = isInForeground;
  }

  // Constants
  static const int PILL_REMINDER_ID_PREFIX = 100000;
  static const int PILL_ADVANCE_REMINDER_ID_PREFIX = 200000;
  static const int MISSED_NOTIFICATION_ID_PREFIX = 300000;
  static const int LOCATION_NOTIFICATION_ID_PREFIX = 400000;
  static const int PILL_TAKEN_NOTIFICATION_ID_PREFIX = 500000;
  static const int MESSAGE_NOTIFICATION_ID_PREFIX = 600000;
  static const int GRACE_PERIOD_MINUTES =
      30; // Grace period for marking pill as taken

  // Initialize notifications and timezone data
  Future<void> initNotification() async {
    if (_isInitialized) return; // prevent re-initialization

    // Initialize timezone data
    tz_data.initializeTimeZones();
    _localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(_localTimezone!));

    // Set up app lifecycle observer to track foreground state
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(this));

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

        // Create channel for messages
        await androidImplementation.createNotificationChannel(
          AndroidNotificationChannel(
            'message_channel',
            'Messages',
            description: 'Notifications for new messages',
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
        AndroidInitializationSettings('notification_icon');

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

      // Parse payload to determine action
      if (payload.startsWith('take:')) {
        // Handle pill taking action
        _handlePillAction(payload);
      } else if (payload.startsWith('check_missed:')) {
        // Handle missed pill check
        _handleMissedCheck(payload);
      } else if (payload.startsWith('message:')) {
        // Handle message notification tap
        _handleMessageTap(payload);
      }
    }
  }

  // Handle pill action when notification tapped in foreground
  void _handlePillAction(String payload) {
    try {
      final parts = payload.split(':');
      if (parts.length >= 3) {
        final pillId = parts[1];
        final day = int.tryParse(parts[2]) ?? 0;
        final timeIndex = int.tryParse(parts[3]) ?? 0;
        print(
            'Handling pill action for pill ID: $pillId, day: $day, timeIndex: $timeIndex');
        // In a real implementation, navigate to pill detail or take action
        // Could show a dialog to mark this specific dose as taken
      } else if (parts.length >= 2) {
        // Backward compatibility for old format
        final pillId = parts[1];
        print('Handling pill action for pill ID: $pillId (old format)');
      }
    } catch (e) {
      print('Error handling pill action: $e');
    }
  }

  // Handle missed pill check when notification tapped in foreground
  void _handleMissedCheck(String payload) {
    try {
      final parts = payload.split(':');
      if (parts.length >= 4) {
        final pillId = parts[1];
        final day = int.tryParse(parts[2]) ?? 0;
        final timeIndex = int.tryParse(parts[3]) ?? 0;
        print(
            'Handling missed check for pill ID: $pillId, day: $day, timeIndex: $timeIndex');

        // Call the new specific time missed check
        checkSpecificTimeMissed(pillId, day, timeIndex);
      } else if (parts.length >= 2) {
        // Backward compatibility for old format
        final pillId = parts[1];
        print('Handling missed check for pill ID: $pillId (old format)');

        // Call the old general missed check
        checkMissedPill(pillId);
      }
    } catch (e) {
      print('Error handling missed check: $e');
    }
  }

  // Handle message notification tap
  void _handleMessageTap(String payload) {
    try {
      // Extract message data from payload
      // Format: message:chatId:senderId:senderName
      final parts = payload.split(':');
      if (parts.length >= 4) {
        final chatId = parts[1];
        final senderId = parts[2];
        final senderName = parts[3];

        // Navigate to messaging screen using global navigator key
        navigatorKey.currentState?.pushNamed('/messaging', arguments: {
          'chatId': chatId,
          'senderId': senderId,
          'senderName': senderName,
        });
      }
    } catch (e) {
      print('Error handling message tap: $e');
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
      if (parts.length >= 3) {
        final pillId = parts[1];
        final day = int.tryParse(parts[2]) ?? 0;
        final timeIndex = int.tryParse(parts[3]) ?? 0;
        // In a real implementation, you would use a background Isolate or WorkManager
        // to handle database operations in the background
        print(
            'Background action for pill ID: $pillId, day: $day, timeIndex: $timeIndex');
      } else if (parts.length >= 2) {
        // Backward compatibility for old format
        final pillId = parts[1];
        print('Background action for pill ID: $pillId (old format)');
      }
    } catch (e) {
      print('Error handling background pill action: $e');
    }
  }

  // Handle missed pill check in background
  static Future<void> _handleBackgroundMissedCheck(String payload) async {
    try {
      final parts = payload.split(':');
      if (parts.length >= 4) {
        final pillId = parts[1];
        final day = int.tryParse(parts[2]) ?? 0;
        final timeIndex = int.tryParse(parts[3]) ?? 0;

        print(
            'Background missed check for pill ID: $pillId, day: $day, timeIndex: $timeIndex');

        // Create an instance to call the method
        final notiService = NotiService();
        if (!notiService.isInitialized) {
          await notiService.initNotification();
        }

        // Call the new specific time missed check
        await notiService.checkSpecificTimeMissed(pillId, day, timeIndex);
      } else if (parts.length >= 2) {
        // Backward compatibility for old format
        final pillId = parts[1];
        print('Background missed check for pill ID: $pillId (old format)');

        // Create an instance to call the method
        final notiService = NotiService();
        if (!notiService.isInitialized) {
          await notiService.initNotification();
        }

        // Call the old general missed check
        await notiService.checkMissedPill(pillId);
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
        icon: 'notification_icon',
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
        icon: 'notification_icon',
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
        icon: 'notification_icon',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // Notification details for messages
  NotificationDetails messageDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'message_channel',
        'Messages',
        channelDescription: 'Notifications for new messages',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: 'notification_icon',
        styleInformation: BigTextStyleInformation(
            ''), // Allow for longer text in notification
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
        // First cancel any existing notifications for this pill to prevent duplicates
        await cancelPillNotifications(pill.id);

        // Get user timezone or default to local timezone
        final userTimezone = userData['timezone'] ?? 'local';
        final tzLocation = userTimezone == 'local'
            ? tz.getLocation(_localTimezone!)
            : tz.getLocation(userTimezone);

        // Calculate notification times for each day of the pill duration
        final startDate = pill.dateTime;
        final int duration = pill.duration;

        // Limit scheduling to 7 days in advance to improve performance
        final int daysToSchedule = min(duration, 7);

        // Calculate ID ranges for this pill using a safe hash code
        final int safeHashCode = pill.id.hashCode % 10000; // Limit to 4 digits
        final int reminderIdBase = PILL_REMINDER_ID_PREFIX + safeHashCode;
        final int dueIdBase = PILL_ADVANCE_REMINDER_ID_PREFIX + safeHashCode;
        final int missedIdBase = MISSED_NOTIFICATION_ID_PREFIX + safeHashCode;

        // Get current time once to avoid repeated calculations
        final now = tz.TZDateTime.now(tzLocation);

        // Track notifications to schedule
        List<Future<void>> scheduleTasks = [];

        // For each day in the duration (limited to daysToSchedule)
        for (int day = 0; day < daysToSchedule; day++) {
          // Calculate the date for this day
          final pillDate = startDate.add(Duration(days: day));

          // Skip past days entirely
          if (pillDate.isBefore(DateTime(now.year, now.month, now.day))) {
            continue;
          }

          // Schedule notifications for each time of the day
          for (int timeIndex = 0; timeIndex < pill.times.length; timeIndex++) {
            final time = pill.times[timeIndex];

            // Check if this specific time is already marked as taken
            final timeKey = pill.getTimeKey(pillDate, timeIndex);
            final isAlreadyTaken = pill.takenDates.containsKey(timeKey);

            // Skip scheduling notifications if this time is already taken
            if (isAlreadyTaken) {
              print(
                  'Skipping notifications for ${pill.name} at time $timeKey - already taken');

              // Make sure to cancel any existing notifications for this time slot
              final timeSlotId = timeIndex * 1000;
              final reminderId = dueIdBase + day + timeSlotId;
              final exactTimeId = reminderIdBase + day + timeSlotId;
              final missedId = missedIdBase + day + timeSlotId;

              await notificationsPlugin.cancel(reminderId);
              await notificationsPlugin.cancel(exactTimeId);
              await notificationsPlugin.cancel(missedId);

              continue;
            }

            // Calculate the exact time for this pill dose on this day
            final pillTime = tz.TZDateTime(
              tzLocation,
              pillDate.year,
              pillDate.month,
              pillDate.day,
              time.hour,
              time.minute,
            );

            // Skip if the pill time is in the past
            if (pillTime.isBefore(now)) {
              continue;
            }

            // Calculate the reminder time (5 minutes before)
            final reminderTime = pillTime.subtract(Duration(minutes: 5));

            // Create unique IDs for each time slot
            final timeSlotId =
                timeIndex * 1000; // Use timeIndex to create unique IDs
            final reminderId = dueIdBase + day + timeSlotId;
            final exactTimeId = reminderIdBase + day + timeSlotId;
            final missedId = missedIdBase + day + timeSlotId;

            // Schedule 5-minute advance reminder if it's in the future
            if (reminderTime.isAfter(now)) {
              scheduleTasks.add(_scheduleNotification(
                id: reminderId,
                title: "Medicine Reminder",
                body:
                    "${userName}, don't forget to take ${pill.name} (Dose ${timeIndex + 1}) after 5 minutes.",
                scheduledTime: reminderTime,
                details: _pillReminderDetails(),
                payload: "reminder:${pill.id}:${day}:${timeIndex}",
              ));
            }

            // Schedule exact time reminder
            scheduleTasks.add(_scheduleNotification(
              id: exactTimeId,
              title: "Medicine Time",
              body:
                  "${userName}, it's time to take your medicine: ${pill.name}${pill.times.length > 1 ? " (Dose ${timeIndex + 1})" : ""}.",
              scheduledTime: pillTime,
              details: _pillReminderDetails(),
              payload: "take:${pill.id}:${day}:${timeIndex}",
            ));

            // Schedule a check for missed pill 6 minutes after the scheduled time
            final checkTime = pillTime.add(Duration(minutes: 6));
            scheduleTasks.add(_scheduleMissedPillCheck(
                pill, day, checkTime, missedId, timeIndex));
          }
        }

        // Execute all scheduling tasks in parallel for better performance
        await Future.wait(scheduleTasks);

        print(
            'Scheduled notifications for pill: ${pill.name} (${scheduleTasks.length} notifications)');
      } else {
        print('User is a guardian, not scheduling pill reminders');
      }
    } catch (e) {
      print('Error scheduling pill notifications: $e');
    }
  }

  // Schedule missed pill check for a specific time slot
  Future<void> _scheduleMissedPillCheck(PillModel pill, int day,
      tz.TZDateTime checkTime, int notificationId, int timeIndex) async {
    try {
      // Get current time
      final now = tz.TZDateTime.now(checkTime.location);

      // Skip if the check time is in the past
      if (checkTime.isBefore(now)) {
        return;
      }

      // Calculate the date for this day
      final pillDate = pill.dateTime.add(Duration(days: day));

      // Check if this specific time is already marked as taken
      final timeKey = pill.getTimeKey(pillDate, timeIndex);
      final isAlreadyTaken = pill.takenDates.containsKey(timeKey);

      // Skip scheduling missed pill check if this time is already taken
      if (isAlreadyTaken) {
        print(
            'Skipping missed pill check for ${pill.name} at time $timeKey - already taken');
        return;
      }

      // Skip if the pill date is in the past (before today)
      final today = DateTime(now.year, now.month, now.day);
      final pillDay = DateTime(pillDate.year, pillDate.month, pillDate.day);
      if (pillDay.isBefore(today)) {
        print(
            'Skipping missed pill check for ${pill.name} at time $timeKey - date is in the past');
        return;
      }

      await _scheduleNotification(
        id: notificationId,
        title: "Check Missed Pill",
        body: "Checking if ${pill.name} was taken",
        scheduledTime: checkTime,
        details: _pillReminderDetails(),
        payload: "check_missed:${pill.id}:${day}:${timeIndex}",
      );
    } catch (e) {
      print('Error scheduling missed pill check: $e');
    }
  }

  // Check if a pill was missed
  Future<void> checkMissedPill(String pillId) async {
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

      // Get today's date string
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month}-${today.day}';

      // Check if pill was taken today
      bool anyTimeTakenToday = false;
      for (int i = 0; i < pill.times.length; i++) {
        final timeKey = '$todayStr-$i';
        if (pill.takenDates.containsKey(timeKey)) {
          anyTimeTakenToday = true;
          break;
        }
      }

      if (!anyTimeTakenToday) {
        // Pill was missed - mark it as missed in Firebase
        final missedPill = pill.copyWith(missed: true);
        await FirebaseManager.updatePill(missedPill);

        // Only notify guardian, not the elder themselves
        if (userRole != 'guardian') {
          // Notify guardian about the missed pill
          await notifyGuardianOfMissedPill(currentUser.uid, missedPill);
        }
      } else {
        print('Pill ${pill.name} already taken today, not marking as missed');
      }
    } catch (e) {
      print('Error checking missed pill: $e');
    }
  }

  // Check if a specific pill time was missed
  Future<void> checkSpecificTimeMissed(
      String pillId, int day, int timeIndex) async {
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

      // Calculate the date for this day
      final pillDate = pill.dateTime.add(Duration(days: day));

      // Check if this specific time is already marked as taken
      final timeKey = pill.getTimeKey(pillDate, timeIndex);
      final isAlreadyTaken = pill.takenDates.containsKey(timeKey);

      // Skip marking as missed if this time is already taken
      if (isAlreadyTaken) {
        print(
            'Pill ${pill.name} at time $timeKey already taken, not marking as missed');
        return;
      }

      // Mark this specific time as missed
      pill.markTimeMissed(timeKey, true);

      // Update the pill in Firebase
      await FirebaseManager.updatePill(pill);

      // Only notify guardian, not the elder themselves
      if (userRole != 'guardian') {
        // Notify guardian about the missed pill
        await notifyGuardianOfMissedPill(currentUser.uid, pill);
      }
    } catch (e) {
      print('Error checking specific time missed: $e');
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
          notificationDetails: takenPillDetails(),
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
          notificationDetails: missedPillDetails(),
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
      payload: payload,
      matchDateTimeComponents: null, // you can also remove this line if unused
    );
  }

  // Cancel all notifications for a pill
  Future<void> cancelPillNotifications(String pillId) async {
    try {
      // Calculate ID ranges for this pill using a safe hash code
      final int safeHashCode = pillId.hashCode % 10000; // Limit to 4 digits
      final int reminderIdBase = PILL_REMINDER_ID_PREFIX + safeHashCode;
      final int dueIdBase = PILL_ADVANCE_REMINDER_ID_PREFIX + safeHashCode;
      final int missedIdBase = MISSED_NOTIFICATION_ID_PREFIX + safeHashCode;

      // Cancel all notifications in these ranges (up to 100 days, 10 times per day)
      for (int day = 0; day < 100; day++) {
        for (int timeIndex = 0; timeIndex < 10; timeIndex++) {
          final timeSlotId = timeIndex * 1000;
          final reminderId = dueIdBase + day + timeSlotId;
          final exactTimeId = reminderIdBase + day + timeSlotId;
          final missedId = missedIdBase + day + timeSlotId;

          await notificationsPlugin.cancel(reminderId);
          await notificationsPlugin.cancel(exactTimeId);
          await notificationsPlugin.cancel(missedId);
        }
      }

      print('Canceled all notifications for pill ID: $pillId');
    } catch (e) {
      print('Error canceling pill notifications: $e');
    }
  }

  // Cancel notifications for a specific pill time slot
  Future<void> cancelPillTimeNotifications(
      String pillId, int day, int timeIndex) async {
    try {
      // Calculate ID ranges for this pill using a safe hash code
      final int safeHashCode = pillId.hashCode % 10000; // Limit to 4 digits
      final int reminderIdBase = PILL_REMINDER_ID_PREFIX + safeHashCode;
      final int dueIdBase = PILL_ADVANCE_REMINDER_ID_PREFIX + safeHashCode;
      final int missedIdBase = MISSED_NOTIFICATION_ID_PREFIX + safeHashCode;

      // Calculate IDs for this specific time slot
      final timeSlotId = timeIndex * 1000;
      final reminderId = dueIdBase + day + timeSlotId;
      final exactTimeId = reminderIdBase + day + timeSlotId;
      final missedId = missedIdBase + day + timeSlotId;

      // Cancel notifications for this specific time slot
      List<Future<void>> cancelTasks = [
        notificationsPlugin.cancel(reminderId),
        notificationsPlugin.cancel(exactTimeId),
        notificationsPlugin.cancel(missedId)
      ];

      // Execute all cancellation tasks in parallel
      await Future.wait(cancelTasks);

      print(
          'Canceled notifications for pill ID: $pillId, day: $day, timeIndex: $timeIndex');
    } catch (e) {
      print('Error canceling pill time notifications: $e');
    }
  }

  // Store notification in Firestore
  Future<void> _storeNotification({
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .add({
        'title': title,
        'message': body,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': type,
        'data': data,
      });

      print('📝 Notification stored in Firestore');
    } catch (e) {
      print('❌ Error storing notification in Firestore: $e');
    }
  }

  // After showing a notification, store it in Firestore
  Future<void> _saveNotificationToFirestore(String? title, String? body) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _storeNotification(
        title: title ?? 'Notification',
        body: body ?? '',
      );
    } catch (e) {
      print('Error saving notification to Firestore: $e');
    }
  }

  // Show an immediate notification
  Future<void> showNotification({
    required int id,
    String? title,
    String? body,
    required NotificationDetails notificationDetails,
    String? payload,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    if (!_isInitialized) await initNotification();

    await notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    // Store notification in Firestore after showing it
    await _storeNotification(
      title: title ?? 'Notification',
      body: body ?? '',
      type: type,
      data: data,
    );
  }

  // Check for pending notifications for the current user
  Future<void> checkPendingNotifications() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Check if there are any pending notifications in Firestore
      final pendingNotifications = await FirebaseFirestore.instance
          .collection('pending_notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('delivered', isEqualTo: false)
          .get();

      if (pendingNotifications.docs.isNotEmpty) {
        for (var doc in pendingNotifications.docs) {
          final data = doc.data();
          final title = data['title'] as String?;
          final body = data['body'] as String?;
          final notificationData = data['data'] as Map<String, dynamic>?;

          // Show the notification locally
          if (title != null && body != null) {
            if (notificationData != null &&
                notificationData['type'] == 'message') {
              // For message notifications
              await notificationsPlugin.show(
                MESSAGE_NOTIFICATION_ID_PREFIX + doc.id.hashCode % 10000,
                title,
                body,
                messageDetails(),
                payload:
                    'message:${notificationData['chatId'] ?? ''}:${notificationData['senderId'] ?? ''}:${notificationData['senderName'] ?? ''}',
              );
            } else {
              // For other types of notifications
              await notificationsPlugin.show(
                doc.id.hashCode,
                title,
                body,
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    'high_importance_channel',
                    'High Importance Notifications',
                    channelDescription:
                        'This channel is used for important notifications.',
                    importance: Importance.high,
                    priority: Priority.high,
                    icon: 'notification_icon',
                  ),
                  iOS: const DarwinNotificationDetails(),
                ),
              );
            }
          }

          // Mark as delivered
          await FirebaseFirestore.instance
              .collection('pending_notifications')
              .doc(doc.id)
              .update({'delivered': true});
        }
      }
    } catch (e) {
      print('Error checking pending notifications: $e');
    }
  }

  // Check specifically for pending message notifications
  Future<void> checkPendingMessageNotifications() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Check if there are any pending message notifications in Firestore
      final pendingNotifications = await FirebaseFirestore.instance
          .collection('pending_notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('delivered', isEqualTo: false)
          .get();

      if (pendingNotifications.docs.isNotEmpty) {
        for (var doc in pendingNotifications.docs) {
          final data = doc.data();
          final title = data['title'] as String?;
          final body = data['body'] as String?;
          final notificationData = data['data'] as Map<String, dynamic>?;

          // Process only message notifications
          if (title != null &&
              body != null &&
              notificationData != null &&
              notificationData['type'] == 'message') {
            // Show the message notification
            await notificationsPlugin.show(
              MESSAGE_NOTIFICATION_ID_PREFIX + doc.id.hashCode % 10000,
              title,
              body,
              messageDetails(),
              payload:
                  'message:${notificationData['chatId'] ?? ''}:${notificationData['senderId'] ?? ''}:${notificationData['senderName'] ?? ''}',
            );

            // Mark as delivered
            await FirebaseFirestore.instance
                .collection('pending_notifications')
                .doc(doc.id)
                .update({'delivered': true});
          }
        }
      }
    } catch (e) {
      print('Error checking pending message notifications: $e');
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
      // Use the centralized FCM service instead
      if (!_fcmService.isInitialized) {
        await _fcmService.initialize();
      }

      // Handle FCM messages when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        // Force show the notification even when app is in foreground
        _showFcmNotification(message);

        if (message.notification != null) {
          print(
              'Message also contained a notification: ${message.notification}');
        }
      });

      // Handle notification click when app is in background or terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('A notification was clicked on: ${message.data}');
        _handleNotificationClick(message.data);
      });

      // Check for initial notification that launched the app
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        print('App was launched by notification: ${initialMessage.data}');
        _handleNotificationClick(initialMessage.data);
      }
    } catch (e) {
      print('Error initializing FCM: $e');
    }
  }

  // Show FCM notification from message
  void _showFcmNotification(RemoteMessage message) {
    try {
      final notification = message.notification;
      final android = message.notification?.android;
      final data = message.data;

      // Always show notifications regardless of app state
      NotificationDetails details;
      String? payload;

      // Determine notification details based on type
      if (data.containsKey('type')) {
        final type = data['type'];

        if (type == 'message') {
          details = messageDetails();
          // Create a payload for message notifications
          final chatId = data['chatId'] ?? '';
          final senderId = data['senderId'] ?? '';
          final senderName = data['senderName'] ?? '';
          payload = 'message:$chatId:$senderId:$senderName';
        } else if (type == 'pill_taken') {
          details = takenPillDetails();
          payload = 'pill_taken:${data['pillId'] ?? ''}';
        } else if (type == 'pill_missed') {
          details = missedPillDetails();
          payload = 'pill_missed:${data['pillId'] ?? ''}';
        } else {
          // Default notification details
          details = NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription:
                  'This channel is used for important notifications.',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'notification_icon',
            ),
            iOS: const DarwinNotificationDetails(),
          );
        }
      } else {
        // Default notification details
        details = NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'notification_icon',
          ),
          iOS: const DarwinNotificationDetails(),
        );
      }

      // Show the notification
      if (notification != null) {
        // For message notifications, we use the pre-decrypted text from messaging_tab.dart
        // The message is already decrypted before being sent to FCM
        String notificationBody = notification.body ?? 'New message';

        // No need to modify the notification body as it's already decrypted in messaging_tab.dart
        notificationsPlugin.show(
          message.hashCode,
          notification.title,
          notificationBody,
          details,
          payload: payload,
        );

        print('Showed FCM notification in foreground: ${notification.title}');
      } else if (data.isNotEmpty) {
        // Handle data-only messages (no notification payload)
        final title = data['title'] ?? 'Notification';
        final body = data['body'] ?? '';

        notificationsPlugin.show(
          data.hashCode,
          title,
          body,
          details,
          payload: payload,
        );

        print('Showed data-only FCM notification in foreground: $title');
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
      // Use the centralized FCM service
      final success = await _fcmService.sendNotification(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );

      if (success) {
        print('FCM notification sent successfully to $userId');
      } else {
        print('FCM notification sending failed, will be retried later');
      }
    } catch (e) {
      print('Error sending FCM notification: $e');
    }
  }

  // Handle notification click based on notification type
  void _handleNotificationClick(Map<String, dynamic> data) {
    try {
      final type = data['type'];

      // Handle different notification types
      if (type == 'message') {
        final chatId = data['chatId'];
        final senderId = data['senderId'];
        final senderName = data['senderName'];

        // Navigate to messaging tab with the chat info
        navigatorKey.currentState?.pushNamed(
          'Messaging',
          arguments: {
            'chatId': chatId,
            'senderId': senderId,
            'senderName': senderName,
          },
        );
      } else if (type == 'pill_taken') {
        // Navigate to calendar tab
        navigatorKey.currentState
            ?.pushNamed('Home', arguments: {'tabIndex': 0});
      } else if (type == 'pill_missed') {
        // Navigate to calendar tab
        navigatorKey.currentState
            ?.pushNamed('Home', arguments: {'tabIndex': 0});
      }
    } catch (e) {
      print('Error handling notification click: $e');
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await notificationsPlugin.cancelAll();
      print('All notifications canceled');
    } catch (e) {
      print('Error canceling all notifications: $e');
    }
  }
}

// App lifecycle observer to track foreground state
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final NotiService _notiService;

  _AppLifecycleObserver(this._notiService);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _notiService.setForegroundState(state == AppLifecycleState.resumed);
  }
}
