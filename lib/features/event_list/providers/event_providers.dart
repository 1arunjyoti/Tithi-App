import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/festival.dart';
import '../../../models/panchang_data.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/panchang_provider.dart';

// Phase 5a: event-list provider extracted from widgets/event_list_widget.dart.
// Names unchanged; the widget re-exports.

/// One festival occurrence inside the home card's upcoming window.
typedef UpcomingFestival = ({
  DateTime date,
  Festival festival,
  PanchangData panchang,
  int daysAway,
});

/// Home card coverage: the selected day plus the next 3 days. The selected
/// day's festivals come first; when it has none, the card simply starts with
/// the upcoming ones.
const int upcomingFestivalWindowDays = 4;

/// Max rows on the home card; everything else lives behind "View all".
const int upcomingFestivalMaxRows = 4;

final upcomingFestivalsProvider =
    FutureProvider.autoDispose<List<UpcomingFestival>>((ref) async {
      final selected = ref.watch(selectedDateProvider);
      final base = DateTime(selected.year, selected.month, selected.day);
      final days = List.generate(
        upcomingFestivalWindowDays,
        (i) => base.add(Duration(days: i)),
      );
      final panchangs = await Future.wait(
        days.map((day) async {
          // Hindu/Bengali adaptive grids already resolve this four-day
          // window for their festival markers. Event rows need that filtered
          // festival data, but not the hero-only intraday tithi transition;
          // reuse it instead of starting four selected-date providers.
          final cached = cachedPanchangUiSync(day);
          if (cached != null) return cached;
          try {
            return await ref.watch(panchangForDateProvider(day).future);
          } catch (_) {
            return null;
          }
        }),
      );
      final out = <UpcomingFestival>[];
      for (var i = 0; i < days.length; i++) {
        final panchang = panchangs[i];
        if (panchang == null) continue;
        for (final festival in panchang.festivals) {
          out.add((
            date: days[i],
            festival: festival,
            panchang: panchang,
            daysAway: i,
          ));
        }
      }
      return out;
    });
