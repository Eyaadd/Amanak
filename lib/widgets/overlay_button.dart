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

    // Responsive sizing with larger buttons
    final double buttonSize = screenWidth * 0.26; // Increased from 0.22
    final double padding = screenWidth * 0.06; // Increased from 0.05

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(screenWidth * 0.05), // Increased from 0.04
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(padding),
        child: SvgPicture.asset("assets/svg/$assetName.svg"),
      ),
    );
  }
}
