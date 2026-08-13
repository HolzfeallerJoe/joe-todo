import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:joe_todo/log.dart';
// Der Test laeuft auf der VM, darf das io-Backend also direkt anfassen.
import 'package:joe_todo/log_sink_io.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('joe_log_test');
    LogSink.resolveDirectory = () async => dir;
    LogSink.maxBytes = 256 * 1024;
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('Zeilen landen mit Zeitstempel in der Datei', () async {
    final log = JoeLog.forTest();
    log.add('erste Zeile');
    log.add('zweite Zeile');
    await log.flushed;

    final content = File('${dir.path}/joe.log').readAsStringSync();
    final lines = content.trim().split('\n');
    expect(lines, hasLength(2));
    expect(lines[0], endsWith('erste Zeile'));
    expect(lines[1], endsWith('zweite Zeile'));
    // ISO-Zeitstempel am Zeilenanfang
    expect(DateTime.tryParse(lines[0].split(' ').first), isNotNull);
  });

  test('Rotation: joe.log rueckt zu joe.log.1, beide werden geteilt',
      () async {
    LogSink.maxBytes = 80;
    final log = JoeLog.forTest();
    log.add('x' * 100); // ueber der Grenze -> rotiert
    log.add('danach');
    await log.flushed;

    expect(File('${dir.path}/joe.log.1').existsSync(), isTrue);
    expect(File('${dir.path}/joe.log').readAsStringSync(),
        contains('danach'));

    final payload = await log.sharePayload();
    expect(payload.paths, hasLength(2));
    expect(payload.paths.first, endsWith('joe.log.1'));
    expect(payload.paths.last, endsWith('joe.log'));
  });

  test('ohne Dateisystem traegt der Speicherpuffer', () async {
    LogSink.resolveDirectory =
        () async => throw StateError('kein Dateisystem');
    final log = JoeLog.forTest();
    log.add('nur im Speicher');
    await log.flushed; // darf nicht werfen

    final payload = await log.sharePayload();
    expect(payload.paths, isEmpty);
    expect(payload.text, contains('nur im Speicher'));
  });
}
