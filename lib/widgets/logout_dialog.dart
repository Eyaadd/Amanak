import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:amanak/login_screen.dart';
import 'package:provider/provider.dart';

import '../provider/my_provider.dart';

void showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildImage("logout"),
              const SizedBox(height: 0),
              Text(
                "Are You Sure you want to logout?",
                style: Theme
                    .of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(color: Colors.black,fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                  // Clear any local state if needed
                  Provider.of<MyProvider>(context, listen: false)
                      .setUserModel("", "", "");
                  // Navigate to login screen
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    LoginScreen.routeName,
                        (route) => false, // This removes all previous routes
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                        Text('Error signing out: ${e.toString()}')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme
                    .of(context)
                    .primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(183, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              child: Text(
                "Log Out",
                style: Theme
                    .of(context)
                    .textTheme
                    .titleSmall!
                    .copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ) ,
              ),
            ),
          ),
          SizedBox(height: 16),
          Center(
            child: TextButton(onPressed:() {
              Navigator.pop(context);
            }, child: Text("Cancel", style: Theme
                .of(context)
                .textTheme
                .titleSmall!
                .copyWith(color: Theme
                .of(context)
                .primaryColor),)),)
        ],
      );
    },
  );
}

Widget _buildImage(String assetName, [double width = 450]) {
  return Lottie.asset('assets/animations/$assetName.json', width: width);
}
