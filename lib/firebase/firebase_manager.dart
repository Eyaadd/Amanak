import 'package:amanak/models/user_model.dart';
import 'package:amanak/models/pill_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:amanak/notifications/noti_service.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:amanak/services/fcm_service.dart';

class FirebaseManager {
  static CollectionReference<UserModel> getUsersCollection() {
    return FirebaseFirestore.instance.collection("users").withConverter(
      fromFirestore: (snapshot, _) {
        return UserModel.fromJson(snapshot.data()!, snapshot.id);
      },
      toFirestore: (value, _) {
        return value.toJson();
      },
    );
  }

  static Future<void> setUser(UserModel user) {
    var collection = getUsersCollection();
    var currentUser = FirebaseAuth.instance.currentUser!;
    var docRef = collection.doc(currentUser.uid); // ✅ use UID
    return docRef.set(user);
  }

  static Future<void> updateEvent(UserModel user) {
    var collection = getUsersCollection();
    return collection.doc(user.id).update(user.toJson());
  }

  static Future<Map<String, String>> getNameAndRole(String userId) async {
    try {
      var collection = getUsersCollection();
      DocumentSnapshot<UserModel> docSnapshot =
          await collection.doc(userId).get();

      if (!docSnapshot.exists) {
        print("Didn't Find $userId");
        QuerySnapshot<UserModel> querySnapshot = await collection
            .where('email', isEqualTo: FirebaseAuth.instance.currentUser?.email)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          docSnapshot = querySnapshot.docs.first;
        }
      }

      if (docSnapshot.exists) {
        print("Found $userId");
        UserModel user = docSnapshot.data()!;
        return {
          'name': user.name,
          'email': user.email,
          'role': user.role,
          'id': user.id,
          'sharedUsers': user.sharedUsers,
          'timezone': user.timezone ?? '',
        };
      }

      return {
        'name': 'User Name',
        'email': 'user@email.com',
        'role': '',
        'id': '',
        'sharedUsers': '',
        'timezone': '',
      };
    } catch (e) {
      print('Error getting user data: $e');
      return {
        'name': 'User Name',
        'email': 'user@email.com',
        'role': '',
        'id': '',
        'sharedUsers': '',
        'timezone': '',
      };
    }
  }

  static Future<void> linkUser(
      String currentUserId, String sharedEmail, String currentUserEmail) async {
    final firestore = FirebaseFirestore.instance;

    // Check if the shared user exists
    final query = await firestore
        .collection('users')
        .where('email', isEqualTo: sharedEmail)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final sharedUserDoc = query.docs.first;
      final sharedUserId = sharedUserDoc.id;

      // Update current user with sharedEmail
      await firestore.collection('users').doc(currentUserId).update({
        'sharedUsers': sharedEmail,
      });

      // Update shared user with currentUserEmail
      await firestore.collection('users').doc(sharedUserId).update({
        'sharedUsers': currentUserEmail,
      });
    } else {
      throw Exception("User with this email doesn't exist.");
    }
  }

  // Pills collection methods
  static CollectionReference<PillModel> getPillsCollection(String userId) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("pills")
        .withConverter(
      fromFirestore: (snapshot, _) {
        return PillModel.fromJson(snapshot.data()!, snapshot.id);
      },
      toFirestore: (value, _) {
        return value.toJson();
      },
    );
  }

  static Future<String> addPill(PillModel pill, {String? userId}) async {
    final currentUserId = userId ?? FirebaseAuth.instance.currentUser!.uid;
    var collection = getPillsCollection(currentUserId);
    DocumentReference docRef = await collection.add(pill);

    // Update the pill with the new ID and schedule notifications
    final pillWithId = pill.copyWith(id: docRef.id);
    await pillWithId.scheduleNotifications();

    return docRef.id;
  }

  static Future<void> updatePill(PillModel pill) async {
    try {
      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Get user role to determine notification behavior
      final userData = await getNameAndRole(currentUser.uid);
      final userRole = userData['role'] ?? '';

      // Update pill in Firebase
      await getPillsCollection(currentUser.uid)
          .doc(pill.id)
          .update(pill.toJson());

      // Handle notifications based on pill status and user role
      final notiService = NotiService();

      // Only process notifications for elder users, not for guardians viewing elder's pills
      if (userRole != 'guardian') {
        final today = DateTime.now();
        final todayStr = '${today.year}-${today.month}-${today.day}';

        // Check for newly taken times
        for (int i = 0; i < pill.times.length; i++) {
          final timeKey = '$todayStr-$i';
          if (pill.takenDates.containsKey(timeKey)) {
            // Check if the pill was taken before its scheduled time
            final pillTime = DateTime(
              today.year,
              today.month,
              today.day,
              pill.times[i].hour,
              pill.times[i].minute,
            );

            final takenTime = pill.takenDates[timeKey]!;

            // Only notify if the pill was taken at or after its scheduled time
            // or within 15 minutes before the scheduled time (reasonable early window)
            if (takenTime.isAfter(pillTime) ||
                pillTime.difference(takenTime).inMinutes <= 15) {
              // Calculate the day index from the start date
              final startDate = pill.dateTime;
              final dayDifference = today.difference(startDate).inDays;

              // Cancel notifications only for this specific time slot
              await notiService.cancelPillTimeNotifications(
                  pill.id, dayDifference, i);

              // Notify guardian about the pill being taken
              final sharedUserEmail = userData['sharedUsers'] ?? '';
              if (sharedUserEmail.isNotEmpty) {
                print(
                    'Elder marked pill as taken: ${pill.name} at time $timeKey. Notifying guardian...');
                await notiService.notifyGuardianOfTakenPill(
                    currentUser.uid, pill);
              } else {
                print(
                    'No shared user (guardian) found for elder. Cannot send notification.');
              }
            } else {
              print(
                  'Pill marked as taken before scheduled time - no notification sent from Firebase Manager');
            }
          }
        }

        // If all times for today are taken, clear missed status
        bool allTimesTaken = true;
        for (int i = 0; i < pill.times.length; i++) {
          final timeKey = '$todayStr-$i';
          if (!pill.takenDates.containsKey(timeKey)) {
            allTimesTaken = false;
            break;
          }
        }

        if (allTimesTaken && pill.missed) {
          // Update pill to clear missed status
          final updatedPill = pill.copyWith(missed: false);
          await getPillsCollection(currentUser.uid)
              .doc(pill.id)
              .update(updatedPill.toJson());
        }

        // If pill is newly marked as missed, notify guardian
        if (pill.missed) {
          // Cancel regular notifications for today
          final startDate = pill.dateTime;
          final dayDifference = today.difference(startDate).inDays;

          // Cancel notifications for all time slots today
          for (int i = 0; i < pill.times.length; i++) {
            await notiService.cancelPillTimeNotifications(
                pill.id, dayDifference, i);
          }

          // Notify guardian about missed pill
          final sharedUserEmail = userData['sharedUsers'] ?? '';
          if (sharedUserEmail.isNotEmpty) {
            print('Pill marked as missed: ${pill.name}. Notifying guardian...');
            await notiService.notifyGuardianOfMissedPill(currentUser.uid, pill);
          } else {
            print(
                'No shared user (guardian) found for elder. Cannot send notification.');
          }
        }
      } else {
        print('Guardian user updating pill - not sending notifications');
      }
    } catch (e) {
      print('Error updating pill: $e');
      throw Exception('Error updating pill: $e');
    }
  }

  static Future<void> deletePill(String pillId, {String? userId}) async {
    final currentUserId = userId ?? FirebaseAuth.instance.currentUser!.uid;
    var collection = getPillsCollection(currentUserId);

    // Get the pill to cancel its notifications
    final pillDoc = await collection.doc(pillId).get();
    if (pillDoc.exists) {
      final pill = pillDoc.data()!;
      await pill.cancelNotifications();
    }

    // Delete from Firestore
    return collection.doc(pillId).delete();
  }

  static Stream<List<PillModel>> getPillsStream({String? userId}) {
    final currentUserId = userId ?? FirebaseAuth.instance.currentUser!.uid;
    var collection = getPillsCollection(currentUserId);
    return collection
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  static Future<List<PillModel>> getPills({String? userId}) async {
    final currentUserId = userId ?? FirebaseAuth.instance.currentUser!.uid;
    var collection = getPillsCollection(currentUserId);
    var snapshot = await collection.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  static Future<List<PillModel>> getPillsForDateRange(
      String userId, DateTime startDate, DateTime endDate) async {
    var collection = getPillsCollection(userId);
    var snapshot = await collection.get();
    var allPills = snapshot.docs.map((doc) => doc.data()).toList();

    // Filter pills that fall within the date range
    return allPills.where((pill) {
      final pillStartDate =
          DateTime(pill.dateTime.year, pill.dateTime.month, pill.dateTime.day);
      final pillEndDate = pillStartDate.add(Duration(days: pill.duration));
      return !pillStartDate.isAfter(endDate) &&
          !pillEndDate.isBefore(startDate);
    }).toList();
  }

  // Helper method to find a user by email
  static Future<Map<String, String>?> getUserByEmail(String email) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final query = await firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'role': data['role'] ?? '',
          'sharedUsers': data['sharedUsers'] ?? '',
          'timezone': data['timezone'] ?? '',
        };
      }
      return null;
    } catch (e) {
      print('Error finding user by email: $e');
      return null;
    }
  }

  // Reschedule all notifications for a user
  static Future<void> rescheduleAllNotifications({String? userId}) async {
    final currentUserId = userId ?? FirebaseAuth.instance.currentUser!.uid;
    final pills = await getPills(userId: currentUserId);

    final notiService = NotiService();

    // Get user data to check role
    final userData = await getNameAndRole(currentUserId);
    final userRole = userData['role'] ?? '';

    // Only schedule notifications for elder users, not for guardians
    if (userRole.toLowerCase() != 'guardian') {
      print('Rescheduling notifications for ${pills.length} pills');

      // Cancel all existing notifications first
      await notiService.cancelAllNotifications();

      // Only schedule future pills that haven't been taken or missed
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int scheduledCount = 0;

      // Schedule new notifications only for active pills
      for (final pill in pills) {
        // Skip pills that have already ended their duration
        final pillStartDate = DateTime(
            pill.dateTime.year, pill.dateTime.month, pill.dateTime.day);
        final daysSinceStart = today.difference(pillStartDate).inDays;

        // Only schedule if the pill is still active (within duration and not completely taken/missed)
        if (daysSinceStart < pill.duration) {
          await notiService.schedulePillNotifications(pill);
          scheduledCount++;
        }
      }

      print(
          'Successfully rescheduled notifications for $scheduledCount active pills');
    } else {
      print('User is a guardian, not rescheduling pill notifications');
    }
  }

  // Initialize timezone data
  static bool _tzInitialized = false;
  static Future<void> _ensureTimezoneInitialized() async {
    if (!_tzInitialized) {
      tz_data.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  // Check for missed pills
  static Future<void> checkForMissedPills() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get user data to check role
      final userData = await getNameAndRole(currentUser.uid);
      final userRole = userData['role'] ?? '';

      // Only check for missed pills for elder users, not guardians
      if (userRole.toLowerCase() != 'guardian') {
        // Initialize timezone
        tz_data.initializeTimeZones();
        final String timezone = userData['timezone'] ?? 'UTC';
        final tzLocation = tz.getLocation(timezone);
        final now = tz.TZDateTime.now(tzLocation);
        final today = tz.TZDateTime(tzLocation, now.year, now.month, now.day);

        print(
            'Checking missed pills at ${now.toString()} (${tzLocation.name})');

        // Get all pills
        final pillsSnapshot = await getPillsCollection(currentUser.uid).get();

        // Check each pill
        for (var pillDoc in pillsSnapshot.docs) {
          final pill = pillDoc.data();
          final pillId = pill.id;

          // Skip if already marked as missed
          if (pill.missed) continue;

          // Check if the pill is scheduled for today or a past date
          final pillStartDate = tz.TZDateTime(tzLocation, pill.dateTime.year,
              pill.dateTime.month, pill.dateTime.day);

          // Skip pills scheduled for future dates - they can't be missed yet
          if (pillStartDate.isAfter(today)) continue;

          // Only check pills that are within their treatment period
          final daysSinceStart = today.difference(pillStartDate).inDays;
          if (daysSinceStart < 0 || daysSinceStart >= pill.duration) continue;

          // Check if this pill was already taken today
          final dateStr = '${today.year}-${today.month}-${today.day}';
          final isTakenToday = pill.takenDates.containsKey(dateStr);

          // If the pill was taken today, skip checking for missed times
          if (isTakenToday) continue;

          // Track if any time was missed
          bool anyTimeMissed = false;
          List<String> missedTimeStrings = [];

          // Check each time for this pill
          for (int i = 0; i < pill.times.length; i++) {
            final timeObj = pill.times[i];

            // Extract hour and minute
            int hour = timeObj.hour;
            int minute = timeObj.minute;

            // Create pill time using user's timezone
            final pillTime = tz.TZDateTime(
              tzLocation,
              now.year,
              now.month,
              now.day,
              hour,
              minute,
            );

            final diffMinutes = now.difference(pillTime).inMinutes;
            print(
                'Pill ${pill.name} time ${i + 1}/${pill.times.length}: ${pillTime.toString()}, diff: $diffMinutes minutes');

            // Check if this specific time was missed (15+ minutes ago)
            if (diffMinutes > 15) {
              anyTimeMissed = true;

              // Format time for notification
              final formattedHour =
                  hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
              final formattedMinute = minute.toString().padLeft(2, '0');
              final period = hour >= 12 ? 'PM' : 'AM';
              missedTimeStrings.add('$formattedHour:$formattedMinute $period');
            }
          }

          // If any time was missed, mark the pill as missed and send notifications
          if (anyTimeMissed) {
            // Mark as missed in Firebase directly
            await getPillsCollection(currentUser.uid)
                .doc(pillId)
                .update({'missed': true});

            // Handle notifications
            final notiService = NotiService();
            await notiService.cancelPillNotifications(pillId);

            // Get user data for notification
            final elderName = userData['name'] ?? 'Elder';
            final sharedUserEmail = userData['sharedUsers'] ?? '';

            // Create notification message with missed times
            final missedTimesText = missedTimeStrings.join(', ');
            final notificationBody =
                "You missed taking: ${pill.name} at $missedTimesText. Please take it as soon as possible.";

            // Notify guardian if needed
            if (sharedUserEmail.isNotEmpty) {
              final guardianData = await getUserByEmail(sharedUserEmail);
              if (guardianData != null) {
                final guardianId = guardianData['id'] ?? '';
                if (guardianId.isNotEmpty) {
                  // Show notification to elder
                  await notiService.showNotification(
                    id: NotiService.MISSED_NOTIFICATION_ID_PREFIX +
                        // Use date hash to create unique ID
                        pill.dateTime.hashCode % 10000,
                    title: "Missed Medicine",
                    body: notificationBody,
                    notificationDetails: notiService.missedPillDetails(),
                    payload: "missed:${pill.id}:${today.toIso8601String()}",
                  );

                  // Send direct FCM notification to guardian about missed pill
                  await _sendDirectMissedPillNotification(
                      guardianId: guardianId,
                      pillName: pill.name,
                      elderName: elderName,
                      missedTimes: missedTimesText);
                }
              }
            }
          }
        }
      } else {
        print('Guardian user - skipping missed pill check');
      }
    } catch (e) {
      print('Error checking for missed pills: $e');
    }
  }

  static Future<void> _sendDirectMissedPillNotification({
    required String guardianId,
    required String pillName,
    required String elderName,
    required String missedTimes,
  }) async {
    try {
      // Use the centralized FCM service
      final fcmService = FCMService();

      // Prepare notification data
      final title = "Pill Missed Alert";
      final body =
          "$elderName missed their medicine: $pillName. Missed times: $missedTimes.";

      // Try to send notification using FCM service
      bool fcmSuccess = false;
      try {
        fcmSuccess = await fcmService.sendNotification(
          userId: guardianId,
          title: title,
          body: body,
          data: {
            'type': 'pill_missed',
            'pillName': pillName,
            'elderName': elderName,
            'missedTimes': missedTimes,
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          },
          highPriority: true,
        );
      } catch (fcmError) {
        print('Error sending FCM notification: $fcmError');
        fcmSuccess = false;
      }

      // If FCM failed, fall back to storing in Firestore directly
      if (!fcmSuccess) {
        print(
            'FCM notification failed, storing in Firestore for later delivery');

        // Store for later delivery
        await FirebaseFirestore.instance
            .collection('pending_notifications')
            .add({
          'userId': guardianId,
          'title': title,
          'body': body,
          'data': {
            'type': 'pill_missed',
            'pillName': pillName,
            'elderName': elderName,
            'missedTimes': missedTimes,
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          },
          'timestamp': FieldValue.serverTimestamp(),
          'delivered': false,
          'attempts': 1,
          'lastAttempt': FieldValue.serverTimestamp(),
        });
      } else {
        print('Missed pill notification sent successfully to guardian');
      }
    } catch (e) {
      print('Error in _sendDirectMissedPillNotification: $e');
    }
  }

  // Ensure Firebase Auth is properly initialized
  static Future<void> ensureAuthInitialized() async {
    try {
      // Check if there's a current user
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Force refresh the token to ensure it's valid
        await user.getIdToken(true);
        print('Firebase Auth token refreshed successfully');
      } else {
        print('No user is currently signed in');
      }
    } catch (e) {
      print('Error ensuring Firebase Auth is initialized: $e');
    }
  }
}
