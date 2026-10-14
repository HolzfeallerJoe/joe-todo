import 'dart:convert';
import 'dart:io';

import 'package:joe_sync/joe_sync.dart';
import 'package:test/test.dart';

void main() {
  // Erzeugt mit WebCrypto (tool/crypto_vectors.mjs): Dart muss dieselben
  // Bytes rechnen wie der Browser.
  final vectors =
      (jsonDecode(File('test/vectors/crypto.json').readAsStringSync())['cases']
              as List)
          .cast<Map<String, dynamic>>();

  for (final v in vectors) {
    final listId = v['listId'] as String;
    final secret = unb64(v['secret'] as String);
    final code = v['code'] as String;

    group('Testvektor $listId (Code: ${code.isEmpty ? 'nein' : 'ja'})', () {
      test('K, A und Ersteller-Token wie im Browser', () async {
        expect(b64(await JoeCrypto.listKey(listId, secret)), v['key']);
        expect(
          await JoeCrypto.accessToken(listId, secret, code),
          v['accessToken'],
        );
        expect(
          await JoeCrypto.ownerToken(listId, unb64(v['ownerSecret'] as String)),
          v['ownerToken'],
        );
      });

      test('Hashes, wie der Server sie speichert', () async {
        expect(
          await JoeCrypto.tokenHash(v['accessToken'] as String),
          v['accessHash'],
        );
        expect(
          await JoeCrypto.tokenHash(v['ownerToken'] as String),
          v['ownerHash'],
        );
      });

      test('Verschluesseln ergibt denselben Block', () async {
        final key = unb64(v['key'] as String);
        final body = jsonDecode(v['plain'] as String) as Map<String, Object?>;
        expect(
          await JoeCrypto.seal(
            key,
            listId,
            v['opId'] as String,
            body,
            nonce: unb64(v['nonce'] as String),
          ),
          v['blob'],
        );
      });

      test('Entschluesseln liefert den Klartext', () async {
        final key = unb64(v['key'] as String);
        final body = await JoeCrypto.open(
          key,
          listId,
          v['opId'] as String,
          v['blob'] as String,
        );
        expect(jsonEncode(body), v['plain']);
      });
    });
  }

  group('Verschluesselung', () {
    final secret = newSecret();
    const listId = 'AAECAwQFBgcICQoLDA0ODw';
    const opId = 'BBECAwQFBgcICQoLDA0ODw';
    final body = {'v': 1, 'op': 'list.name', 'device': 'd', 'name': 'Baumarkt'};

    test('jeder Block hat einen frischen Nonce', () async {
      final key = await JoeCrypto.listKey(listId, secret);
      final a = await JoeCrypto.seal(key, listId, opId, body);
      final b = await JoeCrypto.seal(key, listId, opId, body);
      expect(a, isNot(b));
      expect(await JoeCrypto.open(key, listId, opId, a), body);
    });

    test('falscher Schluessel, fremde Liste oder ID schlagen fehl', () async {
      final key = await JoeCrypto.listKey(listId, secret);
      final other = await JoeCrypto.listKey(listId, newSecret());
      final blob = await JoeCrypto.seal(key, listId, opId, body);
      final failure = throwsA(isA<SyncCryptoException>());
      await expectLater(JoeCrypto.open(other, listId, opId, blob), failure);
      await expectLater(
        JoeCrypto.open(key, 'CCECAwQFBgcICQoLDA0ODw', opId, blob),
        failure,
      );
      await expectLater(
        JoeCrypto.open(key, listId, 'CCECAwQFBgcICQoLDA0ODw', blob),
        failure,
      );
      await expectLater(JoeCrypto.open(key, listId, opId, 'kaputt!'), failure);
      // Ein veraendertes Byte faellt am Tag auf.
      final bytes = unb64(blob);
      bytes[20] ^= 1;
      await expectLater(JoeCrypto.open(key, listId, opId, b64(bytes)), failure);
    });

    test('der Code aendert nur das Zugangstoken', () async {
      final ohne = await JoeCrypto.accessToken(listId, secret, null);
      expect(await JoeCrypto.accessToken(listId, secret, ''), ohne);
      final mit = await JoeCrypto.accessToken(listId, secret, '123456');
      expect(mit, isNot(ohne));
      // Leerzeichen und Bindestriche beim Eintippen zaehlen nicht.
      expect(await JoeCrypto.accessToken(listId, secret, '123 456'), mit);
      expect(await JoeCrypto.accessToken(listId, secret, '123-456'), mit);
    });
  });

  group('IDs und Codes', () {
    test('newId ist gueltig und zufaellig', () {
      final ids = {for (var i = 0; i < 100; i++) newId()};
      expect(ids, hasLength(100));
      expect(ids.every(isValidId), isTrue);
      expect(isValidId('zu-kurz'), isFalse);
      expect(isValidId('AAECAwQFBgcICQoLDA0OD!'), isFalse);
    });

    test('newCode hat sechs Ziffern', () {
      for (var i = 0; i < 50; i++) {
        expect(newCode(), matches(RegExp(r'^\d{6}$')));
      }
    });

    test('base64url hin und zurueck, auch mit Auffuellzeichen', () {
      final bytes = [0, 1, 250, 251, 252, 253, 254, 255];
      expect(b64(bytes), isNot(contains('=')));
      expect(unb64(b64(bytes)), bytes);
      expect(unb64('AAH6-_z9_v8='), bytes);
      expect(() => unb64('a+b/'), throwsFormatException);
    });
  });
}
