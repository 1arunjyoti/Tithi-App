import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:jyotish/jyotish.dart';
import '../services/planetary_view_service.dart';
import 'location_provider.dart';

/// Provider for the selected date for planetary view
/// Defaults to current date/time
final planetaryViewDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Provider for solar system data at the selected date
final solarSystemDataProvider = FutureProvider<SolarSystemData>((ref) async {
  final service = ref.watch(planetaryViewServiceProvider);
  final viewDate = ref.watch(planetaryViewDateProvider);
  final viewMode = ref.watch(solarSystemViewModeProvider);
  final locationData = ref.watch(currentLocationProvider);

  return locationData.maybeWhen(
    data: (location) => service.getSolarSystemData(
      dateTime: viewDate,
      latitude: location?.latitude ?? 28.6139,
      longitude: location?.longitude ?? 77.2090,
      viewMode: viewMode,
    ),
    orElse: () =>
        service.getSolarSystemData(dateTime: viewDate, viewMode: viewMode),
  );
});

/// Provider for currently selected planet (for info display)
final selectedPlanetProvider = StateProvider<Planet?>((ref) {
  return null;
});

/// Provider for selected planet's visual data
final selectedPlanetDataProvider = Provider<PlanetVisualData?>((ref) {
  final selectedPlanet = ref.watch(selectedPlanetProvider);
  final solarSystemAsync = ref.watch(solarSystemDataProvider);

  if (selectedPlanet == null) return null;

  return solarSystemAsync.when(
    data: (data) => data.getPlanet(selectedPlanet),
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Provider to toggle animation on/off
final animationEnabledProvider = StateProvider<bool>((ref) {
  return true;
});

/// Provider for zoom level (default 1.0)
final zoomLevelProvider = StateProvider<double>((ref) {
  return 1.0;
});
