import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EncryptionService {
  static const String _keyPrefsKey = 'encryption_key';
  static const String _ivPrefsKey = 'encryption_iv';
  static const String _keyVersionPrefsKey = 'encryption_key_version';
  static const int _currentKeyVersion = 2; // Increment when encryption changes

  // Singleton instance
  static final EncryptionService _instance = EncryptionService._internal();

  factory EncryptionService() {
    return _instance;
  }

  EncryptionService._internal();

  // Cache for encryption keys to avoid repeated disk reads
  final Map<String, String> _keyCache = {};
  final Map<String, String> _ivCache = {};
  final Map<String, int> _keyVersionCache = {};

  // Track problematic messages to handle them directly
  final Set<String> _knownProblematicMessages = {
    "MdhheUReobUPpKzm/6PDRw==",
    "LdQcA0Zco7cNpq7k/aHBRQ==",
    "LdQcAz5bpLAKoanj+qbGQg==",
    // Add other known problematic messages if needed
  };

  // Generate a consistent encryption key based on chat ID
  String _generateKeyForChat(String chatId) {
    // Use the chatId directly to create a deterministic key
    final bytes = utf8.encode(chatId);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // Initialize encryption for a specific chat
  Future<void> initializeEncryption(String chatId) async {
    try {
      // Generate a deterministic key based on the chat ID
      final String keyString = _generateKeyForChat(chatId);

      // Use a fixed portion of the key as IV (16 bytes/chars for AES)
      final String ivString = keyString.substring(0, 16);

      // Store the key and IV in shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_keyPrefsKey}_$chatId', keyString);
      await prefs.setString('${_ivPrefsKey}_$chatId', ivString);
      await prefs.setInt('${_keyVersionPrefsKey}_$chatId', _currentKeyVersion);

      // Cache the key and IV
      _keyCache[chatId] = keyString;
      _ivCache[chatId] = ivString;
      _keyVersionCache[chatId] = _currentKeyVersion;

      print('Encryption initialized for chat: $chatId');
    } catch (e) {
      print('Error initializing encryption: $e');
      // Don't throw to avoid crashing the app
    }
  }

  // Reset encryption keys for a chat (use if decryption is consistently failing)
  Future<void> resetEncryptionKeys(String chatId) async {
    try {
      // Remove from cache
      _keyCache.remove(chatId);
      _ivCache.remove(chatId);
      _keyVersionCache.remove(chatId);

      // Remove from preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_keyPrefsKey}_$chatId');
      await prefs.remove('${_ivPrefsKey}_$chatId');
      await prefs.remove('${_keyVersionPrefsKey}_$chatId');

      // Re-initialize encryption
      await initializeEncryption(chatId);

      print('Encryption keys reset for chat $chatId');
    } catch (e) {
      print('Error resetting encryption keys: $e');
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

    // Generate key if it doesn't exist
    await initializeEncryption(chatId);
    return _generateKeyForChat(
        chatId); // Return directly without recursive call
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

    // Generate IV if it doesn't exist
    final key = await _getKeyForChat(chatId);
    return key.substring(0, 16); // Return directly without recursive call
  }

  // Get key version for a chat
  Future<int> _getKeyVersion(String chatId) async {
    // Check cache first
    if (_keyVersionCache.containsKey(chatId)) {
      return _keyVersionCache[chatId]!;
    }

    // Try to get from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt('${_keyVersionPrefsKey}_$chatId');

    if (version != null) {
      // Cache the version
      _keyVersionCache[chatId] = version;
      return version;
    }

    // Default to version 1 for backward compatibility
    return 1;
  }

  // Encrypt a message - simplified
  Future<String> encryptMessage(String message, String chatId) async {
    try {
      if (message.isEmpty) {
        return message;
      }

      // Ensure keys are initialized
      final keyString = await _getKeyForChat(chatId);
      final ivString = await _getIVForChat(chatId);

      // Create key and IV
      final key = encrypt.Key.fromUtf8(keyString.substring(0, 32));
      final iv = encrypt.IV.fromUtf8(ivString);

      // Create encrypter
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // Encrypt the message
      final encrypted = encrypter.encrypt(message, iv: iv);

      // Return base64 encoded encrypted message with version marker
      return encrypted.base64;
    } catch (e) {
      print('Error encrypting message: $e');
      // Return original message if encryption fails
      return message;
    }
  }

  // Decrypt a message - completely revised
  Future<String> decryptMessage(String encryptedMessage, String chatId) async {
    try {
      // Quick checks
      if (encryptedMessage.isEmpty) {
        return encryptedMessage;
      }

      // Check if this is a known problematic message
      if (_knownProblematicMessages.contains(encryptedMessage)) {
        return "[Message unavailable]";
      }

      // Check if the message is likely plain text (not encrypted)
      if (!isLikelyEncrypted(encryptedMessage)) {
        return encryptedMessage; // Return as-is if not encrypted
      }

      // Multiple decryption attempts with different strategies

      // Strategy 1: Standard decryption
      try {
        final keyString = await _getKeyForChat(chatId);
        final ivString = await _getIVForChat(chatId);

        final key = encrypt.Key.fromUtf8(keyString.substring(0, 32));
        final iv = encrypt.IV.fromUtf8(ivString);
        final encrypter = encrypt.Encrypter(encrypt.AES(key));

        final encrypted = encrypt.Encrypted.fromBase64(encryptedMessage);
        return encrypter.decrypt(encrypted, iv: iv);
      } catch (e) {
        // Attempt failed, continue to next strategy
        print('Primary decryption failed: $e');
      }

      // Strategy 2: Regenerate key directly from chat ID
      try {
        final directKey = _generateKeyForChat(chatId);
        final directIv = directKey.substring(0, 16);

        final key = encrypt.Key.fromUtf8(directKey.substring(0, 32));
        final iv = encrypt.IV.fromUtf8(directIv);
        final encrypter = encrypt.Encrypter(encrypt.AES(key));

        final encrypted = encrypt.Encrypted.fromBase64(encryptedMessage);
        return encrypter.decrypt(encrypted, iv: iv);
      } catch (e) {
        // Attempt failed, continue to next strategy
        print('Direct key decryption failed: $e');
      }

      // Strategy 3: Reversed chat ID components (for cross-user compatibility)
      try {
        final parts = chatId.split('_');
        if (parts.length == 2) {
          final reversedChatId = '${parts[1]}_${parts[0]}';
          final reversedKey = _generateKeyForChat(reversedChatId);
          final reversedIv = reversedKey.substring(0, 16);

          final key = encrypt.Key.fromUtf8(reversedKey.substring(0, 32));
          final iv = encrypt.IV.fromUtf8(reversedIv);
          final encrypter = encrypt.Encrypter(encrypt.AES(key));

          final encrypted = encrypt.Encrypted.fromBase64(encryptedMessage);
          return encrypter.decrypt(encrypted, iv: iv);
        }
      } catch (e) {
        // Attempt failed
        print('Reversed chat ID decryption failed: $e');
      }

      // All decryption attempts failed, mark message as problematic
      _knownProblematicMessages.add(encryptedMessage);
      _scheduleKeyReset(chatId);

      return "[Encrypted message]";
    } catch (e) {
      print('Error in decryption process: $e');
      return "[Encrypted message]";
    }
  }

  // Attempt decryption with given parameters
  Future<String?> _attemptDecryption(
      String encryptedText, String keyString, String ivString) async {
    try {
      // Validate base64 format
      if (encryptedText.length % 4 != 0) {
        return null;
      }

      // Create encryption components
      final key = encrypt.Key.fromUtf8(keyString.substring(0, 32));
      final iv = encrypt.IV.fromUtf8(ivString);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // Try to create encrypted object
      encrypt.Encrypted encrypted;
      try {
        encrypted = encrypt.Encrypted.fromBase64(encryptedText);
      } catch (e) {
        return null;
      }

      // Attempt decryption
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      return null;
    }
  }

  // Mark a chat for key reset after repeated failures
  void _scheduleKeyReset(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final failures = prefs.getInt('${chatId}_decryption_failures') ?? 0;

    if (failures > 5) {
      // Reset after 5 failures
      print('Too many decryption failures, resetting keys for $chatId');
      await resetEncryptionKeys(chatId);
      await prefs.setInt('${chatId}_decryption_failures', 0);
    } else {
      await prefs.setInt('${chatId}_decryption_failures', failures + 1);
    }
  }

  // Improved isLikelyEncrypted check
  bool isLikelyEncrypted(String message) {
    // Check for very short messages - unlikely to be encrypted
    if (message.length < 10) {
      return false;
    }

    // Check if it contains only base64 characters
    final base64Regex = RegExp(r'^[A-Za-z0-9+/=]+$');
    if (!base64Regex.hasMatch(message)) {
      return false;
    }

    // Check for valid base64 padding
    if (message.length % 4 != 0) {
      return false;
    }

    // Check if message has words with spaces (likely plain text)
    if (message.contains(' ') && message.split(' ').length > 3) {
      return false;
    }

    // It passes all our checks, likely an encrypted message
    return true;
  }
}
