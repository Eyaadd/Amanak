import 'package:amanak/medicine_search_screen.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

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
    final localizations = AppLocalizations.of(context)!;
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
        hintText: localizations.medicineSearchHint,
        hintStyle: Theme.of(context).textTheme.titleSmall!.copyWith(
              color: const Color(0xFFA1A8B0),
              fontSize: screenWidth * 0.032,
            ),
        prefixIcon: Icon(Icons.search,
            color: Colors.grey.shade600, size: screenWidth * 0.06),
        filled: true,
        fillColor: const Color(0xFFFBFBFB),
        contentPadding: EdgeInsets.symmetric(
          vertical: screenHeight * 0.018,
          horizontal: screenWidth * 0.05,
        ),
      ),
      onTap: () {
        // Clear focus to prevent keyboard from showing
        FocusScope.of(context).unfocus();

        // Navigate to medicine search screen
        Navigator.of(context).pushNamed(
          MedicineSearchScreen.routeName,
          arguments: controller.text,
        );
      },
      readOnly:
          true, // Make it non-editable since we're using it for navigation
    );
  }
}
