import 'package:flutter/material.dart';
import 'package:amanak/models/medicine_json_model.dart';
import 'package:amanak/services/medicines_json_service.dart';
import '../l10n/app_localizations.dart';

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
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_medicine?.enName ?? localizations.medicineDetailTitle,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _medicine == null
              ? Center(child: Text(localizations.medicineDetailNotFound, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMedicineHeader(localizations),
                      const Divider(height: 30, thickness: 1),
                      _buildInfoSection(localizations.medicineDetailDescription, _medicine!.description),
                      _buildListSection(localizations.medicineDetailSideEffects, _medicine!.sideEffects),
                      _buildListSection(localizations.medicineDetailUses, _medicine!.uses),
                      _buildListSection(localizations.medicineDetailContraindications, _medicine!.contraindications),
                      _buildListSection(localizations.medicineDetailPrecautions, _medicine!.precautions),
                      _buildListSection(localizations.medicineDetailInteractions, _medicine!.interactions),
                      _buildInfoSection(localizations.medicineDetailDosage, _medicine!.dosage),
                      _buildListSection(localizations.medicineDetailDosageForms, _medicine!.dosageForms),
                      _buildInfoSection(localizations.medicineDetailStorage, _medicine!.storage),
                      _buildListSection(localizations.medicineDetailUsageInstructions, _medicine!.usageInstructions),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMedicineHeader(AppLocalizations localizations) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // English Name
            Text(
              localizations.medicineDetailEnglishName,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _medicine!.enName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Arabic Name
            Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.medicineDetailArabicName,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _medicine!.arName,
                    style: const TextStyle(
                      fontSize: 24,
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
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        initiallyExpanded: title == 'Description',
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Directionality(
              textDirection: textDirection,
              child: Text(
                content,
                style: const TextStyle(fontSize: 20),
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
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Directionality(
              textDirection: textDirection,
              child: Column(
                crossAxisAlignment: isArabic
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: items
                    .map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            item,
                            style: const TextStyle(fontSize: 20),
                            textAlign:
                                isArabic ? TextAlign.right : TextAlign.left,
                          ),
                        ))
                    .toList(),
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
