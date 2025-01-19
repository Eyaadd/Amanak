import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'theme/base_theme.dart';
import 'theme/light_theme.dart';

void main() {
  runApp(MyApp());
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
          initialRoute: LoginScreen.routeName, // Set LoginScreen as initial route
          routes: {
            LoginScreen.routeName: (context) => LoginScreen(),
            HomeScreen.routeName: (context) => HomeScreen(),
          },
        );
      },
    );
  }
}
