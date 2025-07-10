import 'package:flutter/material.dart';
import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:page_transition/page_transition.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:amanak/home_screen.dart';
import 'package:amanak/login_screen.dart';
import 'package:amanak/screens/language_selection_screen.dart';
import 'package:amanak/onboarding_screen.dart';

class SimpleSplashScreen extends StatefulWidget {
  const SimpleSplashScreen({Key? key}) : super(key: key);

  @override
  State<SimpleSplashScreen> createState() => _SimpleSplashScreenState();
}

class _SimpleSplashScreenState extends State<SimpleSplashScreen> {
  Widget? _nextScreen;

  @override
  void initState() {
    super.initState();
    _determineNextScreen();
  }

  Future<void> _determineNextScreen() async {
    try {
      // Get SharedPreferences instance
      final prefs = await SharedPreferences.getInstance();

      // Check if this is the first launch
      final bool languageSelected = prefs.getBool('language_selected') ?? false;
      final bool onboardingCompleted =
          prefs.getBool('onboarding_completed') ?? false;
      final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;

      // Determine the next screen
      Widget nextScreen;

      if (!languageSelected) {
        nextScreen = const LanguageSelectionScreen();
      } else if (!onboardingCompleted) {
        nextScreen = OnBoardingScreen();
      } else if (!isLoggedIn) {
        nextScreen = LoginScreen();
      } else {
        nextScreen = HomeScreen();
      }

      // Update state if the widget is still mounted
      if (mounted) {
        setState(() {
          _nextScreen = nextScreen;
        });
      }
    } catch (e) {
      print('Error determining next screen: $e');
      // Default to language selection screen in case of error
      if (mounted) {
        setState(() {
          _nextScreen = const LanguageSelectionScreen();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If next screen is not determined yet, show a loading indicator
    if (_nextScreen == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Return animated splash screen
    return AnimatedSplashScreen(
      splash: Container(
        width: 250,
        height: 250,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Center(
          child: Image.asset(
            'assets/images/amanaklogo.png',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
      ),
      nextScreen: _nextScreen!,
      splashIconSize: 250,
      duration: 2500,
      splashTransition: SplashTransition.slideTransition,
      pageTransitionType: PageTransitionType.rightToLeft,
      backgroundColor: Colors.white,
      animationDuration: const Duration(milliseconds: 1200),
      centered: true,
    );
  }
}
