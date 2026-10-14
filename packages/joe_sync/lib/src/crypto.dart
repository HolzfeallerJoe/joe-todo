import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'encoding.dart';

/// Kryptografie der geteilten Listen (Konzept 4). Die Webseite rechnet
/// dasselbe mit WebCrypto nach; `test/vectors/crypto.json` haelt beide
/// auf denselben Bytes.
///
/// Genau festgelegt:
///
/// * HKDF-SHA256, Salt = UTF-8 der Listen-ID (die 22 Zeichen), 32 Bytes.
/// * `K` = HKDF(S, info `joe-v1-key`) – AES-256-GCM-Schluessel.
/// * `A` = HKDF(S ‖ UTF-8(Code), info `joe-v1-access`) – ohne Code nur S.
///   Auf der Leitung als `Authorization: Bearer <b64(A)>`.
/// * Ersteller-Token = HKDF(O, info `joe-v1-owner`), als
///   `X-Joe-Owner: <b64>`.
/// * Der Server speichert von beiden Tokens nur b64(SHA-256(Token-Bytes)).
/// * Block = b64(Nonce(12) ‖ Chiffrat ‖ Tag(16)), AAD = UTF-8 von
///   `<Listen-ID>:<Operations-ID>`.
class JoeCrypto {
  JoeCrypto._();

  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final _aes = AesGcm.with256bits();

  static Future<List<int>> _derive(
    List<int> ikm,
    String listId,
    String info,
  ) async {
    final key = await _hkdf.deriveKey(
      secretKey: SecretKey(ikm),
      nonce: utf8.encode(listId),
      info: utf8.encode(info),
    );
    return key.extractBytes();
  }

  /// `K`: der Schluessel fuer die Operationen einer Liste.
  static Future<List<int>> listKey(String listId, List<int> secret) =>
      _derive(secret, listId, 'joe-v1-key');

  /// `A` als base64url: das Zugangstoken. Der Code (falls gesetzt) steckt
  /// nur hier drin, der Server sieht ihn nie.
  static Future<String> accessToken(
    String listId,
    List<int> secret,
    String? code,
  ) async {
    final ikm = [...secret, ...utf8.encode(normalizeCode(code))];
    return b64(await _derive(ikm, listId, 'joe-v1-access'));
  }

  /// Token des Erstellers (Konzept 4.3) aus seinem Geheimnis `O`.
  static Future<String> ownerToken(
    String listId,
    List<int> ownerSecret,
  ) async => b64(await _derive(ownerSecret, listId, 'joe-v1-owner'));

  /// Was der Server von einem Token speichert und vergleicht.
  static Future<String> tokenHash(String token) async {
    final hash = await Sha256().hash(unb64(token));
    return b64(hash.bytes);
  }

  static List<int> _aad(String listId, String opId) =>
      utf8.encode('$listId:$opId');

  /// Verschluesselt den Klartext einer Operation. [nonce] nur fuer
  /// Testvektoren; sonst zieht AES-GCM einen frischen.
  static Future<String> seal(
    List<int> key,
    String listId,
    String opId,
    Map<String, Object?> body, {
    List<int>? nonce,
  }) async {
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(body)),
      secretKey: SecretKey(key),
      nonce: nonce ?? _aes.newNonce(),
      aad: _aad(listId, opId),
    );
    return b64(box.concatenation());
  }

  /// Entschluesselt einen Block. Falscher Schluessel, fremde Liste, fremde
  /// ID oder veraenderte Bytes: [SyncCryptoException].
  static Future<Map<String, Object?>> open(
    List<int> key,
    String listId,
    String opId,
    String blob,
  ) async {
    try {
      final box = SecretBox.fromConcatenation(
        unb64(blob),
        nonceLength: 12,
        macLength: 16,
      );
      final clear = await _aes.decrypt(
        box,
        secretKey: SecretKey(key),
        aad: _aad(listId, opId),
      );
      final body = jsonDecode(utf8.decode(clear));
      if (body is! Map<String, Object?>) {
        throw const FormatException('kein Objekt');
      }
      return body;
    } on SyncCryptoException {
      rethrow;
    } catch (e) {
      throw SyncCryptoException(e.runtimeType.toString());
    }
  }
}

/// Ein Block liess sich nicht entschluesseln oder lesen. Traegt bewusst
/// nur die Art des Fehlers, nie Bytes oder Schluessel.
class SyncCryptoException implements Exception {
  final String reason;
  const SyncCryptoException(this.reason);

  @override
  String toString() => 'SyncCryptoException($reason)';
}
