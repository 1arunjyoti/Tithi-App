import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tithi/screens/location_picker_screen.dart'
    show kLocationPickerMapFlags, resetMapToNorth;

void main() {
  group('location picker map interaction flags', () {
    test('two-finger rotation is disabled', () {
      // A pinch is never perfectly aligned; without this, the twist component
      // rotates the map while the user only meant to zoom.
      expect(InteractiveFlag.hasRotate(kLocationPickerMapFlags), isFalse);
    });

    test('pinch zoom, drag and double-tap zoom remain enabled', () {
      expect(InteractiveFlag.hasPinchZoom(kLocationPickerMapFlags), isTrue);
      expect(InteractiveFlag.hasDrag(kLocationPickerMapFlags), isTrue);
      expect(InteractiveFlag.hasDoubleTapZoom(kLocationPickerMapFlags), isTrue);
    });
  });

  testWidgets('resetMapToNorth restores a north-up camera on entry',
      (tester) async {
    final controller = MapController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: FlutterMap(
          mapController: controller,
          options: const MapOptions(
            initialCenter: LatLng(28.6139, 77.209),
            initialRotation: 45,
            interactionOptions: InteractionOptions(
              flags: kLocationPickerMapFlags,
            ),
          ),
          children: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.camera.rotation, 45);
    resetMapToNorth(controller);
    await tester.pumpAndSettle();
    expect(controller.camera.rotation, 0);
  });
}
