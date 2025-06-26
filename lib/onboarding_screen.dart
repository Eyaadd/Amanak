import 'package:amanak/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:amanak/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnBoardingScreen extends StatelessWidget {
  static const String routeName = "OnBoardingScreen";

  const OnBoardingScreen({super.key});

  Widget _buildImage(String assetName, [double width = 450]) {
    return Lottie.asset('assets/animations/gedo$assetName.json', width: width);
  }

  @override
  Widget build(BuildContext context) {
    var bodyStyle = GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: const Color(0xFF202020),
    );

    var pageDecoration = PageDecoration(
        titleTextStyle: GoogleFonts.poppins(
          color: const Color(0xFF212523),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        bodyTextStyle: bodyStyle,
        bodyPadding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
        pageColor: const Color(0xFFF4EEEE),
        imagePadding: EdgeInsets.zero,
        imageFlex: 2,
        bodyAlignment: Alignment.bottomCenter);
    final localizations = AppLocalizations.of(context)!;
    return IntroductionScreen(
      dotsFlex: 2,
      dotsDecorator: const DotsDecorator(
        color: Color(0xFF707070),
        activeColor: Color(0xFF015C92),
      ),
      globalBackgroundColor: const Color(0xFFF4EEEE),
      showDoneButton: true,
      onDone: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      },
      done: Text(
        localizations.onboarding_finish,
        style: GoogleFonts.poppins(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
          color: Color(0xFF015C92),
        ),
      ),
      showNextButton: true,
      next: Text(
        localizations.onboarding_next,
        style: GoogleFonts.poppins(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
          color: Color(0xFF015C92),
        ),
      ),
      showBackButton: true,
      back: Text(
        localizations.onboarding_back,
        style: GoogleFonts.poppins(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
          color: Color(0xFF015C92),
        ),
      ),
      pages: [
        PageViewModel(
          title: localizations.onboarding_welcome_title,
          body: localizations.onboarding_welcome_body,
          image: _buildImage(''),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: localizations.onboarding_safety_title,
          body: localizations.onboarding_safety_body,
          image: _buildImage('2'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: localizations.onboarding_connected_title,
          body: localizations.onboarding_connected_body,
          image: _buildImage('3'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: localizations.onboarding_organized_title,
          body: localizations.onboarding_organized_body,
          image: _buildImage('4'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: localizations.onboarding_hassle_free_title,
          body: localizations.onboarding_hassle_free_body,
          image: _buildImage('5'),
          decoration: pageDecoration,
        ),
      ],
    );
  }
}
