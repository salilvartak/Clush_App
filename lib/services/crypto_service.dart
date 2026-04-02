// lib/services/crypto_service.dart
//
// True E2EE using X25519 Diffie-Hellman + HKDF + AES-256-GCM.
// The server stores only ciphertext and can never decrypt messages.
//
// Key lifecycle:
//   1. On first app launch, generateAndStoreKeyPair() creates a Curve25519
//      key pair, saves the private key in flutter_secure_storage, and uploads
//      the public key (base64) to profiles.public_key in Supabase.
//   2. When opening a chat, getOrDeriveConversationKey(roomId, theirPublicKeyB64)
//      performs X25519 DH + HKDF to get a 32-byte symmetric key unique to
//      this conversation pair.
//   3. encryptMessage / decryptMessage use AES-256-GCM with a random 12-byte
//      nonce per message.  The wire format stored in Supabase is:
//        { "ct": "<base64 ciphertext+tag>", "iv": "<base64 nonce>", "v": 2 }

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CryptoService {
  static const _privateKeyStorageKey = 'clush_x25519_private_key';
  static const _publicKeyStorageKey = 'clush_x25519_public_key';
  static const _hkdfSalt = 'ClushChat_v2';

  static final _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // -------------------------------------------------------------------------
  // Key-pair management
  // -------------------------------------------------------------------------

  /// Returns existing public key bytes or generates + persists a new pair.
  static Future<Uint8List> getOrCreatePublicKey() async {
    final stored = await _storage.read(key: _publicKeyStorageKey);
    if (stored != null) return base64Decode(stored);

    return _generateAndStoreKeyPair();
  }

  static Future<Uint8List> _generateAndStoreKeyPair() async {
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    final pubB64 = base64Encode(publicKey.bytes);
    final privB64 = base64Encode(privateKeyBytes);

    await _storage.write(key: _publicKeyStorageKey, value: pubB64);
    await _storage.write(key: _privateKeyStorageKey, value: privB64);

    return Uint8List.fromList(publicKey.bytes);
  }

  /// Uploads the user's public key to Supabase profiles if not already set.
  static Future<void> ensurePublicKeyUploaded() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final pubKeyBytes = await getOrCreatePublicKey();
    final pubKeyB64 = base64Encode(pubKeyBytes);

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'public_key': pubKeyB64})
          .eq('id', uid);
    } catch (e) {
      // Non-fatal – will retry next launch
    }
  }

  // -------------------------------------------------------------------------
  // Shared-secret derivation
  // -------------------------------------------------------------------------

  /// Derives a 32-byte AES key for `roomId` using X25519 + HKDF.
  /// `theirPublicKeyB64` is the base64-encoded Curve25519 public key of
  /// the other participant, fetched from profiles.public_key.
  static Future<SecretKey> deriveConversationKey(
      String roomId, String theirPublicKeyB64) async {
    final privB64 = await _storage.read(key: _privateKeyStorageKey);
    if (privB64 == null) throw StateError('Private key not found – call ensurePublicKeyUploaded first');

    final privBytes = base64Decode(privB64);
    final theirPubBytes = base64Decode(theirPublicKeyB64);

    final algorithm = X25519();
    final myKeyPair = await algorithm.newKeyPairFromSeed(privBytes);
    final theirPublicKey = SimplePublicKey(theirPubBytes, type: KeyPairType.x25519);

    final sharedSecretKey = await algorithm.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: theirPublicKey,
    );

    // HKDF to bind the shared secret to this specific conversation
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derivedKey = await hkdf.deriveKey(
      secretKey: sharedSecretKey,
      nonce: utf8.encode(_hkdfSalt),
      info: utf8.encode(roomId),
    );

    return derivedKey;
  }

  // -------------------------------------------------------------------------
  // Message encryption / decryption
  // -------------------------------------------------------------------------

  /// Encrypts [plaintext] and returns a JSON string suitable for storage
  /// in the `encrypted_content` column.
  static Future<String> encryptMessage(String plaintext, SecretKey key) async {
    final aesGcm = AesGcm.with256bits();
    final nonce = aesGcm.newNonce();
    final secretBox = await aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );

    return jsonEncode({
      'ct': base64Encode(secretBox.cipherText + secretBox.mac.bytes),
      'iv': base64Encode(nonce),
      'v': 2,
    });
  }

  /// Decrypts a JSON envelope produced by [encryptMessage].
  /// Returns the plaintext, or null on any failure (corrupted / legacy msg).
  static Future<String?> decryptMessage(String envelope, SecretKey key) async {
    try {
      final map = jsonDecode(envelope) as Map<String, dynamic>;

      // Legacy v1 messages (AES-CBC) – return the raw field so UI shows it
      if ((map['v'] as int? ?? 0) < 2) {
        return map['data'] as String? ?? envelope;
      }

      final ctWithTag = base64Decode(map['ct'] as String);
      final nonce = base64Decode(map['iv'] as String);

      // Last 16 bytes are the GCM authentication tag
      final cipherText = ctWithTag.sublist(0, ctWithTag.length - 16);
      final mac = Mac(ctWithTag.sublist(ctWithTag.length - 16));

      final aesGcm = AesGcm.with256bits();
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
      final plainBytes = await aesGcm.decrypt(secretBox, secretKey: key);

      return utf8.decode(plainBytes);
    } catch (_) {
      return null; // Decryption failure – show placeholder in UI
    }
  }

  /// Encrypts raw bytes (image / audio) using the same key.
  /// Returns base64-encoded JSON envelope.
  static Future<String> encryptBytes(Uint8List bytes, SecretKey key) async {
    final aesGcm = AesGcm.with256bits();
    final nonce = aesGcm.newNonce();
    final secretBox = await aesGcm.encrypt(bytes, secretKey: key, nonce: nonce);

    return jsonEncode({
      'ct': base64Encode(secretBox.cipherText + secretBox.mac.bytes),
      'iv': base64Encode(nonce),
      'v': 2,
    });
  }

  /// Decrypts a bytes envelope produced by [encryptBytes].
  static Future<Uint8List?> decryptBytes(String envelope, SecretKey key) async {
    try {
      final map = jsonDecode(envelope) as Map<String, dynamic>;
      final ctWithTag = base64Decode(map['ct'] as String);
      final nonce = base64Decode(map['iv'] as String);
      final cipherText = ctWithTag.sublist(0, ctWithTag.length - 16);
      final mac = Mac(ctWithTag.sublist(ctWithTag.length - 16));

      final aesGcm = AesGcm.with256bits();
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
      final plain = await aesGcm.decrypt(secretBox, secretKey: key);
      return Uint8List.fromList(plain);
    } catch (_) {
      return null;
    }
  }
}
