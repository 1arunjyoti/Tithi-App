import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/tithi_localization.dart';
import '../domain/schedule_scroll.dart';
import 'schedule_date_item.dart';

/// Schedule View Widget - displays events in a vertical scrollable list
/// similar to Google Calendar's Schedule view.
/// Uses a CustomScrollView with center key for stable scroll anchoring.
///
/// This file owns the scroll shell (anchor day, bidirectional day range,
/// sticky month header, today FAB). A row is [ScheduleDateItem]; the day's
/// content is [ScheduleDayContent]; the scroll maths are in
/// `features/schedule/domain/schedule_scroll.dart`.
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
    final visibleDate = scheduleVisibleDate(_anchorDate, position.pixels);
    if (!scheduleMonthChanged(_currentVisibleMonth, visibleDate)) return;

    setState(() {
      _currentVisibleMonth = visibleDate;
    });

    // Update focused month provider (for sync with calendar view)
    Future.microtask(() {
      if (mounted) {
        cp.setCalendarMonth(ref, visibleDate);
      }
    });
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
    // Reduce Motion skips smooth scrolling and jumps instantly.
    final reduceMotion = AppTheme.reduceMotionOf(context);
    // Use jump logic if we need to re-anchor
    final difference = now.difference(_anchorDate).inDays;

    if (difference.abs() > 180) {
      _jumpToDate(now);
      return;
    }

    if (difference == 0 && _scrollController.hasClients) {
      if (animated && !reduceMotion) {
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
    final picked = await M3EDatePicker.show(
      context,
      initialDate: _currentVisibleMonth,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      // Update selected date provider which triggers the listener
      ref.read(cp.selectedDateProvider.notifier).setDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                  ),
                  child: ScheduleDateItem(
                    date: scheduleDayAt(_anchorDate, -daysAgo),
                    isToday: false,
                  ),
                );
              }, childCount: _daysBefore),
            ),

            // Today (center anchor)
            SliverToBoxAdapter(
              key: _centerKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s8,
                ),
                child: ScheduleDateItem(date: _anchorDate, isToday: true),
              ),
            ),

            // Future dates (builds downward from today)
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                // index 0 = tomorrow, index 1 = 2 days from now, etc.
                final daysAhead = index + 1;
                if (daysAhead > _daysAfter) return null;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                  ),
                  child: ScheduleDateItem(
                    date: scheduleDayAt(_anchorDate, daysAhead),
                    isToday: false,
                  ),
                );
              }, childCount: _daysAfter),
            ),

            // The scroll view draws behind the gesture handle, so the last day
            // needs its own padding to stay scrollable clear of it.
            SliverToBoxAdapter(
              child: SizedBox(
                height: 24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
            ),
          ],
        ),

        // Floating Action Button to scroll to today
        Positioned(
          bottom: 16,
          right: 16,
          child: M3EFab(
            icon: const Icon(Icons.today_rounded),
            size: M3EFabSize.small,
            onPressed: () => _scrollToToday(),
            tooltip: l10n?.goToToday ?? 'Go to Today',
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
    // Cached formatter (not a per-build DateFormat construction): this
    // header rebuilds on every scroll offset change.
    final monthLabel = formatLocalizedDate(
      _currentVisibleMonth,
      'MMMM yyyy',
      Localizations.localeOf(context).languageCode,
    );

    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s8,
        ),
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
              monthLabel,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: AppTypography.bold,
                color: context.colors.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
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
