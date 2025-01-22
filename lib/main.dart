import 'package:amanak/provider/my_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'onboarding_screen2.dart';
import 'theme/base_theme.dart';
import 'theme/light_theme.dart';

void main() {
  runApp(ChangeNotifierProvider(
      create: (context) => ChangeTab(),
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
          initialRoute: OnBoardingScreen.routeName,
          routes: {
            OnBoardingScreen.routeName: (context)=> OnBoardingScreen(),
            OnBoardingScreen2.routeName: (context)=> OnBoardingScreen2(),
            LoginScreen.routeName: (context) => LoginScreen(),
            HomeScreen.routeName: (context) => HomeScreen(),
          },
        );
      },
    );
  }
}
