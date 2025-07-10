class MedicineJson {
  final String key;
  final String enName;
  final String arName;
  final String description;
  final List<String> sideEffects;
  final List<String> uses;
  final List<String> contraindications;
  final List<String> precautions;
  final List<String> interactions;
  final String dosage;
  final List<String> dosageForms;
  final String storage;
  final List<String> usageInstructions;

  MedicineJson({
    required this.key,
    required this.enName,
    required this.arName,
    required this.description,
    required this.sideEffects,
    required this.uses,
    required this.contraindications,
    required this.precautions,
    required this.interactions,
    required this.dosage,
    required this.dosageForms,
    required this.storage,
    required this.usageInstructions,
  });

  factory MedicineJson.fromJson(Map<String, dynamic> json) {
    return MedicineJson(
      key: json['key'] ?? '',
      enName: json['enName'] ?? '',
      arName: json['arName'] ?? '',
      description: json['description'] ?? '',
      sideEffects: _parseStringList(json['sideEffects']),
      uses: _parseStringList(json['uses']),
      contraindications: _parseStringList(json['contraindications']),
      precautions: _parseStringList(json['precautions']),
      interactions: _parseStringList(json['interactions']),
      dosage: json['dosage'] ?? '',
      dosageForms: _parseStringList(json['dosageForms']),
      storage: json['storage'] ?? '',
      usageInstructions: _parseStringList(json['usageInstructions']),
    );
  }

  // Helper method to parse list of strings from JSON
  static List<String> _parseStringList(dynamic list) {
    if (list == null) return [];
    return List<String>.from(list.map((item) => item.toString()));
  }

  // Convert to the old Medicine model format for backward compatibility
  Medicine toMedicine() {
    return Medicine(
      id: key,
      name: enName,
      generics: uses.isNotEmpty ? uses.join(', ') : '',
      manufacturer: '',
      dosageForm: dosageForms.isNotEmpty ? dosageForms.join(', ') : '',
    );
  }
}

// Keeping the old Medicine model for backward compatibility
class Medicine {
  final String id;
  final String name;
  final String generics;
  final String manufacturer;
  final String dosageForm;

  Medicine({
    required this.id,
    required this.name,
    required this.generics,
    required this.manufacturer,
    required this.dosageForm,
  });
}
