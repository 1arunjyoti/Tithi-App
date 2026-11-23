import 'package:flutter/foundation.dart';

import '../../../providers/calendar_provider.dart' as cp;
import 'calendar_models.dart';

/// Resolved view of the adaptive (Hindu/Bengali) grid.
///
/// The stale grid must keep its OLD key so the caller's `AnimatedSwitcher`
/// holds it static (no transition) until fresh data arrives under the NEW
/// key. That produces a single slide old -> new instead of the
/// double-transition flash where the outgoing grid slides into itself first.
class AdaptiveGridDisplay {
  final AdaptiveCalendarData data;
  final String key;

  const AdaptiveGridDisplay({required this.data, required this.key});
}

AdaptiveCalendarData? _lastData;
int? _lastSystemIndex;
int? _lastModeIndex;
String? _lastKey;

/// Clears the remembered stale grid. Test-only: production keeps this state
/// for the widget's lifetime.
@visibleForTesting
void resetAdaptiveGridDisplay() {
  _lastData = null;
  _lastSystemIndex = null;
  _lastModeIndex = null;
  _lastKey = null;
}

/// Returns the grid to render, remembering [fresh] when it resolves.
///
/// [fresh] is the focused month's resolved data, or null while loading.
/// Returns null only on a cold start with no reusable stale grid. The stale
/// grid is scoped by calendar system and display mode so a Hindu grid is
/// never shown as stale Bengali data.
AdaptiveGridDisplay? resolveAdaptiveGridDisplay({
  required AdaptiveCalendarData? fresh,
  required String freshKey,
  required cp.AppCalendarSystem system,
  required cp.TithiDisplayMode mode,
}) {
  if (fresh != null) {
    _lastData = fresh;
    _lastSystemIndex = system.index;
    _lastModeIndex = mode.index;
    _lastKey = freshKey;
  }
  final reuseStale =
      _lastData != null &&
      _lastSystemIndex == system.index &&
      _lastModeIndex == mode.index;
  if (fresh == null && !reuseStale) return null;
  return AdaptiveGridDisplay(
    data: fresh ?? _lastData!,
    key: fresh != null
        ? freshKey
        : (reuseStale ? (_lastKey ?? freshKey) : freshKey),
  );
}
