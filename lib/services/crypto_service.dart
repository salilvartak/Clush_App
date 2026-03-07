// lib/services/crypto_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class CryptoService {
  late enc.Encrypter _encrypter;
  late enc.IV _iv;

  // Initialize the engine with the Room Name
  CryptoService(String roomName) {
    // We derive a secure 256-bit (32 byte) key using SHA-256 on the room name
    // The server NEVER calculates this. Only the phones do.
    var bytes = utf8.encode("ClushSecret_$roomName");
    var digest = sha256.convert(bytes);
    final key = enc.Key(Uint8List.fromList(digest.bytes));

    // Derive a deterministic 16-byte IV using MD5 on the room name
    var ivBytes = utf8.encode("ClushIV_$roomName");
    var ivDigest = md5.convert(ivBytes);
    _iv = enc.IV(Uint8List.fromList(ivDigest.bytes));
    
    _encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  }

  // --- TEXT / JSON PAYLOADS ---
  
  /// Encrypts a JSON string into a Base64 gibberish string
  String encryptPayload(String rawJson) {
    final encrypted = _encrypter.encrypt(rawJson, iv: _iv);
    return encrypted.base64;
  }

  /// Decrypts the Base64 gibberish back to JSON
  String decryptPayload(String encryptedBase64) {
    try {
      final decrypted = _encrypter.decrypt64(encryptedBase64, iv: _iv);
      return decrypted;
    } catch (e) {
      // Graceful fallback for legacy plaintext messages sent before E2E encryption was activated.
      // We wrap the plaintext in our new JSON structure so the UI can still read it.
      return jsonEncode({"type": "text", "data": encryptedBase64});
    }
  }

  // --- FILE BYTES (IMAGES/VOICE) ---

  /// Encrypts raw file bytes before uploading to Supabase
  Uint8List encryptBytes(Uint8List rawBytes) {
    final encrypted = _encrypter.encryptBytes(rawBytes, iv: _iv);
    return Uint8List.fromList(encrypted.bytes);
  }

  /// Decrypts downloaded gibberish bytes back into an Image/Audio
  Uint8List decryptBytes(Uint8List encryptedBytes) {
    final decrypted = _encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: _iv);
    return Uint8List.fromList(decrypted);
  }
}
