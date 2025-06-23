import 'package:amanak/models/user_model.dart';
import 'package:amanak/models/pill_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:amanak/notifications/noti_service.dart';

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
        if (pill.taken) {
          // Cancel notifications if pill is taken
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

        // Check each pill
        for (var pillDoc in pillsSnapshot.docs) {
          final pill = pillDoc.data();
          final pillId = pill.id;

          // Skip if already taken or already marked as missed
          if (pill.taken || pill.missed) continue;

          // Check if pill time has passed (more than 5 minutes ago)
          for (final t in pill.times) {
            final pillTime = DateTime(
              now.year,
              now.month,
              now.day,
              t['hour'] ?? 8,
              t['minute'] ?? 0,
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
                    // Send notification directly to guardian
                    await notiService.showNotification(
                      id: NotiService.MISSED_NOTIFICATION_ID_PREFIX +
                          pillId.hashCode % 10000,
                      title: "Pill Missed Alert",
                      body:
                          "Your shared user ${elderName} missed their medicine: ${pill.name}.",
                      details: notiService.missedPillDetails(),
                    );
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
}
