class UserModel {
  String id;
  String name;
  String email;
  String role;
  int age;
  double height;
  String sharedUsers;

  UserModel({
    this.id = "",
    required this.name,
    required this.email,
     this.role = "",
     this.age = 0,
    this.height = 0,
    this.sharedUsers = "",
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
        );

  Map<String, dynamic> toJson() {
    return {
      'id' : id,
      'name': name,
      'email': email,
      'role': role,
      'age': age,
      'height': height,
      'sharedUsers': sharedUsers,
    };
  }
}
