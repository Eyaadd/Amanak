import 'package:amanak/models/user_model.dart';
import 'package:amanak/models/pill_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
          'sharedUsers': user.sharedUsers
        };
      }

      return {
        'name': 'User Name',
        'email': 'user@email.com',
        'role': '',
        'id': '',
        'sharedUsers': ''
      };
    } catch (e) {
      print('Error getting user data: $e');
      return {
        'name': 'User Name',
        'email': 'user@email.com',
        'role': '',
        'id': '',
        'sharedUsers': ''
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
    return docRef.id;
  }

  static Future<void> updatePill(PillModel pill, {String? userId}) async {
    final currentUserId = userId ?? FirebaseAuth.instance.currentUser!.uid;
    var collection = getPillsCollection(currentUserId);
    return collection.doc(pill.id).update(pill.toJson());
  }

  static Future<void> deletePill(String pillId, {String? userId}) async {
    final currentUserId = userId ?? FirebaseAuth.instance.currentUser!.uid;
    var collection = getPillsCollection(currentUserId);
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
}
