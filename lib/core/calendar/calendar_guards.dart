import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/calendar_provider.dart';

// P0-3: shared guards for calendar-gated providers. Replaces ~12 copies of
// "watch primary/secondary → return null if irrelevant → try FFI → catch →
// null" across sheet/schedule/hero/countdown providers. Takes [Ref] (all
// call sites are providers; widgets use resolveAppLocale instead).

/// True when [system] is the primary calendar.
bool isPrimarySystem(Ref ref, AppCalendarSystem system) =>
    ref.watch(primaryCalendarSystemProvider) == system;

/// True when [system] is shown as primary or secondary.
bool showsCalendarSystem(Ref ref, AppCalendarSystem system) {
  return ref.watch(primaryCalendarSystemProvider) == system ||
      ref.watch(secondaryCalendarSystemProvider) == system;
}

/// Runs [fn], returning null on any failure (FFI/services unavailable).
/// Callers fall back to Gregorian/empty UI when null.
Future<T?> guarded<T>(Future<T> Function() fn) async {
  try {
    return await fn();
  } catch (_) {
    return null;
  }
}
