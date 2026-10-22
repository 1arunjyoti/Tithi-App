import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_messages.dart';
import '../../../core/format/date_only.dart';
import '../../../core/format/festival_labels.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../models/festival.dart';
import '../../../models/hindu_month_system.dart';
import '../../../models/panchang_data.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/panchang_provider.dart';
import '../../../services/ai_handoff_service.dart'
    show AiHandoffOutcome, AiHandoffService;
import '../../../services/auspicious_timings.dart';
import '../../../services/inauspicious_timings.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/tithi_localization.dart';
import '../../calendar/data/calendar_caches.dart' show normalizeMonthKey;
import '../../sheets/widgets/section_header.dart';
import '../../sheets/widgets/sheet_explainer_card.dart';
import '../../sheets/widgets/sheet_hero_tile.dart';
import '../../sheets/widgets/sheet_scaffold.dart';
import '../../sheets/widgets/sheet_surface_card.dart';
import '../domain/ai_app_target.dart';
import '../domain/ai_context.dart';
import '../domain/ai_prompt.dart';
import '../providers/ai_providers.dart';

/// Opens the "ask your AI app" sheet.
///
/// Only reachable while [aiAssistEnabledProvider] is on - every entry point
/// checks that first, so the sheet itself assumes opt-in consent.
Future<void> showAskAiSheet(
  BuildContext context, {
  required AiIntent intent,
  PanchangData? panchang,
  Festival? festival,
  DateTime? month,
  AuspiciousTimings? timings,
  InauspiciousTimings? inauspicious,
}) async {
  assert(
    intent != AiIntent.todayPanchang || panchang != null,
    'AiIntent.todayPanchang needs the day\'s panchang',
  );
  assert(
    intent != AiIntent.festival || festival != null,
    'AiIntent.festival needs the festival it is about',
  );
  await showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: AppTheme.sheetAnimationStyleOf(context),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AskAiSheet(
      intent: intent,
      panchang: panchang,
      festival: festival,
      month: month,
      timings: timings,
      inauspicious: inauspicious,
    ),
  );
}

/// Preview + hand-off sheet for the chosen [AiIntent].
///
/// Shows the user exactly what will leave the device, lets them edit the
/// question, and offers two exits: the system share sheet (whichever AI app
/// they use) or a plain clipboard copy. Tithi never sends anything itself.
class AskAiSheet extends ConsumerStatefulWidget {
  const AskAiSheet({
    super.key,
    required this.intent,
    this.panchang,
    this.festival,
    this.month,
    this.timings,
    this.inauspicious,
  });

  final AiIntent intent;
  final PanchangData? panchang;
  final Festival? festival;
  final DateTime? month;

  /// Auspicious windows for [panchang]'s day, when the caller already computed
  /// them (the tithi sheet does). Optional: the payload simply omits them.
  final AuspiciousTimings? timings;

  /// Rahu Kalam, Yamaganda and Gulika Kalam for the same day. Optional, same
  /// rule as [timings].
  final InauspiciousTimings? inauspicious;

  @override
  ConsumerState<AskAiSheet> createState() => _AskAiSheetState();
}

/// Everything the preview payload is built from, apart from the question.
///
/// Typed so the memo in [_AskAiSheetState] stays honest: adding an input to the
/// payload without adding it here fails to compile at the construction site.
typedef _PayloadKey = ({
  AiIntent intent,
  String city,
  String timeZone,
  HinduMonthSystem monthSystem,
  DateTime month,
  PanchangData? panchang,
  Festival? festival,
  AuspiciousTimings? timings,
  InauspiciousTimings? inauspicious,
  Map<DateTime, PanchangData>? monthDays,
});

class _AskAiSheetState extends ConsumerState<AskAiSheet> {
  final TextEditingController _question = TextEditingController();
  bool _seededQuestion = false;
  bool _showFullPreview = false;

  /// Shows the assembled message instead of the data block, so "the preview"
  /// can be checked against what the intent actually carries (instructions,
  /// the question line and the answer-language line included).
  bool _showFullPrompt = false;

  /// Memoised payload for the preview (see `build`): a keystroke changes only
  /// the question, so the context block is rebuilt only when one of these
  /// inputs does. The record compares members with `==`, i.e. by value for the
  /// strings and the date and by identity for the data objects - which is what
  /// we want, since a new instance only arrives when the underlying data moved.
  _PayloadKey? _contextKey;
  String _contextBlock = '';
  int _contextLineCount = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededQuestion) return;
    _seededQuestion = true;
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final seed = switch (widget.intent) {
      AiIntent.todayPanchang => l10n.aiDefaultQuestionToday,
      AiIntent.festival => l10n.aiDefaultQuestionFestival,
      AiIntent.monthDigest => l10n.aiDefaultQuestionMonth,
    };
    // The actions capture the assembled prompt, so a rebuild per keystroke is
    // what keeps the edited question (and only the edited question) in it.
    _question
      ..text = seed
      ..selection = TextSelection.collapsed(offset: seed.length)
      ..addListener(_onQuestionChanged);
  }

  void _onQuestionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final highContrast = AppTheme.highContrastOf(context);
    final localeCode = l10n.localeName;

    // City only - the AI never receives coordinates. `cityNameProvider`
    // resolves from the same location record the panchang used, so the two
    // cannot disagree about where the numbers came from.
    final city = ref.watch(cityNameProvider).valueOrNull ?? 'your city';
    final timeZone =
        ref.watch(aiDeviceTimeZoneProvider).valueOrNull ?? 'Asia/Kolkata';
    // The masa name is only meaningful together with the system that produced
    // it (Amanta vs Purnimant), so the payload states both.
    final monthSystem = ref.watch(hinduMonthSystemProvider);
    final targetId = ref.watch(aiTargetAppProvider);
    // Off Android there is no package-targeted intent, so the hand-off is the
    // share sheet and the button must not promise a named app.
    final selectedTarget = ref.watch(aiDirectOpenSupportedProvider)
        ? aiTargetById(targetId)
        : null;

    // Month-normalized on purpose: `focusedMonthProvider` is not itself
    // normalized (it starts as `DateTime.now()` and swipes store the day the
    // pager landed on), while `monthlyPanchangProvider` keys its family on the
    // argument verbatim. A raw value would start a second full-month
    // computation next to the calendar's instead of joining it - and, because
    // each `DateTime.now()` differs, one more instance per open.
    final month = normalizeMonthKey(widget.month ?? DateTime.now());
    final monthState = widget.intent == AiIntent.monthDigest
        ? ref.watch(monthlyPanchangProvider(month))
        : null;
    final monthDays = monthState?.valueOrNull;
    final monthFailed = monthState?.hasError ?? false;
    final isReady = widget.intent != AiIntent.monthDigest || monthDays != null;

    final contextKey = (
      intent: widget.intent,
      city: city,
      timeZone: timeZone,
      monthSystem: monthSystem,
      month: month,
      panchang: widget.panchang,
      festival: widget.festival,
      timings: widget.timings,
      inauspicious: widget.inauspicious,
      monthDays: monthDays,
    );
    if (contextKey != _contextKey) {
      _contextKey = contextKey;
      _contextBlock = switch (widget.intent) {
        AiIntent.todayPanchang => buildDayContext(
          panchang: widget.panchang!,
          city: city,
          timeZone: timeZone,
          monthSystem: monthSystem,
          timings: widget.timings,
          inauspicious: widget.inauspicious,
          heading: isSameDay(widget.panchang!.date, DateTime.now())
              ? "Today's panchang (calculated offline by Tithi)"
              : 'Panchang (calculated offline by Tithi)',
        ),
        AiIntent.festival => buildFestivalContext(
          festival: widget.festival!,
          panchang: widget.panchang,
          city: city,
          timeZone: timeZone,
          monthSystem: monthSystem,
        ),
        AiIntent.monthDigest => buildMonthContext(
          month: month,
          days: monthDays?.values ?? const <PanchangData>[],
          city: city,
          timeZone: timeZone,
        ),
      };
      _contextLineCount = '\n'.allMatches(_contextBlock).length + 1;
    }
    final contextBlock = _contextBlock;

    final prompt = buildAiPrompt(
      intent: widget.intent,
      context: contextBlock,
      languageName: aiLanguageName(localeCode),
      question: isReady ? _question.text : null,
    );
    final showPrompt = _showFullPrompt && isReady;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SheetScaffold(
        highContrast: highContrast,
        hero: _buildHero(context, l10n, highContrast, localeCode, city, month),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(text: l10n.aiYourQuestion),
            const SizedBox(height: 10),
            SheetSurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: TextField(
                controller: _question,
                minLines: 2,
                maxLines: 4,
                maxLength: 280,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                  color: context.colors.onSurface,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                  hintText: l10n.aiQuestionHint,
                  // The counter is visual noise inside a sheet; the hard cap
                  // still applies.
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Expanded: at large text scales the label and "Show all"
                // cannot both take their intrinsic width.
                Expanded(
                  child: SectionHeader(text: l10n.aiWhatWillBeShared),
                ),
                if (!showPrompt && isReady && _contextLineCount > 6)
                  TextButton(
                    onPressed: () =>
                        setState(() => _showFullPreview = !_showFullPreview),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      _showFullPreview ? l10n.aiHidePreview : l10n.aiShowAll,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SheetSurfaceCard(
              child: _PreviewBody(
                text: showPrompt
                    ? prompt
                    : isReady
                    ? contextBlock
                    : monthFailed
                    ? l10n.aiMonthFailed
                    : l10n.aiPreparing,
                expanded: showPrompt || _showFullPreview,
              ),
            ),
            // The data block is only part of the message: say so, so "what
            // will be shared" is not mistaken for "everything that is sent".
            if (!showPrompt) ...[
              const SizedBox(height: 6),
              Text(
                l10n.aiAlsoSends,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: context.colors.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
            if (isReady)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _showFullPrompt = !_showFullPrompt;
                    _showFullPreview = false;
                  }),
                  icon: Icon(
                    showPrompt
                        ? Icons.short_text_rounded
                        : Icons.receipt_long_outlined,
                    size: 16,
                  ),
                  label: Text(
                    showPrompt ? l10n.aiPreviewSummary : l10n.aiPreviewFull,
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            // A failed month computation used to leave the sheet on
            // "Preparing..." forever with both actions disabled. Say what went
            // wrong and offer the one action that can recover it.
            if (monthFailed) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () =>
                    ref.invalidate(monthlyPanchangProvider(month)),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.retry),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
            const SizedBox(height: 10),
            SheetExplainerCard(
              icon: Icons.lock_outline_rounded,
              text: l10n.aiLocationNote,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isReady
                        ? () => _openAiApp(prompt, targetId)
                        : null,
                    icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                    label: Text(
                      selectedTarget == null
                          ? l10n.aiOpenApp
                          : l10n.aiOpenInApp(selectedTarget.label),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isReady ? () => _copyPrompt(prompt) : null,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(l10n.aiCopy),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SheetExplainerCard(
              icon: Icons.auto_awesome_outlined,
              text: l10n.aiFooterNote,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(
    BuildContext context,
    AppLocalizations l10n,
    bool highContrast,
    String localeCode,
    String city,
    DateTime month,
  ) {
    final title = switch (widget.intent) {
      AiIntent.todayPanchang => l10n.aiTitleToday,
      AiIntent.festival => festivalDisplayName(
        festival: widget.festival!,
        locale: localeCode,
      ),
      AiIntent.monthDigest => l10n.aiTitleMonth,
    };

    final dateLine = switch (widget.intent) {
      AiIntent.todayPanchang => formatLocalizedDate(
        widget.panchang!.date,
        'EEE, d MMM',
        localeCode,
      ),
      AiIntent.festival => widget.panchang == null
          ? null
          : formatLocalizedDate(widget.panchang!.date, 'EEE, d MMM', localeCode),
      AiIntent.monthDigest => formatLocalizedDate(month, 'MMMM y', localeCode),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SheetHeroTile(
              highContrast: highContrast,
              child: Icon(
                Icons.auto_awesome_outlined,
                size: 22,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [dateLine, city].whereType<String>().join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: context.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Pops first so the target app (or chooser) is not competing with the
  /// sheet, then reports the outcome through the captured messenger.
  Future<void> _openAiApp(String prompt, String targetId) async {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final messenger = ScaffoldMessenger.of(context);
    final colors = Theme.of(context).colorScheme;
    // Both outlive the pop: the messenger is app-level and the navigator hosts
    // the fallback dialog.
    final navigator = Navigator.of(context);
    // Resolve the service before popping: this widget is disposed with the
    // sheet, and `ref` is not usable afterwards.
    final handoff = ref.read(aiHandoffServiceProvider);
    const subject = 'Tithi';

    Navigator.of(context).pop();

    final result = await handoff.openAiApp(
      prompt: prompt,
      preferredAppId: targetId,
      subject: subject,
    );

    switch (result.outcome) {
      case AiHandoffOutcome.openedApp:
      case AiHandoffOutcome.openedChooser:
        // The app (or chooser) is on screen; it explains itself.
        return;
      case AiHandoffOutcome.appUnavailable:
        final missing = result.missingApp;
        if (missing == null || !navigator.mounted) return;
        await _confirmShareFallback(
          navigator: navigator,
          handoff: handoff,
          l10n: l10n,
          messenger: messenger,
          colors: colors,
          prompt: prompt,
          subject: subject,
          appLabel: missing.label,
        );
        return;
      case AiHandoffOutcome.failed:
        // Nothing opened and the sheet is gone: put the prompt somewhere it
        // survives instead of leaving the user with only an error.
        final copied = await handoff.copyPrompt(prompt);
        if (!navigator.mounted) return;
        showAppMessageOn(
          messenger,
          colors,
          copied ? l10n.aiShareFailedCopied : l10n.aiShareFailed,
          kind: AppMessageKind.error,
        );
        return;
    }
  }

  /// The chosen app could not take the prompt. Ask before replacing it with
  /// the share sheet: a chooser that appears on its own looks like the app
  /// choice was ignored.
  Future<void> _confirmShareFallback({
    required NavigatorState navigator,
    required AiHandoffService handoff,
    required AppLocalizations l10n,
    required ScaffoldMessengerState messenger,
    required ColorScheme colors,
    required String prompt,
    required String subject,
    required String appLabel,
  }) async {
    final choice = await showDialog<_FallbackChoice>(
      context: navigator.context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.aiAppUnavailable(appLabel)),
        content: Text(l10n.aiAppUnavailableBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_FallbackChoice.copy),
            child: Text(l10n.aiCopy),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_FallbackChoice.share),
            child: Text(l10n.aiOpenShareSheet),
          ),
        ],
      ),
    );
    if (choice == null || !navigator.mounted) return;

    if (choice == _FallbackChoice.copy) {
      final copied = await handoff.copyPrompt(prompt);
      if (!navigator.mounted) return;
      showAppMessageOn(
        messenger,
        colors,
        copied ? l10n.aiCopied : l10n.aiCopyFailed,
        kind: copied ? AppMessageKind.success : AppMessageKind.error,
      );
      return;
    }

    final shared = await handoff.openShareSheet(
      prompt: prompt,
      subject: subject,
    );
    if (shared || !navigator.mounted) return;
    showAppMessageOn(
      messenger,
      colors,
      l10n.aiShareFailed,
      kind: AppMessageKind.error,
    );
  }

  Future<void> _copyPrompt(String prompt) async {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final copied = await ref.read(aiHandoffServiceProvider).copyPrompt(prompt);
    if (!mounted) return;
    showAppMessage(
      context,
      copied ? l10n.aiCopied : l10n.aiCopyFailed,
      kind: copied ? AppMessageKind.success : AppMessageKind.error,
    );
  }
}

/// What the user picked when the chosen AI app could not take the prompt.
enum _FallbackChoice { copy, share }

/// The payload preview: six lines collapsed, and a bounded scroll area when
/// expanded.
///
/// A month digest can run past thirty lines (one per festival). Letting the
/// expanded text grow inline would push the Open/Copy row off-screen, so the
/// whole payload scrolls inside a fixed box instead.
class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.text, required this.expanded});

  final String text;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final body = SelectableText(
      text,
      maxLines: expanded ? null : 6,
      style: TextStyle(
        fontSize: 12.5,
        height: 1.45,
        color: context.colors.onSurface.withValues(alpha: 0.8),
      ),
    );
    if (!expanded) return body;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: SingleChildScrollView(child: body),
    );
  }
}
