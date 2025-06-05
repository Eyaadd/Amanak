import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../firebase/firebase_manager.dart';

void sharedUsersDialog(BuildContext context, String title , String currentUserId , currentUserEmail) {
final emailController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        content: Column(
          children: [
            Center(child: Text(title)),
            SizedBox(height: 20),
            TextField(
              controller: emailController,
            ),
            SizedBox(height: 20),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () {
            FirebaseManager.linkUser(currentUserId, emailController.text, currentUserEmail);
            Navigator.pop(context);
          }, child: Text("Save"))
        ],
      );
    },
  );
}
