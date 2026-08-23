import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:convert/convert.dart';

const int _keyBytes = 32;
const int _nonceBytes = 12;
const int _iterations = 100000;

JSObject get _crypto => globalContext['crypto'] as JSObject;
JSObject get _subtle => _crypto['subtle'] as JSObject;

Uint8List _randomBytes(int length) {
  final bytes = Uint8List(length);
  _crypto.callMethodVarArgs<JSAny?>('getRandomValues'.toJS, [bytes.toJS]);
  return bytes;
}

Future<JSAny?> _await(dynamic promise) => (promise as JSPromise<JSAny?>).toDart;

Future<JSObject> _deriveAesKey(
  String password,
  Uint8List salt,
  int iterations,
) async {
  final baseKey = await _await(
    _subtle.callMethodVarArgs<JSAny?>('importKey'.toJS, [
      'raw'.toJS,
      Uint8List.fromList(utf8.encode(password)).toJS,
      {'name': 'PBKDF2'}.jsify()!,
      false.toJS,
      ['deriveKey'].jsify()!,
    ]),
  );
  final key = await _await(
    _subtle.callMethodVarArgs<JSAny?>('deriveKey'.toJS, [
      {
        'name': 'PBKDF2',
        'salt': salt,
        'iterations': iterations,
        'hash': 'SHA-256',
      }.jsify()!,
      baseKey!,
      {'name': 'AES-GCM', 'length': _keyBytes * 8}.jsify()!,
      false.toJS,
      ['encrypt', 'decrypt'].jsify()!,
    ]),
  );
  return key as JSObject;
}

Future<String?> encryptPayload(String password, String value) async {
  try {
    final salt = _randomBytes(32);
    final nonce = _randomBytes(_nonceBytes);
    final key = await _deriveAesKey(password, salt, _iterations);
    final encrypted = await _await(
      _subtle.callMethodVarArgs<JSAny?>('encrypt'.toJS, [
        {'name': 'AES-GCM', 'iv': nonce, 'tagLength': 128}.jsify()!,
        key,
        Uint8List.fromList(utf8.encode(value)).toJS,
      ]),
    );
    final cipherBytes = JSUint8Array(encrypted as JSArrayBuffer).toDart;
    return jsonEncode({
      'version': 1,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': _iterations,
      'salt': hex.encode(salt),
      'nonce': hex.encode(nonce),
      'cipherText': hex.encode(cipherBytes),
    });
  } catch (_) {
    return null;
  }
}

Future<String?> decryptPayload({
  required String password,
  required Uint8List salt,
  required Uint8List nonce,
  required Uint8List cipherText,
  required int iterations,
}) async {
  try {
    final key = await _deriveAesKey(password, salt, iterations);
    final plainText = await _await(
      _subtle.callMethodVarArgs<JSAny?>('decrypt'.toJS, [
        {'name': 'AES-GCM', 'iv': nonce, 'tagLength': 128}.jsify()!,
        key,
        cipherText.toJS,
      ]),
    );
    return utf8.decode(JSUint8Array(plainText as JSArrayBuffer).toDart);
  } catch (_) {
    return null;
  }
}
