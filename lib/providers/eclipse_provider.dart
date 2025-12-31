import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/eclipse.dart';
import '../services/eclipse_service.dart';
import 'location_provider.dart';

/// Provider for upcoming eclipses
/// Auto-refreshes based on location changes
final upcomingEclipsesProvider = FutureProvider<List<Eclipse>>((ref) async {
  final eclipseService = ref.watch(eclipseServiceProvider);
  final locationData = ref.watch(currentLocationProvider);

  return locationData.when(
    data: (location) => eclipseService.getUpcomingEclipses(
      count: 12,
      latitude: location?.latitude ?? 28.6139,
      longitude: location?.longitude ?? 77.2090,
    ),
    loading: () => eclipseService.getUpcomingEclipses(),
    error: (_, _) => eclipseService.getUpcomingEclipses(),
  );
});

/// Provider for selected eclipse (for detail view)
final selectedEclipseProvider = StateProvider<Eclipse?>((ref) {
  return null;
});

/// Provider for eclipse with local visibility details
final eclipseWithVisibilityProvider = FutureProvider.family<Eclipse, Eclipse>((
  ref,
  eclipse,
) async {
  final eclipseService = ref.watch(eclipseServiceProvider);
  final locationData = ref.watch(currentLocationProvider);

  return locationData.when(
    data: (location) => eclipseService.getEclipseWithVisibility(
      eclipse: eclipse,
      latitude: location?.latitude ?? 28.6139,
      longitude: location?.longitude ?? 77.2090,
    ),
    loading: () => eclipse,
    error: (_, _) => eclipse,
  );
});
