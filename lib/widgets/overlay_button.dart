import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OverlayButton extends StatelessWidget {
  static const routeName = "OverlayButton";
  final String assetName;
  final VoidCallback? onTap;

  const OverlayButton({
    Key? key,
    required this.assetName,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing
    final double buttonSize = screenWidth * 0.22; // Adjusts size of button
    final double padding = screenWidth * 0.05;    // Inner padding of the icon

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          color: Colors.white,
        ),
        padding: EdgeInsets.all(padding),
        child: SvgPicture.asset("assets/svg/$assetName.svg"),
      ),
    );
  }
}
