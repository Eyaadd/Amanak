import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EncryptionService {
  static const String _keyPrefsKey = 'encryption_key';
  static const String _ivPrefsKey = 'encryption_iv';

  // Singleton instance
  static final EncryptionService _instance = EncryptionService._internal();

  factory EncryptionService() {
    return _instance;
  }

  EncryptionService._internal();

  // Cache for encryption keys to avoid repeated disk reads
  final Map<String, String> _keyCache = {};
  final Map<String, String> _ivCache = {};

  // Generate a deterministic encryption key based on user IDs
  String _generateKeyForUsers(String userIdA, String userIdB) {
    // Sort user IDs to ensure the same key is generated regardless of order
    final List<String> sortedIds = [userIdA, userIdB]..sort();
    final String combinedIds = '${sortedIds[0]}:${sortedIds[1]}';

    // Generate a SHA-256 hash of the combined IDs
    final bytes = utf8.encode(combinedIds);
    final hash = sha256.convert(bytes);

    // Return the first 32 bytes (256 bits) as a hex string
    return hash.toString();
  }

  // Initialize encryption for a specific chat
  Future<void> initializeEncryption(String chatId) async {
    try {
      // Parse the chat ID to extract user IDs or emails
      final parts = chatId.split('_');
      if (parts.length != 2) {
        throw Exception('Invalid chat ID format');
      }

      // Get current user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Generate a deterministic key based on the user IDs
      final String keyString = _generateKeyForUsers(
          currentUser.uid, parts[0] == currentUser.email ? parts[1] : parts[0]);

      // Generate a deterministic IV (Initialization Vector)
      final String ivString = keyString.substring(0, 16);

      // Store the key and IV in shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_keyPrefsKey}_$chatId', keyString);
      await prefs.setString('${_ivPrefsKey}_$chatId', ivString);

      // Cache the key and IV
      _keyCache[chatId] = keyString;
      _ivCache[chatId] = ivString;
    } catch (e) {
      print('Error initializing encryption: $e');
      rethrow;
    }
  }

  // Get the encryption key for a specific chat
  Future<String> _getKeyForChat(String chatId) async {
    // Check cache first
    if (_keyCache.containsKey(chatId)) {
      return _keyCache[chatId]!;
    }

    // Try to get from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final keyString = prefs.getString('${_keyPrefsKey}_$chatId');

    if (keyString != null) {
      // Cache the key
      _keyCache[chatId] = keyString;
      return keyString;
    }

    // Initialize encryption if key doesn't exist
    await initializeEncryption(chatId);
    return _getKeyForChat(chatId);
  }

  // Get the IV for a specific chat
  Future<String> _getIVForChat(String chatId) async {
    // Check cache first
    if (_ivCache.containsKey(chatId)) {
      return _ivCache[chatId]!;
    }

    // Try to get from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final ivString = prefs.getString('${_ivPrefsKey}_$chatId');

    if (ivString != null) {
      // Cache the IV
      _ivCache[chatId] = ivString;
      return ivString;
    }

    // Initialize encryption if IV doesn't exist
    await initializeEncryption(chatId);
    return _getIVForChat(chatId);
  }

  // Encrypt a message
  Future<String> encryptMessage(String message, String chatId) async {
    try {
      if (message.isEmpty) {
        return message;
      }

      final keyString = await _getKeyForChat(chatId);
      final ivString = await _getIVForChat(chatId);

      // Create key and IV
      final key = encrypt.Key.fromUtf8(keyString.substring(0, 32));
      final iv = encrypt.IV.fromUtf8(ivString);

      // Create encrypter
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // Encrypt the message
      final encrypted = encrypter.encrypt(message, iv: iv);

      // Return base64 encoded encrypted message
      return encrypted.base64;
    } catch (e) {
      print('Error encrypting message: $e');
      // Return original message if encryption fails
      return message;
    }
  }

  // Decrypt a message
  Future<String> decryptMessage(String encryptedMessage, String chatId) async {
    try {
      if (encryptedMessage.isEmpty) {
        return encryptedMessage;
      }

      // Check if the message is actually encrypted
      if (!isLikelyEncrypted(encryptedMessage)) {
        // If it doesn't look like an encrypted message, return as is
        return encryptedMessage;
      }

      final keyString = await _getKeyForChat(chatId);
      final ivString = await _getIVForChat(chatId);

      // Create key and IV
      final key = encrypt.Key.fromUtf8(keyString.substring(0, 32));
      final iv = encrypt.IV.fromUtf8(ivString);

      // Create encrypter
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // Decrypt the message
      try {
        final decrypted = encrypter
            .decrypt(encrypt.Encrypted.fromBase64(encryptedMessage), iv: iv);
        return decrypted;
      } catch (e) {
        // If decryption fails, it might be an unencrypted message
        print('Decryption failed, returning original message: $e');
        return encryptedMessage;
      }
    } catch (e) {
      print('Error decrypting message: $e');
      // Return original message if decryption fails
      return encryptedMessage;
    }
  }

  // Check if a message is likely encrypted (better than isEncrypted)
  bool isLikelyEncrypted(String message) {
    // Most encrypted base64 strings:
    // 1. Are longer than typical chat messages
    // 2. Contain only valid base64 characters (A-Z, a-z, 0-9, +, /, =)
    // 3. Have a length that's a multiple of 4 (base64 padding)

    // Quick check for very short messages - unlikely to be encrypted
    if (message.length < 10) {
      return false;
    }

    // Check if it contains only base64 characters
    final base64Regex = RegExp(r'^[A-Za-z0-9+/=]+$');
    if (!base64Regex.hasMatch(message)) {
      return false;
    }

    // Check if length is multiple of 4 (base64 requirement)
    if (message.length % 4 != 0) {
      return false;
    }

    // It passes all our checks, likely an encrypted message
    return true;
  }

  // Original isEncrypted method - less reliable
  bool isEncrypted(String message) {
    try {
      // Try to decode as base64
      base64.decode(message);

      // If no exception was thrown, it's likely encrypted
      return true;
    } catch (e) {
      // If an exception was thrown, it's not valid base64, so not encrypted
      return false;
    }
  }
}
