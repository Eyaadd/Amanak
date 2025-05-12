class UserModel {
  String id;
  String name;
  String email;
  String role;
  int age;

  UserModel({
    this.id = "",
    required this.name,
    required this.email,
     this.role = "",
     this.age = 0,
  });

   UserModel.fromJson(Map<String, dynamic> json):this (
      name: json['name'],
      email: json['email'],
      role: json['role'],
      age: json['age'],
   );

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'age': age,
    };
  }
}
