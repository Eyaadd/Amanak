import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:amanak/login_screen.dart';

void showSuccessDialog(BuildContext context) {
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
              _buildImage("Tick-amanak"),
              const SizedBox(height: 0),
              Text(
                "Success",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(color: Colors.black),
              ),
              const SizedBox(height: 8),
              const Text(
                "You have successfully created your account",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFA1A8B0),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  LoginScreen.routeName,
                      (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(183, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              child: Text(
                "Login",
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildImage(String assetName, [double width = 450]) {
  return Lottie.asset('assets/animations/$assetName.json', width: width);
}
