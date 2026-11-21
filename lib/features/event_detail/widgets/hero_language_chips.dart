import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_theme.dart';
import '../../sheets/widgets/sheet_chip.dart';
import '../providers/event_detail_providers.dart';

/// Collapsible hero language chips (shared pill style): collapsed shows
/// only the first chip row with an expand chevron, expanded shows every
/// regional name with a collapse chevron. The chevron sits in its own
/// right-aligned row below the full-width chips. Single-row sets render
/// bare — no chevron when there is nothing to reveal.
///
/// The first row is measured, not guessed: each chip carries a key and a
/// post-frame pass groups them by vertical position, so the clipped height
/// matches the real chip height on any screen width, font scale or locale.
/// Before the first measurement the full row renders unclipped (safe
/// fallback — nothing is ever hidden without a toggle).
class HeroLanguageChips extends ConsumerStatefulWidget {
  const HeroLanguageChips({
    super.key,
    required this.chips,
    required this.highContrast,
  });

  final List<String> chips;
  final bool highContrast;

  @override
  ConsumerState<HeroLanguageChips> createState() => _HeroLanguageChipsState();
}

class _HeroLanguageChipsState extends ConsumerState<HeroLanguageChips> {
  late List<GlobalKey> _chipKeys = [for (final _ in widget.chips) GlobalKey()];
  bool _measured = false;
  int _measureAttempts = 0;
  int _firstRowCount = 0;
  double? _firstRowHeight;

  bool get _multiRow => _measured && _firstRowCount < widget.chips.length;

  @override
  void didUpdateWidget(covariant HeroLanguageChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chips.length != widget.chips.length) {
      _chipKeys = [for (final _ in widget.chips) GlobalKey()];
      _measured = false;
      _measureAttempts = 0;
      _firstRowCount = 0;
      _firstRowHeight = null;
    }
    _scheduleMeasure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-runs on width/text-scale changes too, so rotation or a larger
    // accessibility font re-groups the rows instead of going stale.
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  double? _globalDy(RenderBox box) {
    try {
      return box.localToGlobal(Offset.zero).dy;
    } catch (_) {
      return null;
    }
  }

  void _measure() {
    if (!mounted || widget.chips.isEmpty) return;
    if (_chipKeys.length != widget.chips.length) return;
    final firstBox =
        _chipKeys.first.currentContext?.findRenderObject() as RenderBox?;
    if (firstBox == null || !firstBox.hasSize) {
      _retryLater();
      return;
    }
    final firstDy = _globalDy(firstBox);
    if (firstDy == null) {
      _retryLater();
      return;
    }
    var count = 0;
    for (final key in _chipKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        _retryLater();
        return;
      }
      final dy = _globalDy(box);
      if (dy == null) {
        _retryLater();
        return;
      }
      // Chips sharing the first row sit on the same baseline (1px
      // tolerance for rounding); the first chip on a lower row ends it.
      if ((dy - firstDy).abs() > 1.0) break;
      count++;
    }
    if (!_measured ||
        count != _firstRowCount ||
        firstBox.size.height != _firstRowHeight) {
      setState(() {
        _measured = true;
        _firstRowCount = count;
        _firstRowHeight = firstBox.size.height;
      });
    }
  }

  void _retryLater() {
    // Layout may lag a frame behind (sheet entry animation); retry a few
    // frames before giving up and leaving the full row visible.
    if (_measured || _measureAttempts >= 5 || !mounted) return;
    _measureAttempts++;
    _scheduleMeasure();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chips.isEmpty) return const SizedBox.shrink();
    final expanded = ref.watch(heroChipsExpandedProvider);
    final l10n = AppLocalizations.of(context);
    // Toggle ink matches the hero titles (primary is unreadable on the
    // peach gradient in light mode — same call as ObservanceCaption).
    final ink = widget.highContrast
        ? context.colors.primary
        : AppTheme.heroForeground(context);

    Wrap chipsWrap() {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        // Clip the paint instead of overflowing: the SizedBox below caps
        // the height at exactly one row.
        clipBehavior: Clip.hardEdge,
        children: [
          for (var i = 0; i < widget.chips.length; i++)
            SheetChip(
              key: _chipKeys[i],
              icon: Icons.translate,
              text: widget.chips[i],
              highContrast: widget.highContrast,
            ),
        ],
      );
    }

    // Chevron pinned to the right side of the chips row (no text label).
    // The existing translations/less strings serve as the tooltip so the
    // icon-only button stays localized and screen-reader friendly.
    Widget arrowButton({required bool isExpanded}) {
      return IconButton(
        onPressed: () =>
            ref.read(heroChipsExpandedProvider.notifier).state = !isExpanded,
        icon: Icon(
          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: ink,
          size: AppIconSize.medium,
        ),
        tooltip: isExpanded
            ? (l10n?.showLess ?? 'Show less')
            : (l10n?.showMoreTranslations ?? 'Show more translations'),
        style: IconButton.styleFrom(
          foregroundColor: ink,
          padding: EdgeInsets.zero,
          minimumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    // Chips always take the full width; the chevron lives in its own
    // right-aligned row below. (Parking the arrow beside the Wrap would
    // reserve a strip on the right of every row and squeeze the chips
    // left.) Single-row sets render bare with no arrow.
    final showToggle = _multiRow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.s14),
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.standard),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: showToggle && !expanded
              // Collapsed multi-row: first row only, clipped at the
              // measured chip height plus a 2px buffer so the bottom
              // border isn't cut by anti-aliasing (still well under the
              // 8px runSpacing, so the second row stays hidden). Clip is
              // paint-only, so the hidden chips still lay out and the row
              // grouping above stays valid.
              ? SizedBox(height: (_firstRowHeight ?? 0) + 2, child: chipsWrap())
              : chipsWrap(),
        ),
        if (showToggle)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [arrowButton(isExpanded: expanded)],
          ),
      ],
    );
  }
}
