import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:amanak/models/medicine_json_model.dart';
import 'package:amanak/models/medicine_search_result.dart';

class MedicinesJsonService {
  static final MedicinesJsonService _instance =
      MedicinesJsonService._internal();

  factory MedicinesJsonService() => _instance;

  MedicinesJsonService._internal();

  List<MedicineJson> _medicines = [];
  bool _isInitialized = false;

  // Cache for search results to avoid repeated filtering
  final Map<String, List<Medicine>> _searchCache = {};
  final Map<String, List<MedicineSearchResult>> _detailedSearchCache = {};

  // Static methods for use with compute function
  static List<MedicineJson> _parseMedicinesJson(String jsonString) {
    final List<dynamic> jsonData = json.decode(jsonString);
    return jsonData.map((item) => MedicineJson.fromJson(item)).toList();
  }

  static List<Medicine> _filterMedicines(Map<String, dynamic> params) {
    final List<MedicineJson> medicines = params['medicines'];
    final String query = params['query'];
    final lowercaseQuery = query.toLowerCase();

    return medicines
        .where((medicine) {
          return medicine.enName.toLowerCase().contains(lowercaseQuery) ||
              medicine.arName.toLowerCase().contains(lowercaseQuery);
        })
        .map((medicine) => medicine.toMedicine())
        .toList();
  }

  static List<MedicineSearchResult> _filterMedicinesWithDetails(
      Map<String, dynamic> params) {
    final List<MedicineJson> medicines = params['medicines'];
    final String query = params['query'];
    final lowercaseQuery = query.toLowerCase();

    return medicines.where((medicine) {
      return medicine.enName.toLowerCase().contains(lowercaseQuery) ||
          medicine.arName.toLowerCase().contains(lowercaseQuery);
    }).map((medicine) {
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

  static bool _isArabicText(String text) {
    // Simple check for Arabic characters in the first 10 characters
    final arabicRegex = RegExp(
        r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    final sample = text.length > 10 ? text.substring(0, 10) : text;
    return arabicRegex.hasMatch(sample);
  }

  // Load all medicines from JSON file
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load the JSON file content
      final String jsonString =
          await rootBundle.loadString('medical_products_full.json');

      // Parse JSON data in a separate isolate
      _medicines = await compute(_parseMedicinesJson, jsonString);
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

    // Check cache first
    final cacheKey = query.toLowerCase();
    if (_searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    // Process search in a separate isolate
    final results = await compute(_filterMedicines, {
      'medicines': _medicines,
      'query': query,
    });

    // Cache the results (limit cache size)
    if (_searchCache.length > 100) {
      _searchCache.remove(_searchCache.keys.first); // Remove oldest entry
    }
    _searchCache[cacheKey] = results;

    return results;
  }

  // Search medicines with descriptions for the search screen
  Future<List<MedicineSearchResult>> searchMedicinesWithDetails(
      String query) async {
    if (query.isEmpty) {
      return [];
    }

    await ensureInitialized();

    // Check cache first
    final cacheKey = query.toLowerCase();
    if (_detailedSearchCache.containsKey(cacheKey)) {
      return _detailedSearchCache[cacheKey]!;
    }

    // Process search in a separate isolate
    final results = await compute(_filterMedicinesWithDetails, {
      'medicines': _medicines,
      'query': query,
    });

    // Cache the results (limit cache size)
    if (_detailedSearchCache.length > 100) {
      _detailedSearchCache
          .remove(_detailedSearchCache.keys.first); // Remove oldest entry
    }
    _detailedSearchCache[cacheKey] = results;

    return results;
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

  // Clear search caches (call this when memory is low)
  void clearCaches() {
    _searchCache.clear();
    _detailedSearchCache.clear();
    print('Medicine search caches cleared');
  }
}
