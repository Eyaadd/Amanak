import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  static const String _englishCode = 'en';
  static const String _arabicCode = 'ar';

  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  // Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('ar'), // Arabic
  ];

  // Initialize the service
  Future<void> initialize() async {
    await _loadSavedLanguage();
  }

  // Load saved language from SharedPreferences
  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey);

      if (savedLanguage != null) {
        _currentLocale = Locale(savedLanguage);
        notifyListeners();
      }
    } catch (e) {
      print('Error loading saved language: $e');
    }
  }

  // Change language
  Future<void> changeLanguage(String languageCode) async {
    if (languageCode == _currentLocale.languageCode) return;

    _currentLocale = Locale(languageCode);

    // Save to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
    } catch (e) {
      print('Error saving language: $e');
    }

    notifyListeners();
  }

  // Get language name
  String getLanguageName(String languageCode) {
    switch (languageCode) {
      case _englishCode:
        return 'English';
      case _arabicCode:
        return 'العربية';
      default:
        return 'English';
    }
  }

  // Check if current language is RTL
  bool get isRTL => _currentLocale.languageCode == 'ar';

  // Get current language code
  String get currentLanguageCode => _currentLocale.languageCode;
}
