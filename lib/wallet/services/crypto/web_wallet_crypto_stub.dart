import 'dart:typed_data';

/// Native platforms use the existing isolate implementation.
Future<String?> encryptPayload(String password, String value) async => null;

/// Native platforms use PointyCastle for backwards-compatible decryption.
Future<String?> decryptPayload({
  required String password,
  required Uint8List salt,
  required Uint8List nonce,
  required Uint8List cipherText,
  required int iterations,
}) async => null;
