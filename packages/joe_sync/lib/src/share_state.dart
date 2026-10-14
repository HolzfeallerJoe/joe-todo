import 'encoding.dart';
import 'link.dart';
import 'merge.dart';
import 'op.dart';

/// Alles, was ein Geraet zu einer geteilten Liste aufbewahrt (Konzept 6.1):
/// Zugang, bestaetigter Stand und die eigenen Aenderungen, die der Server
/// noch nicht zurueckgemeldet hat.
///
/// Sichtbar ist [view]: der bestaetigte Stand plus [outbox] obendrauf. So
/// sieht man eigene Aenderungen sofort, auch offline.
class ShareState {
  final String server;
  final String listId;

  /// Das Geheimnis aus dem Link (base64url). Wer es hat, kann lesen.
  final String secret;

  /// Der Code, falls die Liste einen verlangt (G4).
  final String? code;

  /// Ersteller-Geheimnis `O` (base64url); nur auf dem Geraet, das geteilt
  /// hat (Konzept 4.3).
  final String? ownerSecret;

  /// Hash des Ersteller-Tokens, wie der Server ihn kennt. Damit kann jedes
  /// Geraet die Liste nach einem Serververlust neu anlegen (Konzept 6.4),
  /// ohne dass der Ersteller seine Rechte verliert.
  String? ownerHash;

  /// Epoche der Liste auf dem Server; aendert sie sich, hat der Server die
  /// Liste verloren und neu angelegt.
  String? epoch;

  /// Letzte `seq`, die dieses Geraet gelesen hat.
  int lastSeq;

  /// Stand aus allen Operationen bis [lastSeq].
  SharedListState confirmed;

  /// Eigene Operationen, die noch nicht vom Server zurueckkamen, in der
  /// Reihenfolge ihres Entstehens.
  final List<Op> outbox;

  /// Davon schon hochgeladen (aber noch nicht wieder gelesen).
  final Set<String> acked;

  /// Ab dann wird die Liste ohne weiteren Zugriff entteilt (G9).
  DateTime? expiresAt;

  /// Letzter erfolgreicher Abgleich, Geraeteuhr.
  DateTime? lastSync;

  ShareState({
    required this.server,
    required this.listId,
    required this.secret,
    this.code,
    this.ownerSecret,
    this.ownerHash,
    this.epoch,
    this.lastSeq = 0,
    SharedListState? confirmed,
    List<Op>? outbox,
    Set<String>? acked,
    this.expiresAt,
    this.lastSync,
  }) : confirmed = confirmed ?? SharedListState(),
       outbox = outbox ?? [],
       acked = acked ?? {};

  ShareLink get link =>
      ShareLink(server: server, listId: listId, secret: unb64(secret));

  bool get isOwner => ownerSecret != null;

  bool get hasCode => code != null && code!.isNotEmpty;

  /// Noch nicht hochgeladene Aenderungen.
  int get unsent => outbox.where((op) => !acked.contains(op.id)).length;

  SharedListState? _view;

  /// Was man sieht: bestaetigt plus eigene Aenderungen.
  SharedListState get view {
    final cached = _view;
    if (cached != null) return cached;
    final view = confirmed.copy();
    for (final op in outbox) {
      view.apply(op);
    }
    return _view = view;
  }

  /// Nach jeder Aenderung an [confirmed] oder [outbox] aufrufen.
  void invalidate() => _view = null;

  /// Eine eigene Aenderung: sofort sichtbar, geht beim naechsten Abgleich
  /// hoch.
  void record(Op op) {
    outbox.add(op);
    // Statt neu zu rechnen: die Operation auf den gemerkten Stand legen.
    _view?.apply(op);
  }

  Map<String, Object?> toJson() => {
    'server': server,
    'listId': listId,
    'secret': secret,
    if (code != null) 'code': code,
    if (ownerSecret != null) 'ownerSecret': ownerSecret,
    if (ownerHash != null) 'ownerHash': ownerHash,
    if (epoch != null) 'epoch': epoch,
    'lastSeq': lastSeq,
    'confirmed': confirmed.toJson(),
    'outbox': [for (final op in outbox) op.toJson()],
    'acked': acked.toList(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    if (lastSync != null) 'lastSync': lastSync!.toIso8601String(),
  };

  factory ShareState.fromJson(Map<String, Object?> json) {
    DateTime? time(String key) =>
        json[key] == null ? null : DateTime.parse(json[key] as String);
    return ShareState(
      server: json['server'] as String,
      listId: json['listId'] as String,
      secret: json['secret'] as String,
      code: json['code'] as String?,
      ownerSecret: json['ownerSecret'] as String?,
      ownerHash: json['ownerHash'] as String?,
      epoch: json['epoch'] as String?,
      lastSeq: json['lastSeq'] as int? ?? 0,
      confirmed: SharedListState.fromJson(
        json['confirmed'] as Map<String, Object?>,
      ),
      outbox: [
        for (final raw in json['outbox'] as List? ?? const [])
          Op.fromJson((raw as Map).cast<String, Object?>()),
      ],
      acked: {
        for (final id in json['acked'] as List? ?? const []) id as String,
      },
      expiresAt: time('expiresAt'),
      lastSync: time('lastSync'),
    );
  }
}
