import 'dart:convert';
import 'dart:math';

/// base64url ohne Auffuellzeichen, wie es in Links und auf der Leitung
/// steht. Ein `=` am Ende waere im Link-Fragment nur Ballast.
String b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// Gegenstueck zu [b64]; nimmt auch Text mit Auffuellzeichen. Wirft
/// [FormatException] bei Unsinn.
List<int> unb64(String text) {
  final clean = text.replaceAll('=', '');
  if (!RegExp(r'^[A-Za-z0-9_-]*$').hasMatch(clean)) {
    throw const FormatException('kein base64url');
  }
  final pad = (4 - clean.length % 4) % 4;
  if (pad == 3) throw const FormatException('falsche Laenge');
  return base64Url.decode(clean + '=' * pad);
}

final _random = Random.secure();

/// [length] Zufallsbytes aus der sicheren Quelle des Systems.
List<int> randomBytes(int length) =>
    List<int>.generate(length, (_) => _random.nextInt(256));

/// Neue zufaellige ID: 16 Bytes, base64url (22 Zeichen). Fuer Listen und
/// Operationen; zufaellig genug, dass niemand eine fremde erraten kann.
String newId() => b64(randomBytes(16));

/// Neues Geheimnis fuer Link oder Ersteller: 32 Bytes.
List<int> newSecret() => randomBytes(32);

/// Neuer Code (G4): 6 Ziffern, fuehrende Nullen erlaubt.
String newCode() => List.generate(6, (_) => _random.nextInt(10)).join();

/// Prueft eine ID im Format von [newId]. Der Server nimmt nur solche an.
bool isValidId(String id) => RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(id);

/// Ein Code, wie ihn Menschen eintippen: Leerzeichen und Bindestriche
/// fallen weg. Leer heisst „kein Code“.
String normalizeCode(String? code) =>
    (code ?? '').replaceAll(RegExp(r'[\s-]'), '');
