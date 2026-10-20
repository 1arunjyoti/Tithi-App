import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/widgets/paksha_hero_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HeroGrainPainter', () {
    const painter = HeroGrainPainter(Color(0x0DFFFFFF));

    test('paints the grain as a single tiled quad', () {
      // Arrange
      final canvas = TestRecordingCanvas();

      // Act
      painter.paint(canvas, const Size(360, 180));

      // Assert: one shaded rect, not one draw op per speck. The previous
      // implementation recorded ~5,000 drawRect calls for this size, and that
      // display list is replayed on every frame the card is composited.
      expect(canvas.invocations.length, lessThanOrEqualTo(2));
      final draw = canvas.invocations.firstWhere(
        (i) => i.invocation.memberName == #drawRect,
      );
      final paint = draw.invocation.positionalArguments[1] as Paint;
      expect(paint.shader, isA<ImageShader>());
    });

    test('cost does not grow with the card area', () {
      // Arrange
      final small = TestRecordingCanvas();
      final large = TestRecordingCanvas();

      // Act
      painter.paint(small, const Size(320, 150));
      painter.paint(large, const Size(1200, 800));

      // Assert: the tiled texture covers any size at the same op count.
      expect(large.invocations.length, small.invocations.length);
    });

    test('repaints only when the tint changes', () {
      // Arrange
      const same = HeroGrainPainter(Color(0x0DFFFFFF));
      const other = HeroGrainPainter(Color(0x0A000000));

      // Assert
      expect(painter.shouldRepaint(same), isFalse);
      expect(painter.shouldRepaint(other), isTrue);
    });

    test('the tile is real grain, not a blank or solid wash', () async {
      // Arrange: opaque specks make the coverage easy to read back
      const tile = 120.0;
      final recorder = ui.PictureRecorder();
      const HeroGrainPainter(
        Color(0xFFFFFFFF),
      ).paint(Canvas(recorder), const Size(tile, tile));
      final picture = recorder.endRecording();

      // Act
      final image = await picture.toImage(tile.toInt(), tile.toInt());
      final data = (await image.toByteData())!;

      // Assert: roughly a third of the cells carry a speck
      var lit = 0;
      for (var i = 3; i < data.lengthInBytes; i += 4) {
        if (data.getUint8(i) > 0) lit++;
      }
      expect(lit, greaterThan(600));
      expect(lit, lessThan(4000));
    });
  });
}
