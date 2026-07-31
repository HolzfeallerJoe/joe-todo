import 'dart:math';

import 'package:flutter/material.dart';

enum TextureStyle { paper, wood, fabric, watercolor }

class JoeTheme {
  final String name;
  final TextureStyle texture;
  final Color bgTop;
  final Color bgBottom;
  final Color paper;
  final Color ink;
  final Color inkSoft;
  final Color accent;
  final List<Color> tabColors;

  const JoeTheme({
    required this.name,
    required this.texture,
    required this.bgTop,
    required this.bgBottom,
    required this.paper,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.tabColors,
  });
}

const joeThemes = [
  JoeTheme(
    name: 'Holz',
    texture: TextureStyle.wood,
    bgTop: Color(0xFFE3C08F),
    bgBottom: Color(0xFFC2925C),
    paper: Color(0xFFFAF3E3),
    ink: Color(0xFF4A3527),
    inkSoft: Color(0xFF8A7461),
    accent: Color(0xFFC0563B),
    tabColors: [
      Color(0xFFE4A54F),
      Color(0xFF82C0AE),
      Color(0xFFB9C29B),
      Color(0xFFC79A63),
      Color(0xFFC96480),
    ],
  ),
  JoeTheme(
    name: 'Papier',
    texture: TextureStyle.paper,
    bgTop: Color(0xFFF6EFDC),
    bgBottom: Color(0xFFEADFC4),
    paper: Color(0xFFFFFDF6),
    ink: Color(0xFF453A2E),
    inkSoft: Color(0xFF8C8070),
    accent: Color(0xFFB25438),
    tabColors: [
      Color(0xFFE8B45C),
      Color(0xFF8FC5B4),
      Color(0xFFC3CBA4),
      Color(0xFFD3A878),
      Color(0xFFD2788F),
    ],
  ),
  JoeTheme(
    name: 'Stoff',
    texture: TextureStyle.fabric,
    bgTop: Color(0xFFE5D5C0),
    bgBottom: Color(0xFFD3BC9F),
    paper: Color(0xFFFBF6EA),
    ink: Color(0xFF4C3D2E),
    inkSoft: Color(0xFF8D7C67),
    accent: Color(0xFFA8563E),
    tabColors: [
      Color(0xFFDFA75B),
      Color(0xFF8BBBA8),
      Color(0xFFB5BE97),
      Color(0xFFC49B6F),
      Color(0xFFC57287),
    ],
  ),
  JoeTheme(
    name: 'Aquarell',
    texture: TextureStyle.watercolor,
    bgTop: Color(0xFFFDF7EB),
    bgBottom: Color(0xFFF3E7D3),
    paper: Color(0xFFFFFEFA),
    ink: Color(0xFF50443A),
    inkSoft: Color(0xFF95887A),
    accent: Color(0xFFC26350),
    tabColors: [
      Color(0xFFEDBB6B),
      Color(0xFF9CCBBB),
      Color(0xFFC9D2AC),
      Color(0xFFDCB183),
      Color(0xFFDD8BA0),
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
