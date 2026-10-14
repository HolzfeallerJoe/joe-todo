import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joe_sync/joe_sync.dart';

import 'package:joe_todo/models.dart';
import 'package:joe_todo/reminders.dart';
import 'package:joe_todo/shared_expiry.dart';

/// Die Hinweise vor dem Entteilen (Konzept 6.6): nur beim Ersteller, die
/// erste Stufe 14 Tage vorher lokal, die zweite als Nachfrage im
/// Hintergrund (Kotlin, hier nur der Kanal dorthin).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const listId = 'AAECAwQFBgcICQoLDA0ODw';
  final expires = DateTime.utc(2027, 10, 14, 8);

  ShoppingList list({bool owner = true, DateTime? expiresAt}) => ShoppingList(
        id: 'l1',
        name: 'Baumarkt',
        share: ShareState(
          server: 'https://sync.example.org',
          listId: listId,
          secret: b64(List.filled(32, 1)),
          ownerSecret: owner ? b64(List.filled(32, 2)) : null,
          expiresAt: expiresAt,
        ),
      );

  group('erste Stufe: 14 Tage vorher', () {
    test('beim Ersteller um 10 Uhr, mit eigenem Kanal und Ziel', () {
      final reminders = sharedExpiryReminders(
        [list(expiresAt: expires)],
        from: DateTime(2026, 10, 14),
      );
      final r = reminders.single;
      final day = expires.toLocal().subtract(const Duration(days: 14));
      expect(r.when, DateTime(day.year, day.month, day.day, 10));
      expect(r.title, contains('„Baumarkt“'));
      expect(r.body, contains('Öffne die Liste'));
      expect(r.channel, ReminderChannel.sharedLists);
      expect(parseSharedListPayload(r.payload), 'l1');
      expect(r.id, isNot(reminderNotificationId('l1', 0)));
    });

    test('nicht fuer Mitglieder, ohne Frist oder wenn sie vorbei ist', () {
      final from = DateTime(2026, 10, 14);
      expect(
        sharedExpiryReminders([list(owner: false, expiresAt: expires)],
            from: from),
        isEmpty,
      );
      expect(sharedExpiryReminders([list()], from: from), isEmpty);
      expect(
        sharedExpiryReminders([list(expiresAt: expires)],
            from: DateTime(2027, 10, 1)),
        isEmpty,
      );
      expect(sharedExpiryReminders([ShoppingList(id: 'x', name: 'Lokal')],
          from: from), isEmpty);
    });

    test('Payload: nur „liste|<id>“ wird erkannt', () {
      expect(parseSharedListPayload(sharedListPayload('l7')), 'l7');
      expect(parseSharedListPayload('liste|'), isNull);
      expect(parseSharedListPayload('aufgabe|1|2026-10-14'), isNull);
      expect(parseSharedListPayload(null), isNull);
      // Erinnerungen an Aufgaben lesen ihn nicht als ihren.
      expect(parseReminderPayload(sharedListPayload('l7')), isNull);
    });
  });

  group('zweite Stufe: Nachfrage im Hintergrund', () {
    const channel = MethodChannel('joe/shared_expiry');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('plant eine Stunde nach der Frist, mit Ersteller-Token', () async {
      final expiry = SharedExpiry();
      final shared = list(expiresAt: expires);
      await expiry.plan(shared);

      final args = (calls.single.arguments as Map).cast<String, Object?>();
      expect(calls.single.method, 'schedule');
      expect(args['key'], listId);
      expect(args['title'], 'Baumarkt');
      expect(args['url'],
          'https://sync.example.org/api/lists/$listId/meta');
      expect(
        args['token'],
        await JoeCrypto.ownerToken(listId, List.filled(32, 2)),
      );
      expect(args['runAt'],
          expires.add(const Duration(hours: 1)).millisecondsSinceEpoch);

      // Dieselbe Frist noch einmal: kein zweiter Aufruf.
      await expiry.plan(shared);
      expect(calls, hasLength(1));
      // Eine neue Frist plant um.
      shared.share!.expiresAt = expires.add(const Duration(days: 3));
      await expiry.plan(shared);
      expect(calls, hasLength(2));

      await expiry.cancel(shared.share!);
      expect(calls.last.method, 'cancel');
      expect(expiry.planned, isEmpty);
    });

    test('nichts fuer Mitglieder oder ohne Frist', () async {
      final expiry = SharedExpiry();
      await expiry.plan(list(owner: false, expiresAt: expires));
      await expiry.plan(list());
      expect(calls, isEmpty);
    });

    test('ohne Android-Teil geht es still weiter', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await SharedExpiry().plan(list(expiresAt: expires));
    });
  });
}
