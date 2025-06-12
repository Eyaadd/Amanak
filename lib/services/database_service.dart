import 'dart:io';
import 'package:amanak/models/medicine_model.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Get the directory for storing the database file
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "eda_medicines_clean.db");

    // Check if the database already exists
    bool exists = await databaseExists(path);

    if (!exists) {
      // Copy the database from assets
      try {
        ByteData data =
            await rootBundle.load(join('assets/db', 'eda_medicines_clean.db'));
        List<int> bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

        // Write and flush the bytes to disk
        await File(path).writeAsBytes(bytes, flush: true);
        print("Database copied successfully");
      } catch (e) {
        print("Error copying database: $e");
        throw e;
      }
    }

    // Open the database
    return await openDatabase(path, readOnly: true);
  }

  // Search medicines by name
  Future<List<Medicine>> searchMedicines(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final db = await database;

    // Convert query to lowercase for case-insensitive search
    final lowercaseQuery = query.toLowerCase();

    // SQLite doesn't support case-insensitive LIKE in a standardized way
    // We'll fetch a broader set of results and filter them in Dart

    try {
      // Get all medicine names that might match the query
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT * FROM medicines
        WHERE generics LIKE ?
        LIMIT 100
      ''', ['%$lowercaseQuery%']);

      // Map the results to Medicine objects
      List<Medicine> medicines = results.map((row) {
        return Medicine.fromMap({
          'name': row.keys
              .first, // First column is name (the table doesn't have column names as per output)
          'generics': row['generics'] ?? '',
          'applicant_name': row['applicant_name'] ?? '',
          'dosage_form': row['dosage_form'] ?? '',
        });
      }).toList();

      // Further filter the results in Dart for case-insensitive matching
      return medicines.where((medicine) {
        return medicine.name.toLowerCase().contains(lowercaseQuery) ||
            medicine.generics.toLowerCase().contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      print('Error searching medicines: $e');
      return [];
    }
  }

  // Get all medicines (limited to 100 for performance)
  Future<List<Medicine>> getAllMedicines() async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT * FROM medicines
        LIMIT 100
      ''');

      // Map the results to Medicine objects
      return results.map((row) {
        return Medicine.fromMap({
          'name': row.keys.first, // First column is name
          'generics': row['generics'] ?? '',
          'applicant_name': row['applicant_name'] ?? '',
          'dosage_form': row['dosage_form'] ?? '',
        });
      }).toList();
    } catch (e) {
      print('Error getting all medicines: $e');
      return [];
    }
  }
}
