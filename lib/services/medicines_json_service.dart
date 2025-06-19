import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:amanak/models/medicine_json_model.dart';
import 'package:amanak/models/medicine_search_result.dart';

class MedicinesJsonService {
  static final MedicinesJsonService _instance =
      MedicinesJsonService._internal();

  factory MedicinesJsonService() => _instance;

  MedicinesJsonService._internal();

  List<MedicineJson> _medicines = [];
  bool _isInitialized = false;

  // Load all medicines from JSON file
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load the JSON file content
      final String jsonString =
          await rootBundle.loadString('medical_products_full.json');
      final List<dynamic> jsonData = json.decode(jsonString);

      // Parse JSON data into MedicineJson objects
      _medicines = jsonData.map((item) => MedicineJson.fromJson(item)).toList();
      _isInitialized = true;

      print('Loaded ${_medicines.length} medicines from JSON file');
    } catch (e) {
      print('Error loading medicines from JSON: $e');
      _medicines = [];
      throw e;
    }
  }

  // Ensure the service is initialized
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // Search medicines by name (in both English and Arabic)
  Future<List<Medicine>> searchMedicines(String query) async {
    if (query.isEmpty) {
      return [];
    }

    await ensureInitialized();

    final lowercaseQuery = query.toLowerCase();

    // Filter medicines that match the query
    final results = _medicines.where((medicine) {
      return medicine.enName.toLowerCase().contains(lowercaseQuery) ||
          medicine.arName.toLowerCase().contains(lowercaseQuery);
    }).toList();

    // Convert to old Medicine model for backward compatibility
    return results.map((medicine) => medicine.toMedicine()).toList();
  }

  // Search medicines with descriptions for the search screen
  Future<List<MedicineSearchResult>> searchMedicinesWithDetails(
      String query) async {
    if (query.isEmpty) {
      return [];
    }

    await ensureInitialized();

    final lowercaseQuery = query.toLowerCase();

    // Filter medicines that match the query
    final results = _medicines.where((medicine) {
      return medicine.enName.toLowerCase().contains(lowercaseQuery) ||
          medicine.arName.toLowerCase().contains(lowercaseQuery);
    }).toList();

    // Convert to MedicineSearchResult with descriptions
    return results.map((medicine) {
      String description = medicine.description;

      // Truncate description if needed
      if (description.length > 100) {
        description = description.substring(0, 100) + '...';
      }

      // Check if text is Arabic
      bool isArabic = _isArabicText(description);

      return MedicineSearchResult(
        id: medicine.key,
        name: medicine.enName,
        description: description,
        isArabic: isArabic,
      );
    }).toList();
  }

  // Helper method to check if text is Arabic
  bool _isArabicText(String text) {
    // Simple check for Arabic characters in the first 10 characters
    final arabicRegex = RegExp(
        r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    final sample = text.length > 10 ? text.substring(0, 10) : text;
    return arabicRegex.hasMatch(sample);
  }

  // Get all medicines (limited for performance)
  Future<List<Medicine>> getAllMedicines({int limit = 100}) async {
    await ensureInitialized();

    return _medicines
        .take(limit)
        .map((medicine) => medicine.toMedicine())
        .toList();
  }

  // Get a specific medicine by ID
  Future<MedicineJson?> getMedicineById(String id) async {
    await ensureInitialized();

    try {
      final medicineJson =
          _medicines.firstWhere((medicine) => medicine.key == id);
      return medicineJson;
    } catch (e) {
      print('Error finding medicine with ID $id: $e');

      // Try searching by name if not found by key
      try {
        return _medicines.firstWhere(
          (medicine) => medicine.enName == id || medicine.arName == id,
        );
      } catch (e) {
        print('Could not find medicine with name $id either: $e');
        return null;
      }
    }
  }
}
