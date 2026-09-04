import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/panchang_data.dart';
import '../models/hindu_month_system.dart';
import '../providers/panchang_provider.dart';
import '../providers/accessibility_provider.dart';
import '../providers/calendar_provider.dart' as cp;
import '../services/bengali_calendar_service.dart';
import '../services/hindu_calendar_service.dart';
import '../theme/app_theme.dart';
import 'event_detail_sheet.dart';

/// Data class for Hindu date with proper settings applied
class HinduDateData {
  final int day; // tithi number
  final String month; // masa name (with month system applied)
  final String paksha;
  final int year; // year in selected era
  final String eraLabel; // "Vikram" or "Shaka"

  HinduDateData({
    required this.day,
    required this.month,
    required this.paksha,
    required this.year,
    required this.eraLabel,
  });
}

class ScheduleDateData {
  final PanchangData panchang;
  final ({int day, String month, int year})? bengaliDate;
  final HinduDateData? hinduDate;

  const ScheduleDateData({
    required this.panchang,
    required this.bengaliDate,
    required this.hinduDate,
  });
}

/// Provider for Hindu date with settings applied
final hinduDateForScheduleProvider = FutureProvider.autoDispose
    .family<HinduDateData?, DateTime>((ref, date) async {
      final primarySystem = ref.watch(cp.primaryCalendarSystemProvider);
      final secondarySystem = ref.watch(cp.secondaryCalendarSystemProvider);

      // Only calculate if Hindu is primary or secondary
      if (primarySystem != cp.AppCalendarSystem.hindu &&
          secondarySystem != cp.AppCalendarSystem.hindu) {
        return null;
      }

      try {
        final service = ref.read(hinduCalendarServiceProvider);
        final monthSystem = ref.watch(cp.hinduMonthSystemProvider);
        final yearEra = ref.watch(cp.hinduYearEraProvider);

        final hDate = await service.calculateDate(date);

        // Apply display mode (paksha-based 1-15 or continuous 1-30)
        final displayMode = ref.watch(cp.tithiDisplayModeProvider);
        final displayTithi = displayMode == cp.TithiDisplayMode.continuous30
            ? hDate.fullTithi
            : hDate.tithi;

        // Apply month system conversion if needed
        String masa = displayMasaName(
          hDate.masa,
          hDate.paksha,
          monthSystem,
        );
        // Replace underscores with spaces for display (e.g. 'Adhika_Jyeshtha' -> 'Adhika Jyeshtha')
        masa = masa.replaceAll('_', ' ');

        // Get year based on era selection
        final year = yearEra == HinduYearEra.vikramSamvat
            ? hDate.vsYear
            : hDate.shakaYear;
        final eraLabel = yearEra.shortLabel;

        return HinduDateData(
          day: displayTithi,
          month: masa,
          paksha: hDate.paksha,
          year: year,
          eraLabel: eraLabel,
        );
      } catch (_) {
        return null;
      }
    });

/// Provider for Bengali date for a specific date
final bengaliDateForScheduleProvider = FutureProvider.autoDispose
    .family<({int day, String month, int year})?, DateTime>((ref, date) async {
      final primarySystem = ref.watch(cp.primaryCalendarSystemProvider);
      final secondarySystem = ref.watch(cp.secondaryCalendarSystemProvider);

      // Only calculate if Bengali is primary or secondary
      if (primarySystem != cp.AppCalendarSystem.bengali &&
          secondarySystem != cp.AppCalendarSystem.bengali) {
        return null;
      }

      try {
        final service = ref.read(bengaliCalendarServiceProvider);
        return await service.calculateDate(date);
      } catch (_) {
        return null;
      }
    });

final scheduleDateDataProvider = FutureProvider.autoDispose
    .family<ScheduleDateData, DateTime>((ref, date) async {
      final panchang = await ref.watch(panchangForDateProvider(date).future);

      final results = await Future.wait<Object?>([
        ref.watch(bengaliDateForScheduleProvider(date).future),
        ref.watch(hinduDateForScheduleProvider(date).future),
      ]);

      return ScheduleDateData(
        panchang: panchang,
        bengaliDate: results[0] as ({int day, String month, int year})?,
        hinduDate: results[1] as HinduDateData?,
      );
    });

/// Schedule View Widget - displays events in a vertical scrollable list
/// similar to Google Calendar's Schedule view.
/// Uses a CustomScrollView with center key for stable scroll anchoring.
class ScheduleViewWidget extends ConsumerStatefulWidget {
  const ScheduleViewWidget({super.key});

  @override
  ConsumerState<ScheduleViewWidget> createState() => _ScheduleViewWidgetState();
}

class _ScheduleViewWidgetState extends ConsumerState<ScheduleViewWidget> {
  final ScrollController _scrollController = ScrollController();

  // Key for the center sliver (today)
  final GlobalKey _centerKey = GlobalKey();

  // How many days to show in each direction
  int _daysBefore = 30;
  int _daysAfter = 90;

  // How many days to load when reaching edges
  final int _loadMoreDays = 60;

  // Threshold to trigger loading more (in pixels from edge)
  final double _loadThreshold = 500;

  // Track "today" for reference (anchor date)
  late DateTime _anchorDate;

  // Track current visible month for sticky header
  late DateTime _currentVisibleMonth;

  // Loading states
  bool _isLoadingPast = false;
  bool _isLoadingFuture = false;

  @override
  void initState() {
    super.initState();
    _anchorDate = DateTime.now();
    _currentVisibleMonth = _anchorDate;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;

    // Load more past dates when near the top
    if (position.pixels < position.minScrollExtent + _loadThreshold &&
        !_isLoadingPast) {
      _loadMorePastDates();
    }

    // Load more future dates when near the bottom
    if (position.maxScrollExtent - position.pixels < _loadThreshold &&
        !_isLoadingFuture) {
      _loadMoreFutureDates();
    }

    // Update visible month based on scroll position - relative to anchor date
    const estimatedItemHeight = 80.0;
    final daysOffset = (position.pixels / estimatedItemHeight).round();
    final visibleDate = _anchorDate.add(Duration(days: daysOffset));

    // Only update if month/year changed
    if (visibleDate.month != _currentVisibleMonth.month ||
        visibleDate.year != _currentVisibleMonth.year) {
      setState(() {
        _currentVisibleMonth = visibleDate;
      });

      // Update focused month provider (for sync with calendar view)
      Future.microtask(() {
        if (mounted) {
          ref
              .read(cp.focusedMonthProvider.notifier)
              .setFocusedMonth(visibleDate);
        }
      });
    }
  }

  void _loadMorePastDates() {
    setState(() {
      _isLoadingPast = true;
      _daysBefore += _loadMoreDays;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _isLoadingPast = false);
      }
    });
  }

  void _loadMoreFutureDates() {
    setState(() {
      _isLoadingFuture = true;
      _daysAfter += _loadMoreDays;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _isLoadingFuture = false);
      }
    });
  }

  void _scrollToToday({bool animated = true}) {
    final now = DateTime.now();
    // Use jump logic if we need to re-anchor
    final difference = now.difference(_anchorDate).inDays;

    if (difference.abs() > 180) {
      _jumpToDate(now);
      return;
    }

    if (difference == 0 && _scrollController.hasClients) {
      if (animated) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        _scrollController.jumpTo(0);
      }
    } else {
      _jumpToDate(now);
    }
  }

  void _jumpToDate(DateTime date) {
    setState(() {
      _anchorDate = date;
      _currentVisibleMonth = date;
      _daysBefore = 30; // Reset range
      _daysAfter = 90;
    });

    // Scroll to center
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentVisibleMonth,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: context.colors.primary.computeLuminance() > 0.5
                ? ColorScheme.light(primary: context.colors.primary)
                : ColorScheme.dark(primary: context.colors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Update selected date provider which triggers the listener
      ref.read(cp.selectedDateProvider.notifier).setDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to selected date changes to trigger jumps
    ref.listen(cp.selectedDateProvider, (previous, next) {
      // Avoid jumping if the change is just within currently visible range
      // But for "Search" results, we always want to jump
      if (next.year != _anchorDate.year ||
          next.month != _anchorDate.month ||
          next.day != _anchorDate.day) {
        _jumpToDate(next);
      }
    });

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          center: _centerKey,
          slivers: [
            // Past dates (builds upward/reverse from today)
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                // index 0 = yesterday, index 1 = 2 days ago, etc.
                final daysAgo = index + 1;
                if (daysAgo > _daysBefore) return null;

                final date = DateTime(
                  _anchorDate.year,
                  _anchorDate.month,
                  _anchorDate.day - daysAgo,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ScheduleDateItem(date: date, isToday: false),
                );
              }, childCount: _daysBefore),
            ),

            // Today (center anchor)
            SliverToBoxAdapter(
              key: _centerKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: _ScheduleDateItem(date: _anchorDate, isToday: true),
              ),
            ),

            // Future dates (builds downward from today)
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                // index 0 = tomorrow, index 1 = 2 days from now, etc.
                final daysAhead = index + 1;
                if (daysAhead > _daysAfter) return null;

                final date = DateTime(
                  _anchorDate.year,
                  _anchorDate.month,
                  _anchorDate.day + daysAhead,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ScheduleDateItem(date: date, isToday: false),
                );
              }, childCount: _daysAfter),
            ),
          ],
        ),

        // Floating Action Button to scroll to today
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'schedule_today_fab',
            onPressed: () => _scrollToToday(),
            tooltip: 'Go to Today',
            child: const Icon(Icons.today_rounded),
          ),
        ),

        // Sticky month/year header
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildStickyMonthHeader(context),
        ),
      ],
    );
  }

  Widget _buildStickyMonthHeader(BuildContext context) {
    final monthFormat = DateFormat('MMMM yyyy');

    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              monthFormat.format(_currentVisibleMonth),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: context.colors.onSurface.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual date item in the schedule view
class _ScheduleDateItem extends ConsumerWidget {
  final DateTime date;
  final bool isToday;

  const _ScheduleDateItem({required this.date, required this.isToday});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateDataAsync = ref.watch(scheduleDateDataProvider(date));

    return dateDataAsync.when(
      data: (dateData) => _buildDateRow(context, ref, dateData),
      loading: () => _buildLoadingRow(context),
      error: (error, _) => _buildErrorRow(context, error),
    );
  }

  Widget _buildDateRow(
    BuildContext context,
    WidgetRef ref,
    ScheduleDateData dateData,
  ) {
    final panchang = dateData.panchang;
    final monthFormat = DateFormat('MMM');
    final dayFormat = DateFormat('d');
    final weekdayFormat = DateFormat('EEE');

    final hasEvents = panchang.hasFestivals;
    final bengaliDate = dateData.bengaliDate;
    final hinduDate = dateData.hinduDate;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: isToday
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.colors.primary.withValues(alpha: 0.5),
                width: 2,
              ),
            )
          : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Column (Left side)
            _buildDateColumn(
              context,
              ref,
              monthFormat.format(date).toUpperCase(),
              dayFormat.format(date),
              weekdayFormat.format(date),
              panchang,
              bengaliDate,
              hinduDate,
            ),

            // Vertical divider
            Container(
              width: 1,
              color: context.colors.onSurface.withValues(alpha: 0.1),
              margin: const EdgeInsets.symmetric(vertical: 8),
            ),

            // Events Column (Right side)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: hasEvents
                    ? _buildEventsList(context, ref, panchang)
                    : _buildPanchangOnly(context, ref, panchang),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateColumn(
    BuildContext context,
    WidgetRef ref,
    String gregorianMonth,
    String gregorianDay,
    String weekday,
    PanchangData panchang,
    ({int day, String month, int year})? bengaliDate,
    HinduDateData? hinduDate,
  ) {
    final primarySystem = ref.watch(cp.primaryCalendarSystemProvider);
    final secondarySystem = ref.watch(cp.secondaryCalendarSystemProvider);
    // Display settings for the panchang-data fallback below (Amanta values
    // converted at render; Shukla days are identical in both systems).
    final monthSystem = ref.watch(cp.hinduMonthSystemProvider);
    final tithiMode = ref.watch(cp.tithiDisplayModeProvider);

    // Determine what to show based on primary calendar system
    String primaryMonth;
    String primaryDay;
    String? secondaryText;

    if (primarySystem == cp.AppCalendarSystem.bengali) {
      // Bengali as primary: show Bengali month and day
      if (bengaliDate != null) {
        primaryMonth = bengaliDate.month
            .substring(0, bengaliDate.month.length.clamp(0, 4))
            .toUpperCase();
        primaryDay = '${bengaliDate.day}';
      } else {
        // Fallback to Gregorian if Bengali calculation not ready
        primaryMonth = gregorianMonth;
        primaryDay = gregorianDay;
      }

      // Show secondary based on selection
      if (secondarySystem == cp.AppCalendarSystem.gregorian) {
        secondaryText = '$gregorianMonth $gregorianDay';
      } else if (secondarySystem == cp.AppCalendarSystem.hindu &&
          hinduDate != null) {
        secondaryText = '${hinduDate.paksha[0]}${hinduDate.day}';
      }
    } else if (primarySystem == cp.AppCalendarSystem.hindu) {
      // Hindu as primary: show masa and tithi with proper settings
      if (hinduDate != null) {
        primaryMonth = hinduDate.month
            .split(' ')
            .last
            .substring(0, hinduDate.month.split(' ').last.length.clamp(0, 4))
            .toUpperCase();
        primaryDay = '${hinduDate.day}';
      } else {
        // Fallback to panchang data (Amanta) with display settings applied.
        final fallbackMasa = displayMasaName(
          panchang.masa,
          panchang.paksha,
          monthSystem,
        );
        primaryMonth = panchang.masa.isNotEmpty
            ? fallbackMasa
                  .replaceAll('_', ' ')
                  .split(' ')
                  .last
                  .substring(
                    0,
                    fallbackMasa.split('_').last.length.clamp(0, 4),
                  )
                  .toUpperCase()
            : gregorianMonth;
        primaryDay =
            '${tithiMode == cp.TithiDisplayMode.continuous30 ? panchang.tithiIndex : panchang.tithiNumber}';
      }

      // Show secondary based on selection
      if (secondarySystem == cp.AppCalendarSystem.gregorian) {
        secondaryText = '$gregorianMonth $gregorianDay';
      } else if (secondarySystem == cp.AppCalendarSystem.bengali &&
          bengaliDate != null) {
        secondaryText =
            '${bengaliDate.month.substring(0, 3)} ${bengaliDate.day}';
      }
    } else {
      // Gregorian as primary
      primaryMonth = gregorianMonth;
      primaryDay = gregorianDay;

      // Show secondary based on selection
      if (secondarySystem == cp.AppCalendarSystem.hindu && hinduDate != null) {
        // Show paksha initial + tithi number with month abbr
        final pakshaInitial = hinduDate.paksha == 'Shukla' ? 'श' : 'क';
        secondaryText =
            '${hinduDate.month.substring(0, 3)} $pakshaInitial${hinduDate.day}';
      } else if (secondarySystem == cp.AppCalendarSystem.bengali &&
          bengaliDate != null) {
        // Show Bengali date as secondary
        secondaryText =
            '${bengaliDate.month.substring(0, 3)} ${bengaliDate.day}';
      }
    }

    final hasSecondary = secondaryText != null;

    return Container(
      width: hasSecondary ? 75 : 60,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            primaryMonth,
            style: context.textTheme.labelSmall?.copyWith(
              color: isToday
                  ? context.colors.primary
                  : context.colors.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            primaryDay,
            style: context.textTheme.headlineMedium?.copyWith(
              color: isToday
                  ? context.colors.primary
                  : context.colors.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            weekday,
            style: context.textTheme.labelSmall?.copyWith(
              color: isToday
                  ? context.colors.primary
                  : context.colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          // Secondary calendar info
          if (hasSecondary) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: context.colors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                secondaryText,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colors.secondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventsList(
    BuildContext context,
    WidgetRef ref,
    PanchangData panchang,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Panchang summary row
        _buildPanchangSummaryRow(context, panchang),
        // Sunrise/Sunset times
        _buildSunTimesRow(context, panchang),
        const SizedBox(height: 8),
        // Festival cards
        ...panchang.festivals.map(
          (festival) => _buildFestivalCard(context, ref, festival, panchang),
        ),
      ],
    );
  }

  Widget _buildPanchangOnly(
    BuildContext context,
    WidgetRef ref,
    PanchangData panchang,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPanchangSummaryRow(context, panchang),
        _buildSunTimesRow(context, panchang),
      ],
    );
  }

  Widget _buildPanchangSummaryRow(BuildContext context, PanchangData panchang) {
    final isShukla = panchang.isShukla;

    return Row(
      children: [
        Icon(
          isShukla ? Icons.brightness_high_rounded : Icons.nights_stay_rounded,
          size: 16,
          color: context.colors.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${panchang.paksha} ${panchang.tithiName}',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${panchang.tithiNumber}',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds sunrise/sunset time row
  Widget _buildSunTimesRow(BuildContext context, PanchangData panchang) {
    final l10n = AppLocalizations.of(context)!;
    final timeFormat = DateFormat('h:mm a');

    if (panchang.sunrise == null && panchang.sunset == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          if (panchang.sunrise != null) ...[
            Semantics(
              label: l10n.sunrise,
              child: Icon(
                Icons.wb_sunny_outlined,
                size: 14,
                color: context.colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${l10n.sunrise}: ${timeFormat.format(panchang.sunrise!)}',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
          if (panchang.sunrise != null && panchang.sunset != null)
            const SizedBox(width: 12),
          if (panchang.sunset != null) ...[
            Semantics(
              label: l10n.sunset,
              child: Icon(
                Icons.nightlight_round,
                size: 14,
                color: context.colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${l10n.sunset}: ${timeFormat.format(panchang.sunset!)}',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFestivalCard(
    BuildContext context,
    WidgetRef ref,
    dynamic festival,
    PanchangData panchang,
  ) {
    final isMajor = festival.category == 'major';

    return GestureDetector(
      onTap: () {
        if (ref.read(accessibilityProvider).hapticFeedback) {
          HapticFeedback.selectionClick();
        }
        _showFestivalDetail(context, festival, panchang);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.glassmorphism(
          context: context,
          opacity: isMajor ? 0.25 : 0.15,
          borderRadius: 12,
          ref: ref,
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: isMajor
                    ? context.colors.primary
                    : context.colors.secondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    festival.name,
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (festival.description.isNotEmpty)
                    Text(
                      festival.description,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              isMajor ? Icons.celebration_rounded : Icons.event_rounded,
              size: 20,
              color: context.colors.primary.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  void _showFestivalDetail(
    BuildContext context,
    dynamic festival,
    PanchangData panchang,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          EventDetailSheet(festival: festival, panchang: panchang),
    );
  }

  Widget _buildLoadingRow(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: context.colors.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorRow(BuildContext context, Object error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      child: Text(
        'Error: $error',
        style: TextStyle(color: context.colors.error),
      ),
    );
  }
}
