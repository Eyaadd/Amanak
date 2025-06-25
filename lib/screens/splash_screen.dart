import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amanak/firebase/firebase_manager.dart';
import 'package:amanak/services/medicines_json_service.dart';
import 'package:amanak/services/localization_service.dart';
import 'package:amanak/notifications/noti_service.dart';
import 'package:amanak/firebase/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:amanak/home_screen.dart';
import 'package:amanak/login_screen.dart';
import 'package:amanak/screens/language_selection_screen.dart';
import 'package:amanak/onboarding_screen.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    // Initialize Firebase
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // Initialize localization service
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    await localizationService.initialize();

    // Initialize notification service
    final notiService = NotiService();
    await notiService.initNotification();

    // Initialize medicines JSON service
    await MedicinesJsonService().initialize();

    // Check for any pending notifications
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      await notiService.checkPendingNotifications();
    }

    // If user is logged in, reschedule all pill notifications
    if (authUser != null) {
      await FirebaseManager.rescheduleAllNotifications();
    }

    // Check for missed pills
    await FirebaseManager.checkForMissedPills();

    // Check flags
    final prefs = await SharedPreferences.getInstance();
    final bool languageSelected = prefs.getBool('language_selected') ?? false;
    final bool onboardingCompleted =
        prefs.getBool('onboarding_completed') ?? false;
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;

    // Decide where to go
    String nextRoute;
    if (!languageSelected) {
      nextRoute = LanguageSelectionScreen.routeName;
    } else if (!onboardingCompleted) {
      nextRoute = OnBoardingScreen.routeName;
    } else if (!isLoggedIn) {
      nextRoute = LoginScreen.routeName;
    } else {
      nextRoute = HomeScreen.routeName;
    }

    // Navigate
    Navigator.of(context).pushReplacementNamed(nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/amanaklogo.png',
              height: 120,
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
