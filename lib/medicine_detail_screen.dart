import 'package:flutter/material.dart';
import 'package:amanak/models/medicine_json_model.dart';
import 'package:amanak/services/medicines_json_service.dart';

class MedicineDetailScreen extends StatefulWidget {
  static const String routeName = "MedicineDetailScreen";

  const MedicineDetailScreen({Key? key}) : super(key: key);

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  final MedicinesJsonService _medicinesService = MedicinesJsonService();
  MedicineJson? _medicine;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMedicineData();
  }

  Future<void> _loadMedicineData() async {
    final dynamic args = ModalRoute.of(context)?.settings.arguments;

    if (args is String) {
      setState(() {
        _isLoading = true;
      });

      try {
        final medicine = await _medicinesService.getMedicineById(args);

        setState(() {
          _medicine = medicine;
          _isLoading = false;
        });
      } catch (e) {
        print('Error loading medicine details: $e');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading medicine details: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid medicine ID')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_medicine?.enName ?? 'Medicine Details'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _medicine == null
              ? const Center(child: Text('Medicine not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMedicineHeader(),
                      const Divider(height: 30, thickness: 1),
                      _buildInfoSection('Description', _medicine!.description),
                      _buildListSection('Side Effects', _medicine!.sideEffects),
                      _buildListSection('Uses', _medicine!.uses),
                      _buildListSection(
                          'Contraindications', _medicine!.contraindications),
                      _buildListSection('Precautions', _medicine!.precautions),
                      _buildListSection(
                          'Interactions', _medicine!.interactions),
                      _buildInfoSection('Dosage', _medicine!.dosage),
                      _buildListSection('Dosage Forms', _medicine!.dosageForms),
                      _buildInfoSection('Storage', _medicine!.storage),
                      _buildListSection(
                          'Usage Instructions', _medicine!.usageInstructions),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMedicineHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // English Name
            Text(
              'English Name',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _medicine!.enName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // Arabic Name
            Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الاسم العربي',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _medicine!.arName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    bool isArabic = _isArabicText(content);
    TextDirection textDirection =
        isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: title == 'Description',
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Directionality(
              textDirection: textDirection,
              child: Text(
                content,
                style: const TextStyle(fontSize: 16),
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(String title, List<String> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    bool isArabic = items.isNotEmpty && _isArabicText(items.first);
    TextDirection textDirection =
        isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Directionality(
            textDirection: textDirection,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: const TextStyle(fontSize: 16)),
                        Expanded(
                          child: Text(
                            items[index],
                            style: const TextStyle(fontSize: 16),
                            textAlign:
                                isArabic ? TextAlign.right : TextAlign.left,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to check if text is Arabic
  bool _isArabicText(String text) {
    // Simple check for Arabic characters in the first 10 characters
    final arabicRegex = RegExp(
        r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    final sample = text.length > 10 ? text.substring(0, 10) : text;
    return arabicRegex.hasMatch(sample);
  }
}
