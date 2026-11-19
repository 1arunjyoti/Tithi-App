import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tithi/core/location/place_grid.dart';
import 'package:tithi/providers/location_provider.dart';
import 'package:tithi/services/location_service.dart';

/// The home cards compute their panchang from [coordinatesProvider]. These
/// tests pin the contract that lets a cold start paint at the last used place
/// instead of the Delhi fallback (or a skeleton) while GPS is still resolving:
///
/// - the saved place is published immediately;
/// - a device fix inside the same ~1.1 km cell must NOT replace it (a new
///   `LocationData` would restart the month batch right after first paint);
/// - a fix in another cell must replace it (the user really moved).
LocationData _place(double lat, double lng, {String? city}) => LocationData(
  latitude: lat,
  longitude: lng,
  cityName: city,
  timestamp: DateTime(2026, 11, 17),
);

final LocationData _saved = _place(28.6139, 77.2090, city: 'New Delhi');
// ~100 m away: same 28.61_77.21 cell.
final LocationData _jittered = _place(28.6145, 77.2088, city: 'New Delhi');
// ~12 km away: 28.70_77.10 cell.
final LocationData _moved = _place(28.7041, 77.1025, city: 'Delhi NCR');

ProviderContainer _container({
  required LocationData? saved,
  required Future<LocationData?> deviceFix,
}) {
  final container = ProviderContainer(
    overrides: [
      persistedLocationProvider.overrideWithValue(saved),
      currentLocationProvider.overrideWith((ref) => deviceFix),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('place grid', () {
    test('treats sub-kilometre jitter as the same place', () {
      expect(
        samePlaceGrid(
          latitudeA: _saved.latitude,
          longitudeA: _saved.longitude,
          latitudeB: _jittered.latitude,
          longitudeB: _jittered.longitude,
        ),
        isTrue,
      );
    });

    test('treats a cross-city move as a different place', () {
      expect(
        samePlaceGrid(
          latitudeA: _saved.latitude,
          longitudeA: _saved.longitude,
          latitudeB: _moved.latitude,
          longitudeB: _moved.longitude,
        ),
        isFalse,
      );
    });
  });

  group('cold start at the saved place', () {
    test('publishes the saved place while the device fix is pending', () {
      // Arrange
      final container = _container(
        saved: _saved,
        deviceFix: Completer<LocationData?>().future,
      );

      // Act
      final coords = container.read(coordinatesProvider);

      // Assert
      expect(coords.asData?.value.latitude, _saved.latitude);
      expect(coords.asData?.value.longitude, _saved.longitude);
    });

    test('keeps the saved place when the fix lands in the same cell', () async {
      // Arrange
      final fix = Completer<LocationData?>();
      final container = _container(saved: _saved, deviceFix: fix.future);
      final before = container.read(calculationLocationProvider);

      // Act
      fix.complete(_jittered);
      await container.read(currentLocationProvider.future);
      await _settle();

      // Assert
      expect(
        identical(container.read(calculationLocationProvider), before),
        isTrue,
        reason: 'a same-cell fix must not notify the panchang providers',
      );
      expect(
        container.read(coordinatesProvider).asData?.value.latitude,
        _saved.latitude,
      );
    });

    test('adopts a fix that lands in a different cell', () async {
      // Arrange
      final fix = Completer<LocationData?>();
      final container = _container(saved: _saved, deviceFix: fix.future);
      expect(
        container.read(coordinatesProvider).asData?.value.latitude,
        _saved.latitude,
      );

      // Act
      fix.complete(_moved);
      await container.read(currentLocationProvider.future);
      await _settle();

      // Assert
      expect(
        identical(container.read(calculationLocationProvider), _moved),
        isTrue,
      );
      expect(
        container.read(coordinatesProvider).asData?.value.latitude,
        _moved.latitude,
      );
      expect(
        container.read(coordinatesProvider).asData?.value.longitude,
        _moved.longitude,
      );
    });

    test('falls back to the device fix when nothing was saved', () async {
      // Arrange (first launch: no persisted fix)
      final fix = Completer<LocationData?>();
      final container = _container(saved: null, deviceFix: fix.future);
      expect(container.read(coordinatesProvider).asData, isNull);

      // Act
      fix.complete(_moved);
      await container.read(currentLocationProvider.future);
      await _settle();

      // Assert
      expect(
        container.read(coordinatesProvider).asData?.value.latitude,
        _moved.latitude,
      );
    });
  });
}
