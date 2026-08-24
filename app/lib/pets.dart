/// Die Begleiter ("Deko-Tierchen"), die in der App sitzen.
///
/// Die WebP-Dateien unter assets/pets/ werden aus den PNG-Originalen mit
/// compress-pet-assets.ps1 im Repo-Wurzelverzeichnis erzeugt; die Originale
/// liegen bewusst nicht im Repo (~52 MB gegenueber 0,9 MB hier).
library;

import 'dart:math' as math;

class Pet {
  /// Stabiler Schluessel in den gespeicherten Einstellungen. Nicht aendern,
  /// sonst faellt eine bestehende Auswahl auf den Standard zurueck.
  final String id;
  final String name;
  final PetGroup group;

  /// Breite geteilt durch Hoehe der Bilddatei. Die Motive sind auf 320 px in
  /// der laengeren Kante normiert, sonst aber voellig verschieden geschnitten
  /// (Lama 130x320 hochkant, Hai 320x196 quer). In einer festen Box waere der
  /// Hai deshalb halb so gross wie das Lama – [petBox] rechnet mit diesem
  /// Wert jedem Motiv dieselbe gefuehlte Groesse aus.
  final double aspect;

  const Pet(this.id, this.name, this.group, this.aspect);

  String get asset => 'assets/pets/${group.folder}/$id.webp';
}

/// Die Gruppen entsprechen den Ordnern des Originalmaterials, in derselben
/// Reihenfolge. Nur die zwei Tippfehler ('Aqarell', 'Weichnachten') und der
/// Unterstrich sind fuer die Anzeige geradegerueckt.
enum PetGroup {
  aquarell('aquarell', 'Aquarell'),
  axos('axos', 'Axos'),
  dinos('dinos', 'Dinos & Drachen'),
  kalasstuff('kalasstuff', 'KalasStuff'),
  katzen('katzen', 'Katzen'),
  obst('obst', 'Obst'),
  weihnachten('weihnachten', 'Weihnachten');

  final String folder;
  final String label;
  const PetGroup(this.folder, this.label);
}

/// Alle Begleiter einer Gruppe, in der Reihenfolge von [joePets].
List<Pet> petsOf(PetGroup group) =>
    joePets.where((p) => p.group == group).toList(growable: false);

/// Der zuerst gezeigte Begleiter – die Aquarellkatze, weil die App vorher
/// ein Katzen-Emoji an dieser Stelle hatte.
const defaultPetId = 'katze';

const joePets = <Pet>[
  // ---- Aquarell ----
  Pet('katze', 'Katze', PetGroup.aquarell, 0.609),
  Pet('axolotl', 'Axolotl', PetGroup.aquarell, 1.194),
  Pet('chamaeleon', 'Chamäleon', PetGroup.aquarell, 0.741),
  Pet('delfin', 'Delfin', PetGroup.aquarell, 0.653),
  Pet('fledermaus', 'Fledermaus', PetGroup.aquarell, 1.461),
  Pet('fuchs', 'Fuchs', PetGroup.aquarell, 0.769),
  Pet('hai', 'Hai', PetGroup.aquarell, 1.633),
  Pet('krebs', 'Krebs', PetGroup.aquarell, 1.275),
  Pet('lama', 'Lama', PetGroup.aquarell, 0.406),
  Pet('narwal', 'Narwal', PetGroup.aquarell, 0.828),
  Pet('nashorn', 'Nashorn', PetGroup.aquarell, 0.681),
  Pet('otter', 'Otter', PetGroup.aquarell, 0.728),
  Pet('pinguin', 'Pinguin', PetGroup.aquarell, 0.831),
  Pet('qualle', 'Qualle', PetGroup.aquarell, 0.678),
  Pet('sonne', 'Sonne', PetGroup.aquarell, 1.0),

  // ---- Axos ----
  Pet('bubbletea-axo', 'Bubbletea-Axo', PetGroup.axos, 1.212),
  Pet('buecher-axo', 'Bücher-Axo', PetGroup.axos, 0.997),
  Pet('keks-axo', 'Keks-Axo', PetGroup.axos, 1.06),
  Pet('dab-axo', 'Dab-Axo', PetGroup.axos, 1.003),
  Pet('schlaf-axo', 'Schlaf-Axo', PetGroup.axos, 1.27),
  Pet('gaming-axo', 'Gaming-Axo', PetGroup.axos, 0.9),
  Pet('laptop-axo', 'Laptop-Axo', PetGroup.axos, 1.265),
  Pet('yoga-axo', 'Yoga-Axo', PetGroup.axos, 1.139),
  Pet('handy-axo', 'Handy-Axo', PetGroup.axos, 1.0),
  Pet('pizza-axo', 'Pizza-Axo', PetGroup.axos, 1.046),

  // ---- Dinos & Drachen ----
  Pet('drache', 'Drache', PetGroup.dinos, 1.016),
  Pet('t-rex', 'T-Rex', PetGroup.dinos, 1.006),
  Pet('triceratops', 'Triceratops', PetGroup.dinos, 1.275),
  Pet('ankylosaurus', 'Ankylosaurus', PetGroup.dinos, 1.328),
  Pet('brontosaurus', 'Brontosaurus', PetGroup.dinos, 0.909),
  Pet('velociraptor', 'Velociraptor', PetGroup.dinos, 1.092),
  Pet('flugsaurier', 'Flugsaurier', PetGroup.dinos, 1.561),
  Pet('bubbletea-dino', 'Bubbletea-Dino', PetGroup.dinos, 0.8),
  Pet('regenbogen-dino', 'Regenbogen-Dino', PetGroup.dinos, 0.912),
  Pet('regenbogen-riese', 'Regenbogen-Riese', PetGroup.dinos, 1.1),
  Pet('regenbogen-baby', 'Regenbogen-Baby', PetGroup.dinos, 1.081),

  // ---- KalasStuff ----
  Pet('schaf', 'Schaf', PetGroup.kalasstuff, 0.916),
  Pet('blumenschaf', 'Blumenschaf', PetGroup.kalasstuff, 0.953),
  Pet('froehliches-schaf', 'Fröhliches Schaf', PetGroup.kalasstuff, 0.844),
  Pet('kuh', 'Kuh', PetGroup.kalasstuff, 0.941),
  Pet('einhorn', 'Einhorn', PetGroup.kalasstuff, 0.909),
  Pet('leuchtturm', 'Leuchtturm', PetGroup.kalasstuff, 0.869),

  // ---- Katzen ----
  Pet('blumenkatze', 'Blumenkatze', PetGroup.katzen, 0.988),
  Pet('kekskatze', 'Kekskatze', PetGroup.katzen, 0.766),
  Pet('grinsekatze', 'Grinsekatze', PetGroup.katzen, 0.694),

  // ---- Obst ----
  Pet('banane', 'Banane', PetGroup.obst, 0.7),
  Pet('drachenfrucht', 'Drachenfrucht', PetGroup.obst, 0.984),
  Pet('kiwi', 'Kiwi', PetGroup.obst, 1.147),
  Pet('litschi', 'Litschi', PetGroup.obst, 0.922),
  Pet('orange', 'Orange', PetGroup.obst, 0.947),
  Pet('zitrone', 'Zitrone', PetGroup.obst, 0.903),

  // ---- Weihnachten ----
  Pet('santa-rudolf', 'Santa & Rudolf', PetGroup.weihnachten, 1.032),
  Pet('schneemann', 'Schneemann', PetGroup.weihnachten, 0.878),
];

/// Der Begleiter zu [id]; faellt auf den Standard zurueck, wenn ein
/// gespeicherter Schluessel nicht mehr existiert.
Pet petById(String id) => joePets.firstWhere(
      (p) => p.id == id,
      orElse: () => joePets.firstWhere((p) => p.id == defaultPetId),
    );

/// Wo der Begleiter auf einer Seite sitzen kann.
///
/// Alle Plaetze lehnen sich an etwas an, das auch wirklich da ist: die drei
/// oberen setzen das Tierchen auf die Oberkante des Inhalts – also auf die
/// erste Karte der Seite –, [besideFab] neben den Plus-Knopf, die beiden
/// unteren auf die Kante ueber der Navigationsleiste. Welche davon eine
/// Seite anbietet, steht in [PetPage]: auf einer kurzen Seite waere unten
/// nur Hintergrund, und dort soll niemand sitzen.
enum PetSpot {
  contentTopLeft,
  contentTopCenter,
  contentTopRight,
  bottomLeft,
  bottomCenter,
  besideFab;

  /// Oben auf der Inhaltskante oder unten am Rand – danach richtet sich die
  /// ganze Geometrie.
  bool get isTop => index < 3;

  /// -1 links, 0 mittig, 1 rechts.
  int get side => switch (this) {
        contentTopLeft || bottomLeft => -1,
        contentTopCenter || bottomCenter => 0,
        contentTopRight || besideFab => 1,
      };
}

/// Die Seiten der App – und die Plaetze, die jede fuer den Begleiter
/// anbietet.
///
/// Hier steht die eigentliche Entscheidung: nicht *irgendwo* auf dem Bild,
/// sondern an einer Stelle, an der auf dieser Seite etwas ist. Eine Seite
/// ohne Plus-Knopf bietet [PetSpot.besideFab] nicht an, eine kurze Seite
/// keinen unteren Platz, und die Mitte oben nur dort, wo oben keine Zahl
/// und keine Ueberschrift steht, die verdeckt wuerde.
enum PetPage {
  /// Erste Seite: die Heute-Karte oben, die Ordner-Reiter bis unten, das
  /// Plus unten rechts – hier ist ueberall etwas.
  dashboard([
    PetSpot.contentTopRight,
    PetSpot.contentTopLeft,
    PetSpot.bottomLeft,
    PetSpot.besideFab,
  ]),
  tasks([
    PetSpot.contentTopRight,
    PetSpot.contentTopLeft,
    PetSpot.besideFab,
  ]),
  appointments([
    PetSpot.contentTopRight,
    PetSpot.contentTopLeft,
    PetSpot.besideFab,
  ]),

  /// Der Kalender hat kein Plus, dafuer reicht die Tageskarte bis unten.
  calendar([
    PetSpot.contentTopRight,
    PetSpot.contentTopLeft,
    PetSpot.bottomLeft,
    PetSpot.bottomCenter,
  ]),
  notes([
    PetSpot.contentTopRight,
    PetSpot.contentTopLeft,
    PetSpot.besideFab,
  ]),

  /// Im Notiz-Editor fuellt eine einzige Karte die Seite; unten sitzt der
  /// Befinden-Abschnitt, davor bleibt das Tierchen weg.
  noteEdit([PetSpot.contentTopRight, PetSpot.contentTopLeft]),

  /// Der Befinden-Editor faengt mit Datum und Uhrzeit an – das Tierchen
  /// sitzt hier hoeher, damit beides lesbar bleibt.
  wellbeingEdit(
    [PetSpot.contentTopRight, PetSpot.contentTopLeft],
    topOverlap: 0.08,
  ),

  /// Listen ohne Kopfzahl: hier stoert auch die Mitte oben nicht.
  history([
    PetSpot.contentTopRight,
    PetSpot.contentTopLeft,
    PetSpot.contentTopCenter,
  ]),
  settings([
    PetSpot.contentTopRight,
    PetSpot.contentTopLeft,
    PetSpot.bottomLeft,
  ]);

  final List<PetSpot> spots;

  /// Wie tief das Tierchen oben in diese Seite hineinragen darf, als Anteil
  /// seiner Hoehe – gedeckelt durch [_maxTopOverlap].
  ///
  /// Der Regelfall streift die Kartenkante ([_defaultTopOverlap]). Wo die
  /// erste Karte gleich in der ersten Zeile etwas zu sagen hat – Datum und
  /// Uhrzeit im Befinden-Editor –, sitzt es hoeher und laesst sie ganz frei.
  final double topOverlap;

  const PetPage(this.spots, {this.topOverlap = _defaultTopOverlap});
}

const _defaultTopOverlap = 0.2;

/// Die Bildgroesse eines Begleiters an einem Platz.
///
/// Gemessen wird ueber das geometrische Mittel: `sqrt(Breite * Hoehe)` ist
/// fuer jedes Motiv gleich ([_gaugeTop] bzw. [_gaugeBottom]). Waere
/// stattdessen die Hoehe gleich, wuerde der quer liegende Hai so breit wie
/// ein halber Bildschirm; waere die Breite gleich, verschwaende das Lama zu
/// einem Strich. Ueber das Mittel wirken alle 53 gleich gross.
///
/// Die beiden Deckel begrenzen danach die Extreme: das Lama darf oben nicht
/// bis in die Statusleiste wachsen, der Hai nicht ueber den halben Bildschirm.
({double width, double height}) petBox(Pet pet, PetSpot spot) {
  final gauge = spot.isTop ? _gaugeTop : _gaugeBottom;
  final maxHeight = spot.isTop ? _maxHeightTop : _maxHeightBottom;
  final maxWidth = spot.isTop ? _maxWidthTop : _maxWidthBottom;

  final root = math.sqrt(pet.aspect);
  var width = gauge * root;
  var height = gauge / root;
  final shrink = math.min(
    math.min(1.0, maxHeight / height),
    maxWidth / width,
  );
  return (width: width * shrink, height: height * shrink);
}

/// Wie tief ein Begleiter in die Seite hineinragt; der Rest darueber ist der
/// Platz, den die Seite fuer ihn freihaelt.
///
/// Oben ist das bewusst wenig – ein schmaler Streifen, gedeckelt durch
/// [_maxTopOverlap]. Das Tierchen soll auf der Kante der ersten Karte
/// sitzen, nicht auf ihrer ersten Zeile: ein Titel, der halb hinter einem
/// Dino steht, ist die Karte nicht wert. Wie viel genau, sagt die Seite
/// ([PetPage.topOverlap]).
///
/// Unten sitzt es auf der Kante ueber der Navigationsleiste; dort steht
/// selten Text, also darf es tiefer.
double petOverlap(Pet pet, PetSpot spot, PetPage page) {
  final height = petBox(pet, spot).height;
  if (!spot.isTop) return height * 0.5;
  return math.min(height * page.topOverlap, _maxTopOverlap);
}

/// Mehr als das darf oben nie ueberlappen. Die Karten der App haben
/// 12 Punkt Innenabstand: genau bis dorthin, dann steht das Tierchen auf
/// der Kante und die erste Zeile bleibt frei.
const _maxTopOverlap = 12.0;

const _gaugeTop = 78.0;
const _maxHeightTop = 96.0;
const _maxWidthTop = 124.0;

const _gaugeBottom = 94.0;
const _maxHeightBottom = 132.0;
const _maxWidthBottom = 168.0;

/// Wo der Begleiter in dieser Sitzung sitzt.
///
/// Gewuerfelt wird **einmal beim App-Start**, und zwar nur eine Zahl: der
/// Startwert. Aus ihm faellt fuer jede Seite ein Platz – auf dem Dashboard
/// ein anderer als in den Notizen, aber auf jeder Seite immer derselbe,
/// solange die App laeuft. So entdeckt man das Tierchen beim Blaettern
/// ueberall neu, ohne dass es beim Hin- und Herwechseln zwischen zwei
/// Seiten herumspringt.
///
/// Ohne Wurf gilt Startwert 0: Tests und Bildschirmfotos sollen nicht vom
/// Zufall abhaengen.
class PetPlacement {
  PetPlacement._();

  static int _seed = 0;

  static int get seed => _seed;

  /// Einmal beim App-Start. Gibt den Startwert zurueck, damit er ins Log
  /// kann – ohne ihn liesse sich ein Bildschirmfoto nicht nachstellen.
  static int roll([math.Random? random]) =>
      _seed = (random ?? math.Random()).nextInt(1 << 32);

  /// Einen Startwert setzen – fuer Tests und um einen gemeldeten Stand
  /// nachzustellen.
  static void use(int seed) => _seed = seed;

  /// Zurueck auf den vorhersehbaren Startwert.
  static void reset() => _seed = 0;

  /// Der Platz auf [page]. Derselbe Startwert und dieselbe Seite ergeben
  /// immer denselben Platz.
  static PetSpot spotOn(PetPage page) {
    final choices = page.spots;
    // Der Seitenindex geht mit einer Primzahl in den Startwert ein, damit
    // benachbarte Seiten nicht reihum dieselbe Wahl treffen.
    final random = math.Random(_seed + page.index * 7919);
    return choices[random.nextInt(choices.length)];
  }
}
