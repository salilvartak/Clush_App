import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:clush/services/crypto_service.dart';

void main() {
  group('CryptoService E2EE tests', () {
    // ── Helper: simulate two users deriving the same shared key ──────────────
    Future<SecretKey> deriveKey(SimpleKeyPair myPair, SimplePublicKey theirPub, String roomId) async {
      final algorithm = X25519();
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

      final sharedSecret = await algorithm.sharedSecretKey(
        keyPair: myPair,
        remotePublicKey: theirPub,
      );

      return hkdf.deriveKey(
        secretKey: sharedSecret,
        nonce: 'ClushChat_v2'.codeUnits,
        info: roomId.codeUnits,
      );
    }

    test('X25519 DH produces the same shared secret on both sides', () async {
      final algorithm = X25519();
      final alice = await algorithm.newKeyPair();
      final bob = await algorithm.newKeyPair();

      final alicePub = await alice.extractPublicKey();
      final bobPub = await bob.extractPublicKey();

      final aliceKey = await deriveKey(alice, bobPub, 'room_abc_xyz');
      final bobKey = await deriveKey(bob, alicePub, 'room_abc_xyz');

      final aliceBytes = await aliceKey.extractBytes();
      final bobBytes = await bobKey.extractBytes();

      expect(aliceBytes, equals(bobBytes),
          reason: 'Both sides must derive the same 32-byte key');

      print('✅ Shared key (first 8 bytes): ${aliceBytes.take(8).toList()}');
    });

    test('Different room IDs produce different keys (key isolation)', () async {
      final algorithm = X25519();
      final alice = await algorithm.newKeyPair();
      final bob = await algorithm.newKeyPair();
      final bobPub = await bob.extractPublicKey();

      final key1 = await deriveKey(alice, bobPub, 'room_aaa_bbb');
      final key2 = await deriveKey(alice, bobPub, 'room_aaa_ccc');

      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();

      expect(bytes1, isNot(equals(bytes2)),
          reason: 'Different rooms must have different keys');

      print('✅ Key isolation confirmed across different rooms');
    });

    test('encryptMessage → decryptMessage round-trip', () async {
      final algorithm = X25519();
      final alice = await algorithm.newKeyPair();
      final bob = await algorithm.newKeyPair();
      final bobPub = await bob.extractPublicKey();

      final key = await deriveKey(alice, bobPub, 'test_room');

      const plaintext = 'Hello, this is a secret message! 🔐';
      final envelope = await CryptoService.encryptMessage(plaintext, key);

      // Envelope must be valid JSON with v=2
      expect(envelope, contains('"v":2'));
      expect(envelope, contains('"ct"'));
      expect(envelope, contains('"iv"'));

      // Must NOT contain the plaintext
      expect(envelope, isNot(contains('Hello')));

      // Decrypt must recover original
      final decrypted = await CryptoService.decryptMessage(envelope, key);
      expect(decrypted, equals(plaintext));

      print('✅ Encrypted:  ${envelope.substring(0, 60)}...');
      print('✅ Decrypted:  $decrypted');
    });

    test('Each encryption produces a different ciphertext (random IV)', () async {
      final algorithm = X25519();
      final keyPair = await algorithm.newKeyPair();
      final pub = await keyPair.extractPublicKey();
      final key = await deriveKey(keyPair, pub, 'test_room');

      const plaintext = 'Same message';
      final envelope1 = await CryptoService.encryptMessage(plaintext, key);
      final envelope2 = await CryptoService.encryptMessage(plaintext, key);

      expect(envelope1, isNot(equals(envelope2)),
          reason: 'Random IV means ciphertext must differ each time');

      print('✅ Envelope 1: ${envelope1.substring(0, 50)}...');
      print('✅ Envelope 2: ${envelope2.substring(0, 50)}...');
    });

    test('Wrong key cannot decrypt message', () async {
      final algorithm = X25519();
      final alice = await algorithm.newKeyPair();
      final bob = await algorithm.newKeyPair();
      final eve = await algorithm.newKeyPair();

      final bobPub = await bob.extractPublicKey();
      final evePub = await eve.extractPublicKey();

      final aliceKey = await deriveKey(alice, bobPub, 'test_room');
      final eveKey = await deriveKey(alice, evePub, 'test_room'); // wrong pair

      const plaintext = 'Top secret';
      final envelope = await CryptoService.encryptMessage(plaintext, aliceKey);

      // Eve's key should fail to decrypt
      final eveResult = await CryptoService.decryptMessage(envelope, eveKey);
      expect(eveResult, isNull,
          reason: 'Wrong key must return null, not throw');

      // Correct key still works
      final correct = await CryptoService.decryptMessage(envelope, aliceKey);
      expect(correct, equals(plaintext));

      print('✅ Eve got: $eveResult (null = correct, decryption failed)');
      print('✅ Alice got: $correct');
    });

    test('encryptBytes → decryptBytes round-trip', () async {
      final algorithm = X25519();
      final keyPair = await algorithm.newKeyPair();
      final pub = await keyPair.extractPublicKey();
      final key = await deriveKey(keyPair, pub, 'test_room');

      final originalBytes = List.generate(256, (i) => i % 256);
      final envelope = await CryptoService.encryptBytes(
          Uint8List.fromList(originalBytes), key);

      final decryptedBytes = await CryptoService.decryptBytes(envelope, key);
      expect(decryptedBytes, isNotNull);
      expect(decryptedBytes!.toList(), equals(originalBytes));

      print('✅ Bytes round-trip: ${originalBytes.length} bytes encrypted and recovered');
    });
  });
}
