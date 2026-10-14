import 'package:joe_sync/joe_sync.dart';
import 'package:test/test.dart';

void main() {
  final secret = List<int>.generate(32, (i) => i);
  const listId = 'AAECAwQFBgcICQoLDA0ODw';

  test('Link hin und zurueck', () {
    final link = ShareLink(
      server: 'https://sync.example.org/',
      listId: listId,
      secret: secret,
    );
    final text = link.toString();
    expect(
      text,
      'https://sync.example.org/l/$listId#AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8',
    );
    final back = ShareLink.tryParse(text)!;
    expect(back.server, 'https://sync.example.org');
    expect(back.listId, listId);
    expect(back.secret, secret);
    expect(back.pageUrl, 'https://sync.example.org/l/$listId');
  });

  test('Server mit Pfad und Port', () {
    final link = ShareLink(
      server: 'http://10.0.2.2:8080/joe',
      listId: listId,
      secret: secret,
    );
    final back = ShareLink.tryParse(link.toString())!;
    expect(back.server, 'http://10.0.2.2:8080/joe');
  });

  test('findet den Link mitten in einer Nachricht', () {
    final link = ShareLink(
      server: 'https://sync.example.org',
      listId: listId,
      secret: secret,
    );
    final back = ShareLink.tryParse(
      'Hier unsere Liste:\n$link\nCode kommt per SMS.',
    )!;
    expect(back.listId, listId);
    expect(back.secret, secret);
  });

  test('ohne Geheimnis, mit kaputtem oder zu langem Geheimnis: null', () {
    expect(ShareLink.tryParse('https://sync.example.org/l/$listId'), isNull);
    expect(
      ShareLink.tryParse('https://sync.example.org/l/$listId#abc'),
      isNull,
    );
    final zuLang = 'A' * 44;
    expect(
      ShareLink.tryParse('https://sync.example.org/l/$listId#$zuLang'),
      isNull,
    );
    expect(ShareLink.tryParse('Milch, Brot, Butter'), isNull);
  });
}
