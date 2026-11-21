import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/calendar/data/adaptive_grid_state.dart';
import 'package:tithi/features/calendar/data/calendar_models.dart';
import 'package:tithi/providers/calendar_provider.dart' as cp;

AdaptiveCalendarData _data(String primary) => AdaptiveCalendarData(
  days: const [],
  cellData: {DateTime(2026, 2, 2): CalendarCellData(primary: primary)},
);

AdaptiveGridDisplay? _resolve({
  required AdaptiveCalendarData? fresh,
  required String freshKey,
  cp.AppCalendarSystem system = cp.AppCalendarSystem.hindu,
  cp.TithiDisplayMode mode = cp.TithiDisplayMode.pakshaBased,
}) {
  return resolveAdaptiveGridDisplay(
    fresh: fresh,
    freshKey: freshKey,
    system: system,
    mode: mode,
  );
}

void main() {
  setUp(resetAdaptiveGridDisplay);

  group('resolveAdaptiveGridDisplay', () {
    test('cold start with no fresh data returns null', () {
      final display = _resolve(fresh: null, freshKey: 'k1');

      expect(display, isNull);
    });

    test('fresh data renders under its own key', () {
      final data = _data('fresh');

      final display = _resolve(fresh: data, freshKey: 'k1');

      expect(display, isNotNull);
      expect(display!.data, same(data));
      expect(display.key, 'k1');
    });

    test('while the next month loads the stale grid keeps its OLD key', () {
      final first = _data('first');
      _resolve(fresh: first, freshKey: 'k1');

      final stale = _resolve(fresh: null, freshKey: 'k2');

      expect(stale, isNotNull);
      expect(stale!.data, same(first));
      expect(
        stale.key,
        'k1',
        reason: 'old key keeps the AnimatedSwitcher static during the hold',
      );
    });

    test('fresh data takes the new key after the stale hold', () {
      _resolve(fresh: _data('first'), freshKey: 'k1');
      final second = _data('second');

      final display = _resolve(fresh: second, freshKey: 'k2');

      expect(display, isNotNull);
      expect(display!.data, same(second));
      expect(display.key, 'k2');
    });

    test('stale grid is not reused across calendar systems', () {
      _resolve(fresh: _data('hindu'), freshKey: 'k1');

      final display = _resolve(
        fresh: null,
        freshKey: 'k2',
        system: cp.AppCalendarSystem.bengali,
      );

      expect(display, isNull);
    });

    test('stale grid is not reused across display modes', () {
      _resolve(fresh: _data('paksha'), freshKey: 'k1');

      final display = _resolve(
        fresh: null,
        freshKey: 'k2',
        mode: cp.TithiDisplayMode.continuous30,
      );

      expect(display, isNull);
    });
  });
}
