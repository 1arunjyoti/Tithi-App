import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jyotish/jyotish.dart';
import '../services/planetary_view_service.dart';
import 'location_provider.dart';
import '../core/location/location_defaults.dart';

/// Provider for PlanetaryViewService (moved here in Phase 6a: service
/// files must not own Riverpod providers).
final planetaryViewServiceProvider = Provider<PlanetaryViewService>((ref) {
  return PlanetaryViewService();
});

/// Provider for current view mode (moved here in Phase 6a, same reason).
class SolarSystemViewModeNotifier extends Notifier<SolarSystemViewMode> {
  @override
  SolarSystemViewMode build() => SolarSystemViewMode.heliocentric;

  void setViewMode(SolarSystemViewMode viewMode) {
    state = viewMode;
  }
}

final solarSystemViewModeProvider =
    NotifierProvider<SolarSystemViewModeNotifier, SolarSystemViewMode>(
      SolarSystemViewModeNotifier.new,
    );

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

/// Provider for solar system data at the selected date.
///
/// The date is day-normalized: the 30fps animation timer advances by
/// microseconds, and positions move negligibly within a day — without this,
/// every frame would miss the solar cache and redo the batched FFI call.
final solarSystemDataProvider = FutureProvider<SolarSystemData>((ref) async {
  final service = ref.watch(planetaryViewServiceProvider);
  final viewDate = ref.watch(planetaryViewDateProvider);
  final day = DateTime(viewDate.year, viewDate.month, viewDate.day);
  final viewMode = ref.watch(solarSystemViewModeProvider);
  final locationData = ref.watch(currentLocationProvider);

  return locationData.maybeWhen(
    data: (location) => service.getSolarSystemData(
      dateTime: day,
      latitude: location?.latitude ?? kDefaultLatitude,
      longitude: location?.longitude ?? kDefaultLongitude,
      viewMode: viewMode,
    ),
    orElse: () =>
        service.getSolarSystemData(dateTime: day, viewMode: viewMode),
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
