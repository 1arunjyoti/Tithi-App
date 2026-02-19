import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jyotish/jyotish.dart';
import '../services/planetary_view_service.dart';
import 'location_provider.dart';

/// Provider for the selected date for planetary view
/// Defaults to current date/time
class PlanetaryViewDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setDate(DateTime value) {
    state = value;
  }
}

final planetaryViewDateProvider =
    NotifierProvider<PlanetaryViewDateNotifier, DateTime>(
      PlanetaryViewDateNotifier.new,
    );

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
class SelectedPlanetNotifier extends Notifier<Planet?> {
  @override
  Planet? build() => null;

  void setPlanet(Planet? planet) {
    state = planet;
  }
}

final selectedPlanetProvider = NotifierProvider<SelectedPlanetNotifier, Planet?>(
  SelectedPlanetNotifier.new,
);

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
class AnimationEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setEnabled(bool enabled) {
    state = enabled;
  }
}

final animationEnabledProvider = NotifierProvider<AnimationEnabledNotifier, bool>(
  AnimationEnabledNotifier.new,
);

/// Provider for zoom level (default 1.0)
class ZoomLevelNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  void setZoom(double zoom) {
    state = zoom;
  }
}

final zoomLevelProvider = NotifierProvider<ZoomLevelNotifier, double>(
  ZoomLevelNotifier.new,
);
