import 'package:amanak/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

}
