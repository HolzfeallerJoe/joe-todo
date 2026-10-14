/// Was zwischen Geraet und Server hin- und hergeht (Konzept 5.2). Der
/// Server sieht nur diese Huelle, nie den Klartext.
library;

/// Grenzen aus G10. Der Server setzt sie durch, die Clients halten sich
/// daran, damit es gar nicht erst zum Fehler kommt.
class SyncLimits {
  SyncLimits._();

  /// Laengster Block (base64url-Zeichen), etwa 4 KB.
  static const maxBlob = 5600;

  /// Hoechstens so viele Operationen je Anfrage, hoch wie runter.
  static const maxOpsPerRequest = 500;
}

/// Eine Operation, wie der Server sie liefert: mit fortlaufender Nummer
/// und Serverzeit. Die Nummer allein legt die Reihenfolge fest (G14).
class WireOp {
  final int seq;
  final String id;
  final String blob;
  final DateTime at;

  const WireOp({
    required this.seq,
    required this.id,
    required this.blob,
    required this.at,
  });

  Map<String, Object?> toJson() => {
    'seq': seq,
    'id': id,
    'blob': blob,
    'at': at.toIso8601String(),
  };

  factory WireOp.fromJson(Map<String, Object?> json) => WireOp(
    seq: json['seq'] as int,
    id: json['id'] as String,
    blob: json['blob'] as String,
    at: DateTime.parse(json['at'] as String),
  );
}
