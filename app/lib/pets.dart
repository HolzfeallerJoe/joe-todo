/// Die Begleiter ("Deko-Tierchen"), die auf dem Dashboard sitzen.
///
/// Die WebP-Dateien unter assets/pets/ werden aus den PNG-Originalen mit
/// compress-pet-assets.ps1 im Repo-Wurzelverzeichnis erzeugt; die Originale
/// liegen bewusst nicht im Repo (~52 MB gegenueber 0,9 MB hier).
library;

class Pet {
  /// Stabiler Schluessel in den gespeicherten Einstellungen. Nicht aendern,
  /// sonst faellt eine bestehende Auswahl auf den Standard zurueck.
  final String id;
  final String name;
  final PetGroup group;

  const Pet(this.id, this.name, this.group);

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
  Pet('katze', 'Katze', PetGroup.aquarell),
  Pet('axolotl', 'Axolotl', PetGroup.aquarell),
  Pet('chamaeleon', 'Chamäleon', PetGroup.aquarell),
  Pet('delfin', 'Delfin', PetGroup.aquarell),
  Pet('fledermaus', 'Fledermaus', PetGroup.aquarell),
  Pet('fuchs', 'Fuchs', PetGroup.aquarell),
  Pet('hai', 'Hai', PetGroup.aquarell),
  Pet('krebs', 'Krebs', PetGroup.aquarell),
  Pet('lama', 'Lama', PetGroup.aquarell),
  Pet('narwal', 'Narwal', PetGroup.aquarell),
  Pet('nashorn', 'Nashorn', PetGroup.aquarell),
  Pet('otter', 'Otter', PetGroup.aquarell),
  Pet('pinguin', 'Pinguin', PetGroup.aquarell),
  Pet('qualle', 'Qualle', PetGroup.aquarell),
  Pet('sonne', 'Sonne', PetGroup.aquarell),

  // ---- Axos ----
  Pet('bubbletea-axo', 'Bubbletea-Axo', PetGroup.axos),
  Pet('buecher-axo', 'Bücher-Axo', PetGroup.axos),
  Pet('keks-axo', 'Keks-Axo', PetGroup.axos),
  Pet('dab-axo', 'Dab-Axo', PetGroup.axos),
  Pet('schlaf-axo', 'Schlaf-Axo', PetGroup.axos),
  Pet('gaming-axo', 'Gaming-Axo', PetGroup.axos),
  Pet('laptop-axo', 'Laptop-Axo', PetGroup.axos),
  Pet('yoga-axo', 'Yoga-Axo', PetGroup.axos),
  Pet('handy-axo', 'Handy-Axo', PetGroup.axos),
  Pet('pizza-axo', 'Pizza-Axo', PetGroup.axos),

  // ---- Dinos & Drachen ----
  Pet('drache', 'Drache', PetGroup.dinos),
  Pet('t-rex', 'T-Rex', PetGroup.dinos),
  Pet('triceratops', 'Triceratops', PetGroup.dinos),
  Pet('ankylosaurus', 'Ankylosaurus', PetGroup.dinos),
  Pet('brontosaurus', 'Brontosaurus', PetGroup.dinos),
  Pet('velociraptor', 'Velociraptor', PetGroup.dinos),
  Pet('flugsaurier', 'Flugsaurier', PetGroup.dinos),
  Pet('bubbletea-dino', 'Bubbletea-Dino', PetGroup.dinos),
  Pet('regenbogen-dino', 'Regenbogen-Dino', PetGroup.dinos),
  Pet('regenbogen-riese', 'Regenbogen-Riese', PetGroup.dinos),
  Pet('regenbogen-baby', 'Regenbogen-Baby', PetGroup.dinos),

  // ---- KalasStuff ----
  Pet('schaf', 'Schaf', PetGroup.kalasstuff),
  Pet('blumenschaf', 'Blumenschaf', PetGroup.kalasstuff),
  Pet('froehliches-schaf', 'Fröhliches Schaf', PetGroup.kalasstuff),
  Pet('kuh', 'Kuh', PetGroup.kalasstuff),
  Pet('einhorn', 'Einhorn', PetGroup.kalasstuff),
  Pet('leuchtturm', 'Leuchtturm', PetGroup.kalasstuff),

  // ---- Katzen ----
  Pet('blumenkatze', 'Blumenkatze', PetGroup.katzen),
  Pet('kekskatze', 'Kekskatze', PetGroup.katzen),
  Pet('grinsekatze', 'Grinsekatze', PetGroup.katzen),

  // ---- Obst ----
  Pet('banane', 'Banane', PetGroup.obst),
  Pet('drachenfrucht', 'Drachenfrucht', PetGroup.obst),
  Pet('kiwi', 'Kiwi', PetGroup.obst),
  Pet('litschi', 'Litschi', PetGroup.obst),
  Pet('orange', 'Orange', PetGroup.obst),
  Pet('zitrone', 'Zitrone', PetGroup.obst),

  // ---- Weihnachten ----
  Pet('santa-rudolf', 'Santa & Rudolf', PetGroup.weihnachten),
  Pet('schneemann', 'Schneemann', PetGroup.weihnachten),
];

/// Der Begleiter zu [id]; faellt auf den Standard zurueck, wenn ein
/// gespeicherter Schluessel nicht mehr existiert.
Pet petById(String id) => joePets.firstWhere(
      (p) => p.id == id,
      orElse: () => joePets.firstWhere((p) => p.id == defaultPetId),
    );
