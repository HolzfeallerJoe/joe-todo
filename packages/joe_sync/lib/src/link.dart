import 'encoding.dart';

/// Der Link einer geteilten Liste (G3):
/// `<server>/l/<listen-id>#<geheimnis>`.
///
/// Der Server darf einen Pfad haben (`https://example.org/joe`). Alles hinter
/// dem `#` schicken Browser und App nie mit, deshalb steht dort das
/// Geheimnis.
class ShareLink {
  /// Basisadresse des Servers, ohne `/` am Ende.
  final String server;
  final String listId;
  final List<int> secret;

  ShareLink({
    required String server,
    required this.listId,
    required this.secret,
  }) : server = server.endsWith('/')
           ? server.substring(0, server.length - 1)
           : server;

  static final _pattern = RegExp(
    r'(https?://[^\s#]+?)/l/([A-Za-z0-9_-]{22})#([A-Za-z0-9_-]{43})(?![A-Za-z0-9_-])',
  );

  /// Sucht einen Link in [text], auch mitten in einer Nachricht wie
  /// „Hier unsere Liste: https://…“. `null`, wenn keiner drinsteht.
  static ShareLink? tryParse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    final secret = unb64(match.group(3)!);
    if (secret.length != 32) return null;
    return ShareLink(
      server: match.group(1)!,
      listId: match.group(2)!,
      secret: secret,
    );
  }

  /// Der Link ohne Geheimnis – nur fuer Anzeigen wie „Server: …“.
  String get pageUrl => '$server/l/$listId';

  @override
  String toString() => '$pageUrl#${b64(secret)}';
}
