import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'login_screen.dart';

class OnBoardingScreen2 extends StatelessWidget {
  static const String routeName = "OnBoardingScreen2";

  const OnBoardingScreen2({super.key});

  Widget _buildImage(String assetName, [double width = 450] ) {
    return Image.asset('assets/images/${assetName}Card.png', width: width);
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
        imageFlex: 10,
        );
    return IntroductionScreen(
      dotsFlex: 2,
      dotsDecorator: const DotsDecorator(
        color: Color(0xFF707070),
        activeColor: Color(0xFF00664F),
      ),
      globalBackgroundColor: const Color(0xFFF4EEEE),
      showDoneButton: true,
      onDone: () {
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      },
      done: Text(
        "Finish",
        style: GoogleFonts.poppins(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00664F),
        ),
      ),
      showNextButton: true,
      next: Text(
        "Next",
        style: GoogleFonts.poppins(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00664F),
        ),
      ),
      showBackButton: true,
      back: Text(
        "Back",
        style: GoogleFonts.poppins(
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00664F),
        ),
      ),
      pages: [
        PageViewModel(
          title: "",
          body: "",
          image: _buildImage('ahmed'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "",
          body: "",
          image: _buildImage('elena'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "",
          body:"",
          image: _buildImage('eyad'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "",
          body: "",
          image: _buildImage('mariam'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "",
          body: "",
          image: _buildImage('mark'),
          decoration: pageDecoration,
        ),
      ],
    );
  }
}
