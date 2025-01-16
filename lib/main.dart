import 'package:amanak/theme/base_theme.dart';
import 'package:amanak/home_screen.dart';
import 'package:amanak/theme/light_theme.dart';
import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  BaseTheme lightTheme = LightTheme();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveSizer( // Wrap the app with ResponsiveSizer
      builder: (context, orientation, screenType) {
        return MaterialApp(
          theme: lightTheme.themeData,
          debugShowCheckedModeBanner: false,
          initialRoute: HomeScreen.routeName,
          routes: {
            HomeScreen.routeName: (context) => HomeScreen(),
          },
        );
      },
    );
  }
}
