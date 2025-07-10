import 'package:amanak/medicine_detail_screen.dart';
import 'package:amanak/models/medicine_json_model.dart';
import 'package:amanak/models/medicine_search_result.dart';
import 'package:amanak/services/medicines_json_service.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class MedicineSearchScreen extends StatefulWidget {
  static const String routeName = "MedicineSearchScreen";

  const MedicineSearchScreen({Key? key}) : super(key: key);

  @override
  State<MedicineSearchScreen> createState() => _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends State<MedicineSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MedicinesJsonService _medicinesService = MedicinesJsonService();
  List<MedicineSearchResult> _searchResults = [];
  bool _isLoading = false;
  String? _initialQuery;

  @override
  void initState() {
    super.initState();
    // Initialize the medicines service
    _initializeMedicinesService();
  }

  Future<void> _initializeMedicinesService() async {
    final localizations = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
    });

    try {
      await _medicinesService.ensureInitialized();
    } catch (e) {
      print('Error initializing medicines service: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.errorLoadingMedicineData(e))),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get the search query from the arguments
    final dynamic args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is String && _initialQuery == null) {
      _initialQuery = args;
      _searchController.text = args;
      if (args.isNotEmpty) {
        _performSearch(args);
      }
    }
  }

  Future<void> _performSearch(String query) async {
    final localizations = AppLocalizations.of(context)!;
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Using the new service method to get medicines with descriptions
      final results = await _medicinesService.searchMedicinesWithDetails(query);

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching medicines: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.errorSearchingMedicines(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.medicineSearchTitle,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: Theme.of(context).primaryColor
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                hintText: localizations.medicineSearchHint,
                hintStyle: const TextStyle(fontSize: 20, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 28),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 26),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                    });
                  },
                ),
              ),
              onChanged: (value) {
                if (value.length > 2) {
                  _performSearch(value);
                } else if (value.isEmpty) {
                  setState(() {
                    _searchResults = [];
                  });
                }
              },
            ),
          ),

          // Search Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                ? Center(
              child: Text(
                _searchController.text.isEmpty
                    ? localizations.medicineSearchEmpty
                    : localizations.medicineSearchNotFound,
                style: const TextStyle(fontSize: 22, color: Colors.grey, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            )
                : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return MedicineCard(result: result);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MedicineCard extends StatelessWidget {
  final MedicineSearchResult result;

  const MedicineCard({Key? key, required this.result}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Navigate to the detail screen with the medicine key
          Navigator.pushNamed(
            context,
            MedicineDetailScreen.routeName,
            arguments: result.id,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            crossAxisAlignment: result.isArabic
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // Medicine Name
              Text(
                result.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: result.isArabic ? TextAlign.right : TextAlign.left,
              ),
              const SizedBox(height: 12),

              // Description Preview
              if (result.description.isNotEmpty)
                Directionality(
                  textDirection:
                  result.isArabic ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(
                    result.description,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign:
                    result.isArabic ? TextAlign.right : TextAlign.left,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
