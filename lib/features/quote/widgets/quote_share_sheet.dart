import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/anim/press_scale.dart';
import '../../../core/feedback/app_messages.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/shloka.dart';
import '../../../services/share_file/share_file.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/shloka_share_card.dart';
import '../domain/shloka_share_text.dart';
import '../domain/shloka_translation.dart';

/// Shares the verse as a branded image card, mirroring [ShareService].
///
/// Falls back to text sharing when the image capture fails.
Future<void> shareWisdomAsImage(
  BuildContext context,
  Shloka shloka, {
  required bool hindiFirst,
  required bool showAll,
}) async {
  final l10n = AppLocalizations.of(context);
  Future<void> shareTextFallback() {
    return SharePlus.instance.share(
      ShareParams(
        text: buildShlokaShareText(
          shloka,
          expanded: true,
          hindiFirst: hindiFirst,
          showAll: showAll,
          l10n: l10n,
        ),
        subject: l10n?.dailyWisdom ?? 'Daily Wisdom',
      ),
    );
  }

  try {
    // Storage hygiene first: drop day-old share images so repeated
    // shares don't grow the temp directory without bound.
    await purgeOldShareImages();
    if (!context.mounted) return;
    final primary = pickShlokaTranslation(shloka, hindiFirst: hindiFirst);
    final secondary = showAll
        ? otherShlokaTranslation(shloka, hindiFirst: hindiFirst)
        : null;
    final translations = [
      if (primary != null)
        ShlokaShareTranslation(
          primary,
          isHindi: primary == shloka.hindiTranslation,
        ),
      if (secondary != null && secondary != primary)
        ShlokaShareTranslation(
          secondary,
          isHindi: secondary == shloka.hindiTranslation,
        ),
    ];
    final imageBytes = await ScreenshotController().captureFromWidget(
      Material(
        type: MaterialType.transparency,
        child: ShlokaShareCard(shloka: shloka, translations: translations),
      ),
      delay: const Duration(milliseconds: 100),
      context: context,
      pixelRatio: 3.0,
    );
    final imagePath = await saveImageToTemp(imageBytes, 'daily-wisdom');
    if (!context.mounted) return;
    if (imagePath == null) {
      await shareTextFallback();
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        text: l10n?.dailyWisdomShareMessage ?? 'Daily Wisdom — Tithi App',
        files: [XFile(imagePath, mimeType: 'image/png')],
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    showAppMessage(
      context,
      l10n?.couldNotCreateImage ?? 'Could not create image',
      kind: AppMessageKind.error,
    );
  }
}

/// Bottom-sheet chooser for sharing the verse as an image card or as text,
/// following the app's sheet presentation with the festival-gold row styling
/// used across the home cards.
void showQuoteShareOptions(
  BuildContext context, {
  required Shloka shloka,
  required bool expanded,
  required bool hindiFirst,
  required bool showAll,
}) {
  final l10n = AppLocalizations.of(context);
  final accent = AppTheme.festivalAccent(context);
  showModalBottomSheet(
    context: context,
    sheetAnimationStyle: AppTheme.sheetAnimationStyleOf(context),
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s12,
        AppSpacing.s20,
        AppSpacing.s24,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle, matching the app's shared sheet idiom.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.micro),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.festivalTileBackground(context),
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.share_rounded,
                    color: accent,
                    size: AppIconSize.large,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n?.shareVerse ?? 'Share verse',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: AppTypography.bold,
                          color: context.colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        '— ${shloka.source}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurface.withValues(
                            alpha: AppTheme.contrastAlpha(context, 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            _ShareOption(
              icon: Icons.image_outlined,
              title: l10n?.shareAsImage ?? 'Share as image',
              subtitle: l10n?.verseCardPicture ?? 'Verse card picture',
              onTap: () {
                Navigator.of(sheetContext).pop();
                shareWisdomAsImage(
                  context,
                  shloka,
                  hindiFirst: hindiFirst,
                  showAll: showAll,
                );
              },
            ),
            const SizedBox(height: AppSpacing.s8),
            _ShareOption(
              icon: Icons.short_text_rounded,
              title: l10n?.shareAsText ?? 'Share as text',
              subtitle: l10n?.verseWithTranslation ?? 'Verse with translation',
              onTap: () {
                Navigator.of(sheetContext).pop();
                SharePlus.instance.share(
                  ShareParams(
                    text: buildShlokaShareText(
                      shloka,
                      expanded: expanded,
                      hindiFirst: hindiFirst,
                      showAll: showAll,
                      l10n: l10n,
                    ),
                    subject: l10n?.dailyWisdom ?? 'Daily Wisdom',
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.s8),
            _ShareOption(
              icon: Icons.copy_rounded,
              title: l10n?.copyText ?? 'Copy text',
              subtitle: l10n?.copyVerseToClipboard ?? 'Copy verse to clipboard',
              onTap: () async {
                Navigator.of(sheetContext).pop();
                String? copyError;
                try {
                  await Clipboard.setData(
                    ClipboardData(
                      text: buildShlokaShareText(
                        shloka,
                        expanded: expanded,
                        hindiFirst: hindiFirst,
                        showAll: showAll,
                        l10n: l10n,
                      ),
                    ),
                  );
                } catch (_) {
                  copyError = l10n?.couldNotCopyVerse ?? 'Could not copy verse';
                }
                if (context.mounted) {
                  if (copyError != null) {
                    showAppMessage(
                      context,
                      copyError,
                      kind: AppMessageKind.error,
                    );
                  } else {
                    showAppMessage(
                      context,
                      l10n?.verseCopied ?? 'Verse copied',
                      kind: AppMessageKind.success,
                      duration: const Duration(seconds: 2),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// One action row in the share sheet: gold glyph tile, title/subtitle and a
/// chevron, on the shared festival-row surface so the sheet matches the
/// home cards.
class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.festivalAccent(context);
    // Gated press haptic + scale live in PressScale (Stateless-safe).
    return PressScale(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: Ink(
          decoration: AppTheme.festivalRowDecoration(context),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.tile),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.festivalTileBackground(context),
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: accent, size: AppIconSize.large),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: context.textTheme.bodyLarge?.copyWith(
                            fontWeight: AppTypography.bold,
                            color: context.colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Text(
                          subtitle,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.onSurface.withValues(
                              alpha: AppTheme.contrastAlpha(context, 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.onSurface.withValues(
                      alpha: AppTheme.contrastAlpha(context, 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
