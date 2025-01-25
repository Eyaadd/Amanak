import 'package:amanak/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:lottie/lottie.dart';

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
          title: "Welcome To Amanak App",
          body: "Caring for your well-being, every step of the way.",
          image: _buildImage(''),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Stay Safe",
          bodyWidget: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(color: Colors.black, fontSize: 16),
              children: [
                TextSpan(text: "Advanced "),
                TextSpan(
                    text: "Fall Detection",
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        color: Colors.black, fontWeight: FontWeight.bold,fontSize: 16)),
                TextSpan(
                    text:
                        " technology alerts your loved ones when help is needed.",
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(color: Colors.black, fontSize: 16,)),
              ],
            ),
          ),
          image: _buildImage('2'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Stay Connected",
          bodyWidget: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(color: Colors.black, fontSize: 16),
              children: [
                TextSpan(text: "Real-time "),
                TextSpan(
                    text: "Live Tracking ",
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        color: Colors.black, fontWeight: FontWeight.bold,fontSize: 16)),
                TextSpan(
                    text:
                    "to ensure you're always within reach.",
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(color: Colors.black, fontSize: 16,)),
              ],
            ),
          ),
          image: _buildImage('3'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Stay Organized",
          bodyWidget: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(color: Colors.black, fontSize: 16),
              children: [
                TextSpan(text: "A smart "),
                TextSpan(
                    text: "Calendar ",
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        color: Colors.black, fontWeight: FontWeight.bold,fontSize: 16)),
                TextSpan(
                    text:
                    "to remind you of medications and appointments.",
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(color: Colors.black, fontSize: 16,)),
              ],
            ),
          ),
          image: _buildImage('4'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Stay Hassle-Free",
          bodyWidget: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(color: Colors.black, fontSize: 16),
              children: [
                TextSpan(text: "Scan "),
                TextSpan(
                    text: "medical prescriptions ",
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        color: Colors.black, fontWeight: FontWeight.bold,fontSize: 16)),
                TextSpan(
                    text:
                    "and let the app manage your medication reminders automatically.",
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(color: Colors.black, fontSize: 16,)),
              ],
            ),
          ),
          image: _buildImage('5'),
          decoration: pageDecoration,
        ),
      ],
    );
  }
}
