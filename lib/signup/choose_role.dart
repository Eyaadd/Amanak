import 'package:amanak/firebase/firebase_manager.dart';
import 'package:amanak/home_screen.dart';
import 'package:amanak/models/user_model.dart';
import 'package:amanak/provider/my_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChooseRoleScreen extends StatelessWidget {
  static const routeName = "ChooseRole";
   ChooseRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var provider = Provider.of<MyProvider>(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actionsIconTheme: IconThemeData(color: Color(0xFF101623)),
        centerTitle: true,
        title: Text(
          "Sign Up",
          style: Theme.of(context)
              .textTheme
              .titleMedium!
              .copyWith(color: Color(0xFF101623)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Column(
            children: [
              SizedBox(height: 20,),
              Text("Choose Your Role",style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Colors.black),),
              SizedBox(height: 140,),
              ElevatedButton(
                onPressed: () {
                  provider.setRole("user");
                  print(provider.chosedRole);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size(342, 81),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  children: [
                    Image.asset("assets/images/user.png"),
                    SizedBox(width: 120,),
                    Text(
                      "User",
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 22,),
              ElevatedButton(
                onPressed: () {
                  provider.setRole("Guardian");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFEEF0F7),
                  foregroundColor: Colors.white,
                  minimumSize: Size(342, 81),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  children: [
                    Image.asset("assets/images/guardian.png"),
                    SizedBox(width: 120,),
                    Text(
                      "Guardian",
                      style: TextStyle(fontSize: 16,color: Color(0xFF525F7F)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 260,),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, HomeScreen.routeName);
                  UserModel user = UserModel(name:provider.userName,
                      email: provider.userEmail ,
                      id: provider.userID,
                      role: provider.chosedRole);
                  FirebaseManager.updateEvent(user);
                } ,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size(342, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: Text(
                  "Continue",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
