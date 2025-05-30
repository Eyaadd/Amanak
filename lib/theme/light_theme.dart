import 'package:amanak/theme/base_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LightTheme extends BaseTheme {
  @override
  Color get backgroundColor => Color(0xFFF5F5F5);

  @override
  // TODO: implement primaryColor
  Color get primaryColor => Color(0xFF015C92);

  @override
  // TODO: implement textColor
  Color get textColor => Color(0xFF015C92);

  @override
  // TODO: implement themeData
  ThemeData get themeData => ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      textTheme: TextTheme(
        titleSmall: GoogleFonts.inter(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        titleMedium: GoogleFonts.poppins(
          color: textColor,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.poppins(
          color: textColor,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
      ));
}
