import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OverlayButton extends StatelessWidget {
  static const routeName = "OverlayButton";
  final String assetName;
  final VoidCallback? onTap;

  // Create a static cache for SVG pictures to avoid reloading
  static final Map<String, SvgPicture> _svgCache = {};

  const OverlayButton({
    Key? key,
    required this.assetName,
    required this.onTap,
  }) : super(key: key);

  // Helper method to get or create SVG picture with caching
  static SvgPicture _getCachedSvg(String assetName) {
    if (!_svgCache.containsKey(assetName)) {
      final svgPath = "assets/svg/$assetName.svg";

      // Create the SVG picture with caching enabled
      _svgCache[assetName] = SvgPicture.asset(
        svgPath,
        cacheColorFilter: true, // Cache the color filter for better performance
      );
    }
    return _svgCache[assetName]!;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing with larger buttons
    final double buttonSize = screenWidth * 0.26;
    final double padding = screenWidth * 0.06;

    // Use Hero widget for smooth transitions when navigating
    return Hero(
      tag: 'button-$assetName',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(screenWidth * 0.05),
              color: Colors.white,
              boxShadow: const [
                BoxShadow(
                  color: Color(
                      0x1A000000), // Optimized from Colors.black.withOpacity(0.1)
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.all(padding),
            child: _getCachedSvg(assetName),
          ),
        ),
      ),
    );
  }
}
