import 'package:amanak/models/medicine_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MedicineService {
  final CollectionReference _medicinesCollection =
      FirebaseFirestore.instance.collection('medicines');

  // Get all medicines
  Future<List<Medicine>> getAllMedicines() async {
    try {
      QuerySnapshot querySnapshot = await _medicinesCollection.get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Medicine(
          name: data['name'] ?? '',
          generics: data['generics'] ?? '',
          manufacturer: data['manufacturer'] ?? '',
          dosageForm: data['dosageForm'] ?? '',
        );
      }).toList();
    } catch (e) {
      print('Error fetching medicines: $e');
      return [];
    }
  }

  // Search medicines by name
  Future<List<Medicine>> searchMedicines(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      // Convert query to lowercase for case-insensitive search
      String lowercaseQuery = query.toLowerCase();

      // Get all medicines and filter locally
      // This approach is used since Firestore doesn't support case-insensitive search directly
      QuerySnapshot querySnapshot = await _medicinesCollection.get();

      List<Medicine> allMedicines = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Medicine(
          name: data['name'] ?? '',
          generics: data['generics'] ?? '',
          manufacturer: data['manufacturer'] ?? '',
          dosageForm: data['dosageForm'] ?? '',
        );
      }).toList();

      // Filter medicines that contain the query string in their name
      return allMedicines.where((medicine) {
        return medicine.name.toLowerCase().contains(lowercaseQuery) ||
            medicine.generics.toLowerCase().contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      print('Error searching medicines: $e');
      return [];
    }
  }

  // Get medicine by ID
  Future<Medicine?> getMedicineById(String id) async {
    try {
      DocumentSnapshot docSnapshot = await _medicinesCollection.doc(id).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        return Medicine(
          name: data['name'] ?? '',
          generics: data['generics'] ?? '',
          manufacturer: data['manufacturer'] ?? '',
          dosageForm: data['dosageForm'] ?? '',
        );
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching medicine by ID: $e');
      return null;
    }
  }

  // Add some sample medicines to the database (for testing)
  Future<void> addSampleMedicines() async {
    List<Map<String, dynamic>> sampleMedicines = [
      {
        'id': '1',
        'name': 'Aspirin',
        'generics': 'Acetylsalicylic Acid',
        'manufacturer': 'Bayer',
        'dosageForm': 'Tablet',
      },
      {
        'id': '2',
        'name': 'Amoxicillin',
        'generics': 'Amoxicillin Trihydrate',
        'manufacturer': 'GSK',
        'dosageForm': 'Capsule',
      },
      {
        'id': '3',
        'name': 'Lisinopril',
        'generics': 'Lisinopril Dihydrate',
        'manufacturer': 'AstraZeneca',
        'dosageForm': 'Tablet',
      },
      {
        'id': '4',
        'name': 'Atorvastatin',
        'generics': 'Atorvastatin Calcium',
        'manufacturer': 'Pfizer',
        'dosageForm': 'Tablet',
      },
      {
        'id': '5',
        'name': 'Metformin',
        'generics': 'Metformin Hydrochloride',
        'manufacturer': 'Merck',
        'dosageForm': 'Tablet',
      },
    ];

    // Add each medicine to Firestore
    for (var medicine in sampleMedicines) {
      await _medicinesCollection.doc(medicine['id']).set({
        'name': medicine['name'],
        'generics': medicine['generics'],
        'manufacturer': medicine['manufacturer'],
        'dosageForm': medicine['dosageForm'],
      });
    }
  }
}
