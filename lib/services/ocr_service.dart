import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class OCRService {
  static const String OCR_API_ENDPOINT =
      'https://markhany168--ocr-serve.modal.run/ocr';

  /// Processes an image with OCR to extract medicine information
  ///
  /// [imageFile] - The image file containing the prescription to scan
  ///
  /// Returns a Map containing the medicine information if successful
  static Future<List<Map<String, dynamic>>> scanPrescription(
      File imageFile) async {
    try {
      // Create multipart request
      final request =
          http.MultipartRequest('POST', Uri.parse(OCR_API_ENDPOINT));

      // Get file extension (jpg or png)
      final String extension = imageFile.path.split('.').last.toLowerCase();
      final String mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';

      // Add the image file to the request
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();

      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: 'prescription_image.$extension',
        contentType: MediaType('image', extension),
      );

      request.files.add(multipartFile);

      // Log that we're about to send the request
      print('📷 Sending prescription image to OCR API...');

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Check for successful response
      if (response.statusCode == 200) {
        // Parse JSON response
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // Check if medicines key exists
        if (jsonResponse.containsKey('medicines')) {
          final List<dynamic> medicines = jsonResponse['medicines'];

          // Convert to List of Maps
          final List<Map<String, dynamic>> medicinesList = medicines
              .map((medicine) => medicine as Map<String, dynamic>)
              .toList();

          print(
              '✅ Successfully parsed ${medicinesList.length} medicines from OCR');
          return medicinesList;
        } else {
          print(
              '❌ OCR response does not contain medicines key: ${response.body}');
          throw Exception('Invalid OCR response format');
        }
      } else {
        print('❌ OCR API error: ${response.statusCode} - ${response.body}');
        throw Exception('OCR API returned status code ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error scanning prescription: $e');
      throw Exception('Failed to scan prescription: $e');
    }
  }
}
