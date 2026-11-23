// Cold-start timing marks.
//
// The home screen's four data cards all reset when Android evicts the process,
// and the fix depends on which stage dominates: the location round trip, the
// ephemeris install, the month batch, or the per-card resolution. Guessing from
// code has already produced one wrong assumption, so each stage drops a mark
// here and one launch's log says where the time actually goes.
//
// Opt-in: ordinary builds stay quiet so a user's logcat is not filled with a
// dozen lines per launch. A profiling build enables it with
// `--dart-define=tithi.startupTimeline=true`, which makes the regression that
// motivated these marks diagnosable again. Marks are a map write plus one log
// line, so they cannot move the measurement they are taking.

import 'package:flutter/foundation.dart';

abstract final class StartupTimeline {
  /// One clock per process, started from `main()` before any bootstrap work.
  static final Stopwatch _clock = Stopwatch()..start();

  static final Map<String, int> _marks = <String, int>{};

  /// False in ordinary builds; tests also force it off. Set true explicitly
  /// (or build with `--dart-define=tithi.startupTimeline=true`) to log marks.
  static bool enabled = const bool.fromEnvironment('tithi.startupTimeline');

  /// Restarts the clock. Called once at the top of `main()`.
  static void start() {
    _clock
      ..reset()
      ..start();
  }

  /// Records [name] at the current elapsed time and logs it as
  /// `[startup] +NNNms name key=value`.
  static void mark(String name, [Map<String, Object?> detail = const {}]) {
    if (!enabled) return;
    final elapsed = _clock.elapsedMilliseconds;
    _marks[name] = elapsed;
    final extra = detail.isEmpty
        ? ''
        : ' ${detail.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
    debugPrint('[startup] +${elapsed}ms $name$extra');
  }

  /// Elapsed milliseconds when [name] was last recorded, or null.
  static int? elapsedMs(String name) => _marks[name];

  /// Records captured so far (insertion ordered).
  static Map<String, int> get marks => Map.unmodifiable(_marks);

  @visibleForTesting
  static void reset() {
    _marks.clear();
    start();
  }
}
