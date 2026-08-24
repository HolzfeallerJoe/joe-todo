import 'util.dart';

/// Das Befinden: eine Stimmung und beliebig viele Symptome mit ihrer
/// Staerke, zu einer Uhrzeit.
///
/// **Mehrere Eintraege je Notiz.** Wie es einem geht, ist keine Tagesnote:
/// morgens Kopfschmerzen und abends nicht mehr sind zwei Angaben, keine
/// widerspruechliche. Jeder Eintrag traegt deshalb seinen Zeitpunkt.
///
/// Eingetragen wird im Notiz-Editor, als Kategorie unter dem Text, und ein
/// Eintrag gehoert genau der Notiz, in der er entstanden ist: zwei Notizen
/// desselben Tages fuehren getrennte Listen. Damit geht ein Eintrag mit,
/// wenn seine Notiz geloescht wird – deshalb sagt die Loeschkarte einer
/// Notiz dazu, wie viele Eintraege daran haengen.

/// Wie es einem geht, von oben nach unten.
enum Mood {
  sehrGut('Sehr gut'),
  gut('Gut'),
  okay('Okay'),
  naja('Naja'),
  schlecht('Schlecht');

  final String label;
  const Mood(this.label);

  static Mood? fromJson(Object? value) {
    for (final m in Mood.values) {
      if (m.name == value) return m;
    }
    return null;
  }
}

/// Ein Symptom im Katalog.
///
/// Die zehn festen tragen einen festen Schluessel und stehen in
/// [fixedSymptoms]; eigene bekommen einen erzeugten Schluessel und liegen im
/// [AppState]. Ein Eintrag speichert nur den Schluessel, nie den Namen – so
/// bleibt ein umbenanntes Symptom dasselbe Symptom.
class Symptom {
  final String id;
  final String name;

  /// Selbst angelegt? Nur solche lassen sich umbenennen und loeschen.
  final bool custom;

  const Symptom(this.id, this.name, {this.custom = false});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Symptom.fromJson(Map<String, dynamic> json) => Symptom(
        json['id'] as String,
        json['name'] as String,
        custom: true,
      );
}

/// Die zehn vorgegebenen Symptome, in der Reihenfolge der Anforderung.
/// Die Schluessel sind ASCII und liegen fest: sie stehen so im Bestand.
const fixedSymptoms = <Symptom>[
  Symptom('kopfschmerzen', 'Kopfschmerzen'),
  Symptom('rueckenschmerzen', 'Rückenschmerzen'),
  Symptom('gelenkschmerzen', 'Gelenkschmerzen'),
  Symptom('koliken', 'Koliken'),
  Symptom('magenschmerzen', 'Magenschmerzen'),
  Symptom('bauchschmerzen', 'Bauchschmerzen'),
  Symptom('unterleibsschmerzen', 'Unterleibsschmerzen'),
  Symptom('kraempfe', 'Krämpfe'),
  Symptom('durchfall', 'Durchfall'),
  Symptom('uebelkeit', 'Übelkeit'),
];

/// Die Skala jedes Symptoms: fuenf Punkte.
const symptomScale = 5;

/// Wie stark, in Worten – fuer die Vorlesehilfe und die Zeile unter dem
/// Namen.
const symptomStrengthLabels = [
  'leicht',
  'mäßig',
  'deutlich',
  'stark',
  'sehr stark',
];

String symptomStrengthLabel(int value) =>
    symptomStrengthLabels[(value.clamp(1, symptomScale)) - 1];

/// Die Tageszeit eines Eintrags in Worten – damit sich eine Liste ueberfliegen
/// laesst, ohne Uhrzeiten zu vergleichen.
String dayPartLabel(DateTime at) => switch (at.hour) {
      >= 5 && < 11 => 'Morgens',
      >= 11 && < 14 => 'Mittags',
      >= 14 && < 17 => 'Nachmittags',
      >= 17 && < 22 => 'Abends',
      _ => 'Nachts',
    };

/// Ein Befinden zu einem Zeitpunkt.
class WellbeingEntry {
  final String id;

  /// Die Notiz, in der er eingetragen wurde. null heisst: aus der Fassung,
  /// in der die Eintraege noch am Tag hingen – siehe
  /// `AppState.adoptOrphanWellbeing`.
  String? noteId;

  /// Wann – Tag *und* Uhrzeit. Mehrere Eintraege einer Notiz unterscheiden
  /// sich genau hierin.
  DateTime at;

  /// Die Stimmung; null heisst: nicht angegeben.
  Mood? mood;

  /// Symptom-Schluessel auf Staerke 1..[symptomScale]. Was nicht drinsteht,
  /// war zu dem Zeitpunkt kein Thema – eine 0 wird gar nicht erst
  /// gespeichert.
  Map<String, int> symptoms;

  DateTime updatedAt;

  WellbeingEntry({
    required this.id,
    this.noteId,
    required this.at,
    this.mood,
    Map<String, int>? symptoms,
    required this.updatedAt,
  }) : symptoms = symptoms ?? {};

  /// Der Tag, an dem der Eintrag steht.
  DateTime get day => dateOnly(at);

  /// "Morgens", "Abends" – siehe [dayPartLabel].
  String get dayPart => dayPartLabel(at);

  /// Nichts angegeben – ein solcher Eintrag wird nicht aufbewahrt.
  bool get isEmpty => mood == null && symptoms.isEmpty;

  /// Die Staerke eines Symptoms, 0 heisst "nicht angegeben".
  int strengthOf(String symptomId) => symptoms[symptomId] ?? 0;

  /// Setzt die Staerke; 0 (oder ausserhalb der Skala) nimmt das Symptom
  /// wieder heraus.
  void setStrength(String symptomId, int value) {
    if (value < 1 || value > symptomScale) {
      symptoms.remove(symptomId);
    } else {
      symptoms[symptomId] = value;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'noteId': noteId,
        'at': at.toIso8601String(),
        'mood': mood?.name,
        'symptoms': symptoms,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WellbeingEntry.fromJson(Map<String, dynamic> json) {
    final raw = json['symptoms'];
    final symptoms = <String, int>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        // Alles, was keine Staerke auf der Skala ist, faellt weg – ein
        // kaputter Wert soll keine Zeile mit "Staerke 9" ergeben.
        if (key is String && value is int && value >= 1 && value <= symptomScale) {
          symptoms[key] = value;
        }
      });
    }
    // 'date' ist der Schluessel aus der ersten Fassung, als es noch einen
    // Eintrag je Tag ohne Uhrzeit gab. Solche Eintraege landen auf dem
    // Tagesbeginn, statt verlorenzugehen.
    final at = json['at'];
    return WellbeingEntry(
      id: json['id'] as String,
      noteId: json['noteId'] as String?,
      at: at is String
          ? DateTime.parse(at)
          : parseDateKey(json['date'] as String),
      mood: Mood.fromJson(json['mood']),
      symptoms: symptoms,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
