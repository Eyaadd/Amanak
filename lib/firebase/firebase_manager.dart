import 'package:amanak/models/user_model.dart';
import 'package:amanak/models/pill_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:amanak/notifications/noti_service.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:cloud_functions/cloud_functions.dart';

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
        final isTakenToday = pill.takenDates.containsKey(todayStr);

        if (isTakenToday) {
          // Cancel notifications if pill is taken today
          await notiService.cancelPillNotifications(pill.id);

          // Notify guardian about the pill being taken
          final sharedUserEmail = userData['sharedUsers'] ?? '';
          if (sharedUserEmail.isNotEmpty) {
            print(
                'Elder marked pill as taken: ${pill.name}. Notifying guardian...');
            await notiService.notifyGuardianOfTakenPill(currentUser.uid, pill);
          } else {
            print(
                'No shared user (guardian) found for elder. Cannot send notification.');
          }
        } else if (pill.missed) {
          // Cancel regular notifications and notify guardian
          await notiService.cancelPillNotifications(pill.id);

          // Notify guardian about missed pill
          final sharedUserEmail = userData['sharedUsers'] ?? '';
          if (sharedUserEmail.isNotEmpty) {
            print('Pill marked as missed: ${pill.name}. Notifying guardian...');
            await notiService.notifyGuardianOfMissedPill(currentUser.uid, pill);
          } else {
            print(
                'No shared user (guardian) found for elder. Cannot send notification.');
          }
        } else {
          // Reschedule notifications if pill is reset
          await notiService.schedulePillNotifications(pill);
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

    // Cancel all existing notifications first
    for (final pill in pills) {
      await notiService.cancelPillNotifications(pill.id);
    }

    // Schedule new notifications
    for (final pill in pills) {
      await notiService.schedulePillNotifications(pill);
    }
  }

  // Check for missed pills and update their status
  static Future<void> checkForMissedPills() async {
    try {
      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get user role to determine notification behavior
      final userData = await getNameAndRole(currentUser.uid);
      final userRole = userData['role'] ?? '';

      // Only check for missed pills for elder users, not for guardians
      if (userRole != 'guardian') {
        // Get all pills for the user
        final pillsSnapshot = await getPillsCollection(currentUser.uid).get();

        // Current time
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Check each pill
        for (var pillDoc in pillsSnapshot.docs) {
          final pill = pillDoc.data();
          final pillId = pill.id;

          // Skip if already taken today or already marked as missed
          if (pill.isTakenOnDate(today) || pill.missed) continue;

          // Check if the pill is scheduled for today or a past date
          final pillStartDate = DateTime(
              pill.dateTime.year, pill.dateTime.month, pill.dateTime.day);

          // Skip pills scheduled for future dates - they can't be missed yet
          if (pillStartDate.isAfter(today)) continue;

          // Only check pills that are within their treatment period
          final daysSinceStart = today.difference(pillStartDate).inDays;
          if (daysSinceStart < 0 || daysSinceStart >= pill.duration) continue;

          // Check if pill time has passed (more than 5 minutes ago)
          for (final dynamic timeObj in pill.times) {
            int hour = 8; // Default value
            int minute = 0; // Default value

            try {
              // Try to get hour and minute based on the object type
              if (timeObj is TimeOfDay) {
                // If it's already a TimeOfDay object
                hour = timeObj.hour;
                minute = timeObj.minute;
              } else {
                // Try to access as a Map
                final dynamic hourValue = timeObj['hour'];
                final dynamic minuteValue = timeObj['minute'];

                if (hourValue != null) {
                  hour = hourValue is int ? hourValue : 8;
                }

                if (minuteValue != null) {
                  minute = minuteValue is int ? minuteValue : 0;
                }
              }
            } catch (e) {
              print('Error parsing time object: $e');
              // Use default values
            }

            final pillTime = DateTime(
              now.year,
              now.month,
              now.day,
              hour,
              minute,
            );
            if (now.difference(pillTime).inMinutes > 5) {
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
                      body:
                          "You missed taking: ${pill.name}. Please take it as soon as possible.",
                      notificationDetails: notiService.missedPillDetails(),
                      payload: "missed:${pill.id}:${today.toIso8601String()}",
                    );

                    // Send direct FCM notification to guardian about missed pill
                    await _sendDirectMissedPillNotification(
                        guardianId: guardianId,
                        pillName: pill.name,
                        elderName: elderName);
                  }
                }
              }
              break; // Only need to mark as missed once
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
  }) async {
    try {
      // Get guardian's FCM token
      final guardianDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(guardianId)
          .get();

      if (!guardianDoc.exists) {
        print('Guardian document not found');
        return;
      }

      final guardianData = guardianDoc.data();
      if (guardianData == null) return;

      final fcmToken = guardianData['fcmToken'];
      if (fcmToken == null || fcmToken.isEmpty) {
        print('FCM token not found for guardian');
        return;
      }

      // Prepare notification message
      final title = "Pill Missed Alert";
      final body = "$elderName missed their medicine: $pillName.";

      // Prepare notification payload with additional fields to ensure proper handling
      final message = {
        'token': fcmToken,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'type': 'pill_missed',
          'pillName': pillName,
          'elderName': elderName,
          'title': title, // Duplicate in data for data-only messages
          'body': body, // Duplicate in data for data-only messages
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        'android': {
          'priority': 'high',
          'notification': {
            'channel_id': 'high_importance_channel',
            'priority': 'high',
          }
        },
        'apns': {
          'payload': {
            'aps': {
              'sound': 'default',
              'badge': 1,
              'content-available': 1,
            }
          }
        }
      };

      // Send via Cloud Functions
      try {
        final functions = FirebaseFunctions.instance;
        final callable = functions.httpsCallable('sendNotification');
        print('Calling Cloud Function directly for missed pill notification');
        final result = await callable.call(message);
        print(
            'Missed pill notification sent via Cloud Functions: ${result.data}');

        // Store notification in Firestore for the guardian
        await FirebaseFirestore.instance
            .collection('users')
            .doc(guardianId)
            .collection('notifications')
            .add({
          'title': title,
          'message': body,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'pill_missed',
          'data': {
            'pillName': pillName,
            'elderName': elderName,
          },
        });
      } catch (e) {
        print('Error sending direct missed pill notification: $e');
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
            'title': title,
            'body': body,
          },
          'timestamp': FieldValue.serverTimestamp(),
          'delivered': false,
        });
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
