import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/temple.dart';
import '../../../services/temple_service.dart';

// Temple search state machine extracted from screens/temple_map_screen.dart.
// Six setState flags (loading/list/page/hasMore/generation/in-flight keys)
// collapse into one notifier with explicit transitions: concurrent,
// out-of-order, or post-dispose completions can no longer desync the UI.

/// Paginated temple search state.
class TempleListState {
  const TempleListState({
    this.temples = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  final List<Temple> temples;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;

  /// Last fetch failure (consumed by the screen's snackbar listener).
  final Object? error;

  TempleListState copyWith({
    List<Temple>? temples,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    Object? error,
  }) {
    return TempleListState(
      temples: temples ?? this.temples,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

/// Search radius bucket for a map zoom level.
double templeRadiusFromZoom(double zoom) {
  if (zoom >= 15) return 2500;
  if (zoom >= 13) return 5000;
  if (zoom >= 11) return 9000;
  return 15000;
}

/// Dedupe key for a page fetch (coordinates rounded to ~11m).
String templeQueryKey(LatLng center, double radius, int page) {
  final lat = center.latitude.toStringAsFixed(4);
  final lon = center.longitude.toStringAsFixed(4);
  return '$lat,$lon:${radius.round()}:$page';
}

class TempleListNotifier extends Notifier<TempleListState> {
  static const int pageSize = 80;

  TempleService? _service;
  bool _disposed = false;
  int _generation = 0;
  String? _inFlightKey;
  String? _lastCompletedKey;

  @override
  TempleListState build() {
    ref.onDispose(() {
      _disposed = true;
      _service?.close();
      _service = null;
    });
    return const TempleListState();
  }

  /// Fetches a page of temples around [center].
  ///
  /// [reset] restarts pagination; [force] bypasses the in-flight and
  /// completed-query dedupe. Stale generations (a newer fetch started
  /// meanwhile) and post-dispose completions are dropped, never applied.
  Future<void> fetch({
    required LatLng center,
    required double radius,
    bool reset = true,
    bool force = false,
  }) async {
    final page = reset ? 0 : state.currentPage;
    if (!reset && !state.hasMore) return;
    final queryKey = templeQueryKey(center, radius, page);

    if (_inFlightKey == queryKey) return;
    if (!force && reset && _lastCompletedKey == queryKey) return;

    final generation = ++_generation;
    _inFlightKey = queryKey;
    _service ??= TempleService();
    state = state.copyWith(
      isLoading: true,
      hasMore: reset ? true : state.hasMore,
      currentPage: reset ? 0 : state.currentPage,
    );
    try {
      final temples = await _service!.fetchNearbyTemples(
        center.latitude,
        center.longitude,
        radius: radius,
        page: page,
      );
      if (_disposed || generation != _generation) return;
      final existingIds = state.temples.map((t) => t.id).toSet();
      state = state.copyWith(
        temples: reset
            ? temples
            : [
                ...state.temples,
                ...temples.where((t) => !existingIds.contains(t.id)),
              ],
        hasMore: temples.length == pageSize,
        currentPage: temples.isNotEmpty ? page + 1 : page,
        isLoading: false,
      );
      _lastCompletedKey = queryKey;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      state = state.copyWith(isLoading: false, error: e);
    } finally {
      if (_inFlightKey == queryKey) _inFlightKey = null;
      if (!_disposed &&
          generation == _generation &&
          state.isLoading &&
          state.error == null) {
        // Unreachable in practice (both branches above set isLoading),
        // kept so a future edit can't strand the spinner.
        state = state.copyWith(isLoading: false);
      }
    }
  }

  /// Clears a consumed error so later failures surface again.
  void clearError() {
    if (state.error != null) state = state.copyWith();
  }
}

final templeListProvider =
    NotifierProvider<TempleListNotifier, TempleListState>(
      TempleListNotifier.new,
    );
