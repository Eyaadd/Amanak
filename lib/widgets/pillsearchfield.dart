import 'package:flutter/material.dart';

class PillSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const PillSearchField({
    Key? key,
    required this.controller,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      cursorColor: const Color(0xFF015C92),
      decoration: InputDecoration(
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE8F3F1)),
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
          borderSide: const BorderSide(color: Color(0xFFE8F3F1)),
        ),
        hintText: "Search for pills",
        hintStyle: Theme.of(context).textTheme.titleSmall!.copyWith(
          color: const Color(0xFFA1A8B0),
          fontSize: screenWidth * 0.032,
        ),
        prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: screenWidth * 0.06),
        filled: true,
        fillColor: const Color(0xFFFBFBFB),
        contentPadding: EdgeInsets.symmetric(
          vertical: screenHeight * 0.018,
          horizontal: screenWidth * 0.05,
        ),
      ),
    );
  }
}
