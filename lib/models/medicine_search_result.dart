// Class to hold search results with description
class MedicineSearchResult {
  final String id;
  final String name;
  final String description;
  final bool isArabic;

  MedicineSearchResult({
    required this.id,
    required this.name,
    required this.description,
    required this.isArabic,
  });
}
