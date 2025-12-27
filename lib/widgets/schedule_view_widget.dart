import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/panchang_data.dart';
import '../providers/panchang_provider.dart';
import '../providers/accessibility_provider.dart';
import '../theme/app_theme.dart';
import 'event_detail_sheet.dart';

/// Schedule View Widget - displays events in a vertical scrollable list
/// similar to Google Calendar's Schedule view
class ScheduleViewWidget extends ConsumerStatefulWidget {
  const ScheduleViewWidget({super.key});

  @override
  ConsumerState<ScheduleViewWidget> createState() => _ScheduleViewWidgetState();
}

class _ScheduleViewWidgetState extends ConsumerState<ScheduleViewWidget> {
  final ScrollController _scrollController = ScrollController();
  late List<DateTime> _dates;

  // Initial range
  final int _initialDaysBefore = 30;
  final int _initialDaysAfter = 90;

  // How many days to load when reaching edges
  final int _loadMoreDays = 60;

  // Threshold to trigger loading more (in pixels from edge)
  final double _loadThreshold = 500;

  // Track the earliest and latest date in our list
  late DateTime _earliestDate;
  late DateTime _latestDate;

  // Track "today" for FAB scroll
  late DateTime _today;

  // Loading states
  bool _isLoadingPast = false;
  bool _isLoadingFuture = false;

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _scrollController.addListener(_onScroll);

    // Scroll to today after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday(animated: false);
    });
  }

  void _initializeDates() {
    _today = DateTime.now();
    _earliestDate = DateTime(
      _today.year,
      _today.month,
      _today.day - _initialDaysBefore,
    );
    _latestDate = DateTime(
      _today.year,
      _today.month,
      _today.day + _initialDaysAfter,
    );

    _rebuildDateList();
  }

  void _rebuildDateList() {
    final dayCount = _latestDate.difference(_earliestDate).inDays + 1;
    _dates = List.generate(
      dayCount,
      (index) => DateTime(
        _earliestDate.year,
        _earliestDate.month,
        _earliestDate.day + index,
      ),
    );
  }

  void _onScroll() {
    final position = _scrollController.position;

    // Load more past dates when near the top
    if (position.pixels < _loadThreshold && !_isLoadingPast) {
      _loadMorePastDates();
    }

    // Load more future dates when near the bottom
    if (position.maxScrollExtent - position.pixels < _loadThreshold &&
        !_isLoadingFuture) {
      _loadMoreFutureDates();
    }
  }

  void _loadMorePastDates() {
    setState(() {
      _isLoadingPast = true;
    });

    // Calculate new earliest date
    final newEarliestDate = DateTime(
      _earliestDate.year,
      _earliestDate.month,
      _earliestDate.day - _loadMoreDays,
    );

    // Remember current scroll position relative to today
    final todayIndex = _getTodayIndex();
    final currentOffset = _scrollController.offset;
    final approximateItemHeight = todayIndex > 0
        ? currentOffset / todayIndex
        : 100.0;

    _earliestDate = newEarliestDate;
    _rebuildDateList();

    setState(() {
      _isLoadingPast = false;
    });

    // Adjust scroll position to maintain visual position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newOffset = currentOffset + (_loadMoreDays * approximateItemHeight);
      _scrollController.jumpTo(
        newOffset.clamp(0, _scrollController.position.maxScrollExtent),
      );
    });
  }

  void _loadMoreFutureDates() {
    setState(() {
      _isLoadingFuture = true;
    });

    // Calculate new latest date
    final newLatestDate = DateTime(
      _latestDate.year,
      _latestDate.month,
      _latestDate.day + _loadMoreDays,
    );

    _latestDate = newLatestDate;
    _rebuildDateList();

    setState(() {
      _isLoadingFuture = false;
    });
  }

  int _getTodayIndex() {
    return _dates.indexWhere((date) => _isToday(date));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToToday({bool animated = true}) {
    final todayIndex = _getTodayIndex();
    if (todayIndex < 0) return;

    // Estimate item height (each item is roughly 80-120 pixels)
    final estimatedItemHeight = 100.0;
    final targetOffset = todayIndex * estimatedItemHeight;

    if (animated && _scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else if (_scrollController.hasClients) {
      _scrollController.jumpTo(
        targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _dates.length,
          itemBuilder: (context, index) {
            final date = _dates[index];
            return _ScheduleDateItem(date: date, isToday: _isToday(date));
          },
        ),
        // Floating Action Button to scroll to today
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'schedule_today_fab',
            onPressed: () => _scrollToToday(animated: true),
            tooltip: 'Go to Today',
            child: const Icon(Icons.today_rounded),
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    return date.year == _today.year &&
        date.month == _today.month &&
        date.day == _today.day;
  }
}

/// Individual date item in the schedule view
class _ScheduleDateItem extends ConsumerWidget {
  final DateTime date;
  final bool isToday;

  const _ScheduleDateItem({required this.date, required this.isToday});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panchangAsync = ref.watch(panchangForDateProvider(date));

    return panchangAsync.when(
      data: (panchang) => _buildDateRow(context, ref, panchang),
      loading: () => _buildLoadingRow(context),
      error: (error, _) => _buildErrorRow(context, error),
    );
  }

  Widget _buildDateRow(
    BuildContext context,
    WidgetRef ref,
    PanchangData panchang,
  ) {
    final monthFormat = DateFormat('MMM');
    final dayFormat = DateFormat('d');
    final weekdayFormat = DateFormat('EEE');

    final hasEvents = panchang.hasFestivals;

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
              monthFormat.format(date).toUpperCase(),
              dayFormat.format(date),
              weekdayFormat.format(date),
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
    String month,
    String day,
    String weekday,
  ) {
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            month,
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
            day,
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
    return _buildPanchangSummaryRow(context, panchang);
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
            'T${panchang.tithiNumber}',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
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
