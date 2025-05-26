import 'package:amanak/chatbot.dart';
import 'package:amanak/gaurdian_location.dart';
import 'package:amanak/login_screen.dart';
import 'package:amanak/nearest_hospitals.dart';
import 'package:amanak/signup/choose_role.dart';
import 'package:amanak/signup/signup_screen.dart';
import 'package:amanak/theme/base_theme.dart';
import 'package:amanak/home_screen.dart';
import 'package:amanak/theme/light_theme.dart';
import 'package:amanak/provider/my_provider.dart';
import 'package:amanak/widgets/overlay_button.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'firebase/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'onboarding_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

const apiKey = "AIzaSyDLePMB53Q1Nud4ZG8a2XA9UUYuSLCrY6c";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Gemini.init(apiKey:  apiKey );
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Check if user is already logged in
  User? currentUser = FirebaseAuth.instance.currentUser;
  print('Current user on app start: ${currentUser?.email ?? 'No user logged in'}');
  
  // Sign out user in debug mode
  assert(() {
    if (currentUser != null) {
      FirebaseAuth.instance.signOut();
      print('User signed out in debug mode');
    }
    return true;
  }());
  
  runApp(ChangeNotifierProvider(
      create: (context) => MyProvider(),
      child: MyApp()));
}

class MyApp extends StatelessWidget {
  BaseTheme lightTheme = LightTheme();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveSizer(
      builder: (context, orientation, screenType) {
        return MaterialApp(
          theme: lightTheme.themeData,
          debugShowCheckedModeBanner: false,
          initialRoute: LoginScreen.routeName,
          routes: {
            OnBoardingScreen.routeName: (context)=> OnBoardingScreen(),
            LoginScreen.routeName: (context) => LoginScreen(),
            SignupScreen.routeName: (context) => SignupScreen(),
            ChooseRoleScreen.routeName : (context) => ChooseRoleScreen(),
            HomeScreen.routeName: (context) => HomeScreen(),
            ChatBot.routeName: (context) => ChatBot(),
            GuardianLiveTracking.routeName : (context) => GuardianLiveTracking(),
            NearestHospitals.routeName : (context) => NearestHospitals()

          },
        );
      },
    );
  }
}
