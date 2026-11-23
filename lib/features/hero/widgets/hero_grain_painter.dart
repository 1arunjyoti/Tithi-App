import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Procedural film grain: a deterministic sprinkle of 1pt specks over the
/// hero gradient, which breaks up the banding a 150-200pt gradient shows on
/// 8-bit panels.
///
/// The specks are baked once into a small tiling texture and drawn as a single
/// shaded rect. Spraying them directly — one `drawRect` per speck — recorded
/// ~5,000 ops for a phone-sized card, and that display list is replayed on
/// every frame the card is composited (Impeller re-renders the layer tree each
/// frame). That made every animation in the app pay for the hero while it was
/// on screen: sheets, the drawer and the page itself all felt heavy. One quad
/// costs the same whatever the card size.
class HeroGrainPainter extends CustomPainter {
  const HeroGrainPainter(this.color);

  /// Speck spacing, matching the old "1pt speck every 3pt".
  static const double _cell = 3;

  /// 40 cells square. Short enough to stay cheap, long enough that the repeat
  /// does not read as a pattern once it is stretched over a card.
  static const double _tileExtent = 120;

  /// Built on first paint, then shared by every hero card. The tint is baked
  /// in (a shader ignores [Paint.color]) and the cache is rebuilt only when
  /// the theme hands over a different colour, which is rare.
  static ({Color color, Shader shader})? _cached;

  final Color color;

  ({Color color, Shader shader})? _grain() {
    final cached = _cached;
    if (cached != null && cached.color == color) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final ink = Paint()..color = color;
    // xorshift32: deterministic and allocation-free, so the grain is stable
    // across builds (no shimmering) and identical on every card.
    var seed = 0x9E3779B1;
    const extent = _tileExtent;
    for (double y = 0; y < extent; y += _cell) {
      for (double x = 0; x < extent; x += _cell) {
        seed ^= (seed << 13) & 0xFFFFFFFF;
        seed ^= seed >> 17;
        seed ^= (seed << 5) & 0xFFFFFFFF;
        if ((seed & 0x7) < 2) continue;
        // Jittered inside its cell; wrapped so specks at the right/bottom
        // edge stay inside the tile and the repeat has no seam.
        canvas.drawRect(
          Rect.fromLTWH(
            (x + (seed & 0x3)) % extent,
            (y + ((seed >> 2) & 0x3)) % extent,
            1,
            1,
          ),
          ink,
        );
      }
    }
    final ui.Image image;
    try {
      image = recorder.endRecording().toImageSync(
        extent.round(),
        extent.round(),
      );
    } catch (_) {
      // Engine cannot rasterize pictures synchronously (headless tooling):
      // the grain is decorative, so leave it off rather than paint per speck.
      return null;
    }
    final grain = (
      color: color,
      shader: ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
        filterQuality: FilterQuality.none,
      ),
    );
    _cached = grain;
    return grain;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grain = _grain();
    if (grain == null) return;
    canvas.drawRect(Offset.zero & size, Paint()..shader = grain.shader);
  }

  @override
  bool shouldRepaint(HeroGrainPainter oldDelegate) =>
      oldDelegate.color != color;
}
