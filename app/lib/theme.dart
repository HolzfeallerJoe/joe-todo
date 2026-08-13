import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum TextureStyle { paper, wood, fabric, watercolor }

class JoeTheme {
  final String name;
  final TextureStyle? texture;

  /// When set, this photo is painted as the app background instead of the
  /// procedural [TexturePainter] texture.
  final String? backgroundAsset;
  final Color bgTop;
  final Color bgBottom;
  final Color paper;
  final Color ink;
  final Color inkSoft;
  final Color accent;
  final List<Color> tabColors;

  /// Color for text/icons drawn straight onto the background (section titles,
  /// app bar). Photo backgrounds are often too dark or too busy for [ink],
  /// so they override this. Defaults to [ink].
  final Color? onBackground;

  const JoeTheme({
    required this.name,
    this.texture,
    this.backgroundAsset,
    required this.bgTop,
    required this.bgBottom,
    required this.paper,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.tabColors,
    this.onBackground,
  });

  Color get onBg => onBackground ?? ink;

  /// Wie Android Status- und Navigationsleiste ueber der App zeichnen soll.
  ///
  /// Die App laeuft randlos, der Hintergrund liegt also schon hinter beiden
  /// Leisten. Ohne diese Angabe legt das System unten einen schwarzen
  /// Kontrastbalken darueber – ein schwarzer Klotz unter einem warmen
  /// Notizbuch. Beides transparent, und die Symbole richten sich nach dem
  /// Hintergrund: Wo [onBg] hell ist, ist der Hintergrund dunkel, dort
  /// brauchen auch die Systemsymbole die helle Fassung.
  SystemUiOverlayStyle get systemOverlayStyle {
    final darkBackground = onBg.computeLuminance() > 0.5;
    final icons = darkBackground ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: icons,
      // iOS dreht die Bedeutung um: hier ist die Helligkeit der Leiste selbst
      // gemeint, nicht die der Symbole.
      statusBarBrightness: darkBackground ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: icons,
      // Das schaltet den Kontrastbalken ab.
      systemNavigationBarContrastEnforced: false,
    );
  }

  /// Contrasting halo behind on-background text. Photos swing from very light
  /// to very dark within one image (on Maritim/Ozean/Regenbogen a flat text
  /// color is under 3:1 on 25-42% of pixels), so the text carries its own
  /// backdrop: a tight opaque ring for local contrast plus a wider soft glow
  /// to lift it off busy detail. Procedural textures are flat enough to skip.
  List<Shadow> get onBgShadows {
    if (backgroundAsset == null) return const [];
    final halo = onBg.computeLuminance() > 0.5
        ? const Color(0xF2000000)
        : const Color(0xF2FFFFFF);
    return [
      Shadow(color: halo, blurRadius: 3),
      Shadow(color: halo, blurRadius: 9),
    ];
  }

  /// Whichever of white or [ink] actually contrasts more against [bg].
  /// Beats a fixed luminance threshold, which misjudges mid-tone fills.
  /// If the darker option wins but still misses the 3:1 non-text bar (a
  /// mid-olive ink on amber, say), it is deepened until it clears.
  Color bestOn(Color bg) {
    if (contrastRatio(Colors.white, bg) >= contrastRatio(ink, bg)) {
      return Colors.white;
    }
    var c = ink;
    for (var i = 0; i < 10 && contrastRatio(c, bg) < 3.0; i++) {
      c = Color.lerp(c, Colors.black, 0.2)!;
    }
    return c;
  }

  /// Readable label color for a folder tab painted in [tabColor].
  Color onTab(Color tabColor) {
    if (backgroundAsset == null) return ink; // keep the original look
    return bestOn(tabColor);
  }
}

/// WCAG 2.1 contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

const joeThemes = [
  JoeTheme(
    name: 'Holz',
    texture: TextureStyle.wood,
    bgTop: Color(0xFFE3C08F),
    bgBottom: Color(0xFFC2925C),
    paper: Color(0xFFFAF3E3),
    ink: Color(0xFF4A3527),
    inkSoft: Color(0xFF7E6A59),
    accent: Color(0xFFB35037),
    // Section titles can sit over the darker foot of the wood gradient, where
    // plain ink only reaches 4.13:1.
    onBackground: Color(0xFF412E22),
    tabColors: [
      Color(0xFFE4A54F),
      Color(0xFF82C0AE),
      Color(0xFFB9C29B),
      Color(0xFFC79A63),
      Color(0xFFC96480),
      Color(0xFF9AAFC9),
    ],
  ),
  JoeTheme(
    name: 'Papier',
    texture: TextureStyle.paper,
    bgTop: Color(0xFFF6EFDC),
    bgBottom: Color(0xFFEADFC4),
    paper: Color(0xFFFFFDF6),
    ink: Color(0xFF453A2E),
    inkSoft: Color(0xFF7D7264),
    accent: Color(0xFFB25438),
    tabColors: [
      Color(0xFFE8B45C),
      Color(0xFF8FC5B4),
      Color(0xFFC3CBA4),
      Color(0xFFD3A878),
      Color(0xFFD2788F),
      Color(0xFFA9BFD8),
    ],
  ),
  JoeTheme(
    name: 'Stoff',
    texture: TextureStyle.fabric,
    bgTop: Color(0xFFE5D5C0),
    bgBottom: Color(0xFFD3BC9F),
    paper: Color(0xFFFBF6EA),
    ink: Color(0xFF4C3D2E),
    inkSoft: Color(0xFF7C6D5B),
    accent: Color(0xFFA8563E),
    tabColors: [
      Color(0xFFDFA75B),
      Color(0xFF8BBBA8),
      Color(0xFFB5BE97),
      Color(0xFFC49B6F),
      Color(0xFFC57287),
      Color(0xFF9FB4CC),
    ],
  ),
  JoeTheme(
    name: 'Aquarell',
    texture: TextureStyle.watercolor,
    bgTop: Color(0xFFFDF7EB),
    bgBottom: Color(0xFFF3E7D3),
    paper: Color(0xFFFFFEFA),
    ink: Color(0xFF50443A),
    inkSoft: Color(0xFF7D7266),
    accent: Color(0xFFB25B4A),
    tabColors: [
      Color(0xFFEDBB6B),
      Color(0xFF9CCBBB),
      Color(0xFFC9D2AC),
      Color(0xFFDCB183),
      Color(0xFFDD8BA0),
      Color(0xFFAFC8E0),
    ],
  ),

  // ---- Photo backgrounds ----
  JoeTheme(
    name: 'Holzmaser',
    backgroundAsset: 'assets/themes/compressed/holz.jpg',
    bgTop: Color(0xFFD19D6D),
    bgBottom: Color(0xFFA66A42),
    paper: Color(0xFFFBF3E7),
    ink: Color(0xFF4A2E14),
    inkSoft: Color(0xFF7E6A58),
    accent: Color(0xFF97603C),
    tabColors: [
      Color(0xFFD19D6D),
      Color(0xFF7B4316),
      Color(0xFFC8B28A),
      Color(0xFFA66A42),
      Color(0xFF4F6B4A),
      Color(0xFF3F5147),
    ],
  ),
  JoeTheme(
    name: 'Eisig',
    backgroundAsset: 'assets/themes/compressed/eisig.jpg',
    bgTop: Color(0xFFCCE2EF),
    bgBottom: Color(0xFF2A5D94),
    paper: Color(0xFFF3F9FD),
    ink: Color(0xFF1F3A54),
    inkSoft: Color(0xFF477596),
    accent: Color(0xFF2A5D94),
    tabColors: [
      Color(0xFF9FBAD5),
      Color(0xFF75A0C0),
      Color(0xFF548AB0),
      Color(0xFF3E759C),
      Color(0xFF2A5D94),
      Color(0xFF1E4570),
    ],
  ),
  JoeTheme(
    name: 'Halloween',
    backgroundAsset: 'assets/themes/compressed/halloween.jpg',
    bgTop: Color(0xFFD2D1D9),
    bgBottom: Color(0xFF6A7175),
    paper: Color(0xFFF1EEF7),
    ink: Color(0xFF34263F),
    inkSoft: Color(0xFF666C70),
    accent: Color(0xFF9F1BCF),
    onBackground: Color(0xFFF3EEF8),
    tabColors: [
      Color(0xFF6A7175),
      Color(0xFF9F1BCF),
      Color(0xFF7C4394),
      Color(0xFF448740),
      Color(0xFF5FC546),
      Color(0xFFE8862B),
    ],
  ),
  JoeTheme(
    name: 'Maritim',
    backgroundAsset: 'assets/themes/compressed/maritim.jpg',
    bgTop: Color(0xFF2F6FAF),
    bgBottom: Color(0xFF1FA38B),
    paper: Color(0xFFEAF7F5),
    ink: Color(0xFF12495F),
    inkSoft: Color(0xFF3C767F),
    accent: Color(0xFF007B7B),
    onBackground: Color(0xFFFFFFFF),
    tabColors: [
      Color(0xFF2F6FAF),
      Color(0xFF248FC9),
      Color(0xFF00A8A8),
      Color(0xFF1FA38B),
      Color(0xFFD4BA82),
      Color(0xFF1B4F7A),
    ],
  ),
  JoeTheme(
    name: 'Ozean',
    backgroundAsset: 'assets/themes/compressed/ozean.jpg',
    bgTop: Color(0xFF74BEC7),
    bgBottom: Color(0xFF0B888C),
    paper: Color(0xFFEAF6F1),
    ink: Color(0xFF0A4F52),
    inkSoft: Color(0xFF477479),
    accent: Color(0xFF0A7A7E),
    onBackground: Color(0xFFFFFFFF),
    tabColors: [
      Color(0xFF0B888C),
      Color(0xFF74BEC7),
      Color(0xFF00A8A8),
      Color(0xFFD4BA82),
      Color(0xFFB8954A),
      Color(0xFF0A5F62),
    ],
  ),
  JoeTheme(
    name: 'Pfoten',
    backgroundAsset: 'assets/themes/compressed/pfoten.jpg',
    bgTop: Color(0xFFF5EEE7),
    bgBottom: Color(0xFF8C7863),
    paper: Color(0xFFFAF5EF),
    ink: Color(0xFF4A3B2C),
    inkSoft: Color(0xFF7C6D5C),
    accent: Color(0xFF7E6C59),
    tabColors: [
      Color(0xFFE8DDD3),
      Color(0xFFD1C0AE),
      Color(0xFFBAA691),
      Color(0xFFA38F79),
      Color(0xFF8C7863),
      Color(0xFF6E5A48),
    ],
  ),
  JoeTheme(
    name: 'Rainbow',
    backgroundAsset: 'assets/themes/compressed/rainbow.jpg',
    bgTop: Color(0xFFFAD1CD),
    bgBottom: Color(0xFFC3DEF7),
    paper: Color(0xFFFDFAF8),
    ink: Color(0xFF5B4A63),
    inkSoft: Color(0xFF7B6D83),
    accent: Color(0xFFA35C7C),
    tabColors: [
      Color(0xFFFAD1CD),
      Color(0xFFFAE0BE),
      Color(0xFFFAF1B6),
      Color(0xFFD3FAC8),
      Color(0xFFC3DEF7),
      Color(0xFFE6D2F7),
    ],
  ),
  JoeTheme(
    name: 'Regenbogen',
    backgroundAsset: 'assets/themes/compressed/regenbogen.jpg',
    bgTop: Color(0xFF1078D9),
    bgBottom: Color(0xFFAB10B2),
    paper: Color(0xFFFFFCF5),
    ink: Color(0xFF332A22),
    inkSoft: Color(0xFF6B5F55),
    accent: Color(0xFFA06405),
    onBackground: Color(0xFFFFFFFF),
    tabColors: [
      Color(0xFFAB10B2),
      Color(0xFF1078D9),
      Color(0xFF15C04D),
      Color(0xFFF6DA17),
      Color(0xFFEC0D10),
      Color(0xFFF57C00),
    ],
  ),
  JoeTheme(
    name: 'Weihnachten',
    backgroundAsset: 'assets/themes/compressed/weihnachten.jpg',
    bgTop: Color(0xFFEED8A7),
    bgBottom: Color(0xFF335A2E),
    paper: Color(0xFFF7F0DE),
    ink: Color(0xFF2C4326),
    inkSoft: Color(0xFF7C6A3E),
    accent: Color(0xFFA6131D),
    onBackground: Color(0xFFF6E9C9),
    tabColors: [
      Color(0xFFEED8A7),
      Color(0xFFC8252A),
      Color(0xFFC7A46C),
      Color(0xFF335A2E),
      Color(0xFF476E3F),
      Color(0xFF7C9BB5),
    ],
  ),
  JoeTheme(
    name: 'Zitronen',
    backgroundAsset: 'assets/themes/compressed/zitronen.jpg',
    bgTop: Color(0xFFF8E8C8),
    bgBottom: Color(0xFF549034),
    paper: Color(0xFFFBF8ED),
    ink: Color(0xFF4C5A1E),
    inkSoft: Color(0xFF557A2C),
    accent: Color(0xFF497D2D),
    tabColors: [
      Color(0xFFFCF09F),
      Color(0xFFEFCA31),
      Color(0xFF9FBE43),
      Color(0xFF6D9C37), // nudged darker so the white label clears 3:1
      Color(0xFF549034),
      Color(0xFF3E7226),
    ],
  ),
  JoeTheme(
    name: 'Kaffee',
    backgroundAsset: 'assets/themes/compressed/kaffee.jpg',
    bgTop: Color(0xFFA9724A),
    bgBottom: Color(0xFF3B2415),
    paper: Color(0xFFF6EDE1),
    ink: Color(0xFF3B2415),
    inkSoft: Color(0xFF83654A),
    accent: Color(0xFF9C5A2E),
    onBackground: Color(0xFFF3E4D2),
    tabColors: [
      Color(0xFFE3C9A3),
      Color(0xFFC9A46B),
      Color(0xFFA9724A),
      Color(0xFF8A6A4E),
      Color(0xFF6B4226),
      Color(0xFF3B2415),
    ],
  ),
];

/// Paints the notebook-style background texture for the current theme.
/// Deterministic (seeded) so it doesn't shimmer on rebuilds.
class TexturePainter extends CustomPainter {
  final JoeTheme theme;
  TexturePainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.bgTop, theme.bgBottom],
        ).createShader(rect),
    );
    final rng = Random(7);
    switch (theme.texture) {
      case null:
        break;
      case TextureStyle.wood:
        final dark = Paint()..color = const Color(0x14513A1F);
        final light = Paint()..color = const Color(0x1AFFF3D6);
        double x = 0;
        while (x < size.width) {
          final w = 22.0 + rng.nextDouble() * 46;
          canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height),
              rng.nextBool() ? dark : light);
          x += w + rng.nextDouble() * 14;
        }
        final seam = Paint()
          ..color = const Color(0x22513A1F)
          ..strokeWidth = 1.4;
        for (double sx = 60 + rng.nextDouble() * 40;
            sx < size.width;
            sx += 90 + rng.nextDouble() * 70) {
          canvas.drawLine(Offset(sx, 0), Offset(sx + 6, size.height), seam);
        }
      case TextureStyle.paper:
        final line = Paint()
          ..color = const Color(0x0F6B5A3E)
          ..strokeWidth = 1;
        for (double y = 28; y < size.height; y += 28) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
        final fleck = Paint()..color = const Color(0x0D6B5A3E);
        for (int i = 0; i < 140; i++) {
          canvas.drawCircle(
            Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
            0.6 + rng.nextDouble() * 1.1,
            fleck,
          );
        }
      case TextureStyle.fabric:
        final thread = Paint()
          ..color = const Color(0x0D5C4630)
          ..strokeWidth = 1;
        for (double y = 0; y < size.height; y += 7) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), thread);
        }
        for (double x = 0; x < size.width; x += 7) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), thread);
        }
      case TextureStyle.watercolor:
        const washes = [
          Color(0x14E8A06B),
          Color(0x128FBFA8),
          Color(0x12D98BA0),
          Color(0x10C9D2AC),
        ];
        for (int i = 0; i < 10; i++) {
          final paint = Paint()
            ..color = washes[i % washes.length]
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
          canvas.drawCircle(
            Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
            60 + rng.nextDouble() * 110,
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(TexturePainter oldDelegate) =>
      oldDelegate.theme != theme;
}
