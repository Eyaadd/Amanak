import 'package:amanak/medicine_detail_screen.dart';
import 'package:amanak/models/medicine_json_model.dart';
import 'package:amanak/models/medicine_search_result.dart';
import 'package:amanak/services/medicines_json_service.dart';
import 'package:flutter/material.dart';

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
    setState(() {
      _isLoading = true;
    });

    try {
      await _medicinesService.ensureInitialized();
    } catch (e) {
      print('Error initializing medicines service: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading medicine data: $e')),
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
        SnackBar(content: Text('Error searching medicines: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Search'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                hintText: 'Search for medicines...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
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
                              ? 'Enter a medicine name to search'
                              : 'No medicines found',
                          style:
                              const TextStyle(fontSize: 16, color: Colors.grey),
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
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Navigate to the detail screen with the medicine key
          Navigator.pushNamed(
            context,
            MedicineDetailScreen.routeName,
            arguments: result.id,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: result.isArabic
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // Medicine Name
              Text(
                result.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: result.isArabic ? TextAlign.right : TextAlign.left,
              ),
              const SizedBox(height: 8),

              // Description Preview
              if (result.description.isNotEmpty)
                Directionality(
                  textDirection:
                      result.isArabic ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(
                    result.description,
                    style: TextStyle(
                      fontSize: 14,
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
