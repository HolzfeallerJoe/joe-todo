import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:joe_sync/joe_sync.dart';

import 'log.dart';
import 'models.dart';
import 'reminders.dart';
import 'util.dart';

/// Die Hinweise vor dem Entteilen (Konzept 6.6), nur beim Ersteller (V13).
///
/// Zwei Stufen:
///
/// 1. **14 Tage vorher, rein lokal**: eine Benachrichtigung ueber
///    [JoeReminders] ([sharedExpiryReminders]), nach jedem Abgleich neu
///    gestellt. Sie braucht kein Netz.
/// 2. **Zum Ablauf, mit Nachfrage** (V14, Variante B): ein Android-
///    WorkManager-Auftrag fragt eine Stunde nach `expiresAt` einmal `meta`
///    mit dem Ersteller-Token. Ist die Liste wirklich abgelaufen, meldet er
///    es; hat sie jemand benutzt, plant er sich auf die neue Frist um. Die
///    Arbeit macht der Kotlin-Teil (SharedExpiryWorker) ganz ohne Dart, die
///    App reicht ihm nur Adresse, Token und Zeitpunkt.
///
/// Diese eine Anfrage ist die einzige Ausnahme von „Joe spricht nur bei
/// offener Liste“ (V4); `meta` verlaengert die Frist nicht.
class SharedExpiry {
  SharedExpiry({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('joe/shared_expiry');

  static final SharedExpiry instance = SharedExpiry();

  final MethodChannel _channel;

  /// Was zuletzt geplant wurde: Listen-ID → Zeitpunkt. Spart den Kanal bei
  /// jedem Abgleich alle 15 Sekunden.
  final Map<String, DateTime> _planned = {};

  /// Eine Stunde Luft nach der Frist: dann antwortet der Server sicher mit
  /// `410 expired`, statt dass die Nachfrage knapp davor landet.
  static const margin = Duration(hours: 1);

  /// Beim Start: fuer alle eigenen Listen neu planen.
  Future<void> refreshAll(AppState state) async {
    for (final list in state.shoppingLists) {
      await plan(list);
    }
  }

  Future<void> plan(ShoppingList list) async {
    final share = list.share;
    final expiresAt = share?.expiresAt;
    if (share == null || !share.isOwner || expiresAt == null) return;
    final runAt = expiresAt.add(margin);
    if (_planned[share.listId] == runAt) return;
    try {
      final token = await JoeCrypto.ownerToken(
        share.listId,
        unb64(share.ownerSecret!),
      );
      await _channel.invokeMethod<void>('schedule', {
        'key': share.listId,
        'title': list.name,
        'url': '${share.server}/api/lists/${share.listId}/meta',
        'token': token,
        'runAt': runAt.millisecondsSinceEpoch,
      });
      _planned[share.listId] = runAt;
      JoeLog.log('Entteilen-Hinweis geplant (${list.id}, '
          '${dateKey(runAt.toLocal())})');
    } on MissingPluginException {
      // Kein Android (Tests, Desktop): dann eben nur die lokale Stufe.
    } catch (e) {
      JoeLog.log('Entteilen-Hinweis nicht planbar: ${e.runtimeType}');
    }
  }

  Future<void> cancel(ShareState share) async {
    _planned.remove(share.listId);
    try {
      await _channel.invokeMethod<void>('cancel', {'key': share.listId});
    } on MissingPluginException {
      // Siehe oben.
    } catch (e) {
      JoeLog.log('Entteilen-Hinweis nicht abbestellbar: ${e.runtimeType}');
    }
  }

  @visibleForTesting
  Map<String, DateTime> get planned => _planned;
}

/// So lange vor `expiresAt` kommt die erste Warnung.
const sharedExpiryWarning = Duration(days: 14);

/// Die erste Stufe als [Reminder]s: je eigener geteilter Liste eine
/// Warnung 14 Tage vor der Frist, um 10 Uhr. Haengt nicht am Hauptschalter
/// fuer Erinnerungen – sie betrifft Daten, keine Termine.
List<Reminder> sharedExpiryReminders(
  List<ShoppingList> lists, {
  required DateTime from,
}) {
  final out = <Reminder>[];
  for (final list in lists) {
    final share = list.share;
    final expiresAt = share?.expiresAt;
    if (share == null || !share.isOwner || expiresAt == null) continue;
    final day = expiresAt.toLocal().subtract(sharedExpiryWarning);
    final when = DateTime(day.year, day.month, day.day, 10);
    if (!when.isAfter(from)) continue;
    out.add(
      Reminder(
        id: reminderNotificationId('geteilt:${share.listId}', 0),
        title: '„${list.name}“ wird bald nicht mehr geteilt',
        body: 'In 14 Tagen endet das Teilen. Öffne die Liste, damit sie '
            'geteilt bleibt.',
        when: when,
        payload: sharedListPayload(list.id),
        channel: ReminderChannel.sharedLists,
      ),
    );
  }
  return out;
}

/// `liste|<id>`: ein Antippen oeffnet diese Einkaufsliste.
String sharedListPayload(String listId) => 'liste|$listId';

/// Gegenstueck zu [sharedListPayload]; null fuer alles andere.
String? parseSharedListPayload(String? payload) {
  if (payload == null || !payload.startsWith('liste|')) return null;
  final id = payload.substring(6);
  return id.isEmpty ? null : id;
}
