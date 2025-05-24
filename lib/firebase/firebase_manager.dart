import 'package:amanak/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseManager {
  static CollectionReference<UserModel> getUsersCollection() {
    return FirebaseFirestore.instance.collection("users").withConverter(
      fromFirestore: (snapshot, _) {
        return UserModel.fromJson(snapshot.data()!);
      },
      toFirestore: (value, _) {
        return value.toJson();
      },
    );
  }

 static Future<void> setUser(UserModel user){
    var collection = getUsersCollection();
    var docRef = collection.doc();
    user.id = docRef.id;
    return docRef.set(user);
 }

  static Future<void> updateEvent(UserModel user) {
    var collection = getUsersCollection();
    return collection.doc(user.id).update(user.toJson());
  }

  static Future<Map<String, String>> getNameAndRole(String userId) async {
    try {
      var collection = getUsersCollection();
      DocumentSnapshot<UserModel> docSnapshot = await collection.doc(userId).get();
      
      if (!docSnapshot.exists) {
        // If not found, try to find the user by email
        QuerySnapshot<UserModel> querySnapshot = await collection
            .where('email', isEqualTo: FirebaseAuth.instance.currentUser?.email)
            .get();
            
        if (querySnapshot.docs.isNotEmpty) {
          docSnapshot = querySnapshot.docs.first;
        }
      }
      
      if (docSnapshot.exists) {
        UserModel user = docSnapshot.data()!;
        print('Found user data: ${user.toJson()}'); // Debug print
        return {
          'name': user.name,
          'email': user.email,
          'role': user.role,
        };
      }
      
      print('No user document found for ID: $userId'); // Debug print
      return {
        'name': 'User Name',
        'email': 'user@email.com',
        'role': '',
      };
    } catch (e) {
      print('Error getting user data: $e');
      return {
        'name': 'User Name',
        'email': 'user@email.com',
        'role': '',
      };
    }
  }
}
