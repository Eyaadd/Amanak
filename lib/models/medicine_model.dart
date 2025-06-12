class Medicine {
  final String name; // maps to the first column in the database
  final String generics; // maps to 'generics' column
  final String manufacturer; // maps to 'applicant_name' column
  final String dosageForm; // maps to 'dosage_form' column

  Medicine({
    required this.name,
    required this.generics,
    required this.manufacturer,
    required this.dosageForm,
  });

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      name: map['name'] ?? '',
      generics: map['generics'] ?? '',
      manufacturer: map['applicant_name'] ?? '',
      dosageForm: map['dosage_form'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'generics': generics,
      'applicant_name': manufacturer,
      'dosage_form': dosageForm,
    };
  }
}
