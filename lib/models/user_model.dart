import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String id;
  String name;
  String email;
  String role;
  int age;
  double height;
  String sharedUsers;
  double? latitude;
  double? longitude;
  DateTime? lastLocationUpdate;
  String? timezone;
  String? fcmToken;

  UserModel({
    this.id = "",
    required this.name,
    required this.email,
    this.role = "",
    this.age = 0,
    this.height = 0,
    this.sharedUsers = "",
    this.latitude,
    this.longitude,
    this.lastLocationUpdate,
    this.timezone,
    this.fcmToken,
  });

  UserModel.fromJson(Map<String, dynamic> json, String id)
      : this(
          id: json['id'],
          name: json['name'],
          email: json['email'],
          role: json['role'],
          age: json['age'],
          height: json['height'],
          sharedUsers: json['sharedUsers'],
          latitude: json['latitude']?.toDouble(),
          longitude: json['longitude']?.toDouble(),
          lastLocationUpdate: json['lastLocationUpdate'] != null
              ? (json['lastLocationUpdate'] as Timestamp).toDate()
              : null,
          timezone: json['timezone'],
          fcmToken: json['fcmToken'],
        );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'age': age,
      'height': height,
      'sharedUsers': sharedUsers,
      'latitude': latitude,
      'longitude': longitude,
      'lastLocationUpdate': lastLocationUpdate != null
          ? Timestamp.fromDate(lastLocationUpdate!)
          : null,
      'timezone': timezone,
      'fcmToken': fcmToken,
    };
  }
}
