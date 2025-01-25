import 'package:amanak/login_screen.dart';
import 'package:amanak/theme/base_theme.dart';
import 'package:amanak/home_screen.dart';
import 'package:amanak/theme/light_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  BaseTheme lightTheme = LightTheme();
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: lightTheme.themeData,
      debugShowCheckedModeBanner: false,
      initialRoute: LoginScreen.routeName,

      routes: {
        LoginScreen.routeName: (context) => LoginScreen(),
        HomeScreen.routeName: (context) => HomeScreen(),
      },
    );
  }
}
