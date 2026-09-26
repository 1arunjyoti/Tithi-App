import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/shloka.dart';
import '../../../providers/panchang_provider.dart';
import '../../../services/shloka_service.dart';

// Phase 5a: quote providers extracted from widgets/daily_quote_widget.dart.
// Names unchanged; the widget re-exports. Pure helpers (quoteDayLabel,
// stepQuoteDay, buildShlokaShareText) stay with the widget for now.

// Verse shown on the Daily Wisdom card for one day, plus display metadata.
class DailyWisdom {
  final Shloka shloka;
  final DateTime date;
  final int dayOffset;
  final String? festivalName;

  const DailyWisdom({
    required this.shloka,
    required this.date,
    this.dayOffset = 0,
    this.festivalName,
  });
}

// Day offset from today for browsing past/future verses. 0 = today.
final quoteDayOffsetProvider = StateProvider.autoDispose<int>((ref) => 0);

/// Browsing bounds in days. Each new date resolves its panchang from the
/// Hive-cached month batches, so the range stays modest.
const int quoteMaxDayOffset = 30;

// Provider for the verse of the selected day.
final dailyShlokaProvider = FutureProvider.autoDispose<DailyWisdom?>((
  ref,
) async {
  final service = ShlokaService();
  await service.init();

  final offset = ref.watch(quoteDayOffsetProvider);
  final now = DateTime.now();
  final date = DateTime(now.year, now.month, now.day + offset);
  final panchang = await ref.watch(panchangForDateProvider(date).future);
  final festivals = panchang.festivals;
  final shloka = service.getShlokaForDate(
    date,
    festivalIds: festivals.map((festival) => festival.id).toList(),
  );
  if (shloka == null) return null;
  String? festivalName;
  for (final festival in festivals) {
    if (shloka.festivalIds.contains(festival.id)) {
      festivalName = festival.name;
      break;
    }
  }
  return DailyWisdom(
    shloka: shloka,
    date: date,
    dayOffset: offset,
    festivalName: festivalName,
  );
});

// UI State provider for collapse/expand
// Using autoDispose so it resets when leaving the screen/rebuilding
final quoteExpandedProvider = StateProvider.autoDispose<bool>((ref) => false);

// UI State for revealing every available translation in the expanded view.
// Also autoDispose; explicitly reset when the card is collapsed.
final quoteShowAllTranslationsProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);
