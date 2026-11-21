import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_haptics.dart';
import '../../../core/location/place_clock.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../providers/location_provider.dart';
import '../../../screens/location_picker_screen.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/moon_animation_widget.dart';
import '../domain/hero_content.dart';
import 'artwork_window.dart';
import 'hero_artwork_deck.dart';
import 'hero_chip.dart';

// Header and moon-row sections of the hero card. They live in one file on
// purpose: one cohesive render tree sharing the same providers and rebuild
// path, so splitting them added indirection without removing coupling. The
// real seams are the deck (hero_artwork_deck.dart) and the rotation clock
// (hero_deck_rotation.dart).

/// Header row: status dot ↔ tag and tag ↔ location pill (symmetric, so the
/// eyebrow reads as one row whether or not the pill is present).
const double _heroHeaderRowGap = 8;

/// Header row: location pill ↔ sheet chevron.
const double _heroHeaderPillChevronGap = 2;

/// Header: tag + day, full width with the location pill capped so a long
/// city name truncates instead of squeezing the tag into a RenderFlex
/// overflow. Text wraps instead of eclipsing at any width.
class HeroHeader extends ConsumerWidget {
  const HeroHeader({
    super.key,
    required this.tagLabel,
    required this.cityName,
    required this.highContrast,
    required this.onHero,
    required this.maxWidth,
  });

  final String tagLabel;
  final String? cityName;
  final bool highContrast;
  final Color onHero;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Location pill lives in the header's top-right corner, not with the
    // chips below. The zone abbreviation is appended only when the place
    // clock differs from the device's: that is exactly when "Today" and the
    // reminder wall times are the place's, not the phone's, and the label
    // keeps that from reading as an off-by-one bug.
    final city = cityName;
    final zoneLabel = placeClockZoneLabel(ref.watch(placeClockProvider));
    final cityWithZone = city == null
        ? null
        : (zoneLabel == null ? city : '$city · $zoneLabel');
    final locationChip = cityWithZone == null
        ? null
        : HeroChip(
            icon: Icons.location_on_rounded,
            text: cityWithZone,
            highContrast: highContrast,
            hint: (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .setHomeLocation,
            // Direct drill from the home hero to the map picker — same
            // destination as Settings → Home Location, without the detour.
            onTap: () =>
                AppRoutes.pushSharedX(context, const LocationPickerScreen()),
          );
    // Tag: dot + Today · 14 September 2026
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highContrast
                ? context.colors.primary
                : AppTheme.homeHeroAccent(context),
            boxShadow: highContrast
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.homeHeroAccent(context),
                      blurRadius: 8,
                    ),
                  ],
          ),
        ),
        const SizedBox(width: _heroHeaderRowGap),
        Expanded(
          child: Text(
            tagLabel.toUpperCase(),
            style: AppTypography.telemetry(
              // Eyebrow: quieter than the old 11/2.2/bold - tighter tracking
              // and 72% ink let the 24pt title own the hierarchy.
              fontSize: AppTypography.sizeMicro,
              letterSpacing: 1.2,
              color: highContrast
                  ? context.secondaryInk
                  : onHero.withValues(alpha: 0.72),
            ),
          ),
        ),
        // Capped so a long city name truncates inside
        // the pill instead of squeezing the tag
        // into a RenderFlex overflow.
        if (locationChip != null) ...[
          const SizedBox(width: _heroHeaderRowGap),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth * 0.38),
            child: locationChip,
          ),
        ],
        // Header tap affordance: the card opens the
        // detail sheet below.
        const SizedBox(width: _heroHeaderPillChevronGap),
        Icon(
          Icons.expand_more,
          size: AppIconSize.dense,
          color: highContrast ? context.secondaryInk : onHero,
        ),
      ],
    );
  }
}

/// Title = weekday + secondary calendar.
class HeroTitle extends StatelessWidget {
  const HeroTitle({
    super.key,
    required this.content,
    required this.baseStyle,
    required this.accentStyle,
  });

  final HeroContent content;
  final TextStyle baseStyle;
  final TextStyle accentStyle;

  @override
  Widget build(BuildContext context) {
    TextSpan? secondarySpan;
    switch (content.secondaryKind) {
      case HeroSecondaryKind.gregorian:
        secondarySpan = TextSpan(text: content.secondaryText, style: baseStyle);
      case HeroSecondaryKind.hindu:
        secondarySpan = TextSpan(
          text: content.secondaryText,
          style: accentStyle,
        );
      case HeroSecondaryKind.bengali:
        secondarySpan = content.secondaryText == null
            ? null
            : TextSpan(
                text: content.secondaryText,
                // Tiro Bangla rides in the display fallback chain, so Bengali
                // and transliterated text both keep the hero typeface.
                style: accentStyle,
              );
      case HeroSecondaryKind.none:
        // Deliberately no label: title is just the weekday.
        break;
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: secondarySpan == null
                ? content.weekday
                : '${content.weekday}, ',
            style: baseStyle,
          ),
          // build_runner's analyzer predates null-aware elements
          // (hive_generator pins analyzer <7): keep the collection-if.
          // ignore: use_null_aware_elements
          if (secondarySpan != null) secondarySpan,
        ],
      ),
    );
  }
}

/// Moon block → transition chips.
const double _heroGapMoonChips = 10;

/// Moon row: icon tile ↔ paksha/tithi text block.
const double _heroMoonIconTextGap = 12;

/// Moon row: paksha/tithi title ↔ illumination sublabel.
const double _heroMoonTitleSubGap = 2;

/// Moon row: text column ↔ festival artwork slot.
const double _heroMoonArtworkGap = 12;

/// Transition chips: gap between adjacent chips.
const double _heroChipSpacing = 8;

/// Transition chips: gap between wrapped chip runs.
const double _heroChipRunSpacing = 6;

/// Moon row: icon + title/sublabel left, festival artwork right (absent
/// without a picture — text-only layout kept). The transition chips live in
/// the left column under the moon text, so the artwork is centered against
/// text + chips and the chip sits close to the sublabel instead of below the
/// artwork's full height.
///
/// Long-pressing the artwork opens the floating [ArtworkWindow]; taps keep
/// the card's own behaviour (detail sheet). When the day has several
/// pictures the deck rotates on a sideways swipe, and the gallery opens on
/// whichever picture is in front.
class HeroMoonRow extends ConsumerWidget {
  const HeroMoonRow({
    super.key,
    required this.content,
    required this.highContrast,
    required this.onHero,
    required this.maxWidth,
  });

  final HeroContent content;
  final bool highContrast;
  final Color onHero;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final chipBg = AppTheme.homeHeroChipBackground(context);
    final chipBd = AppTheme.homeHeroChipBorder(context);
    // Responsive artwork width: ~26% of the content width,
    // clamped so the text column always keeps room.
    final imageWidth = (maxWidth * 0.26).clamp(76.0, 110.0);
    final artworks = content.artworks;
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.dense),
                      color: highContrast
                          ? context.colors.primary.withValues(alpha: 0.1)
                          : chipBg,
                      border: Border.all(
                        color: highContrast
                            ? context.colors.primary.withValues(alpha: 0.2)
                            : chipBd,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: MoonAnimationWidget(
                      phase: content.illumination,
                      isWaxing: content.isShukla,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: _heroMoonIconTextGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.title,
                          style: TextStyle(
                            fontSize: AppTypography.sizeHeading,
                            fontWeight: AppTypography.semibold,
                            color: highContrast
                                ? context.colors.onSurface
                                : onHero,
                          ),
                        ),
                        const SizedBox(height: _heroMoonTitleSubGap),
                        Text(
                          content.subLabel,
                          style: TextStyle(
                            fontSize: AppTypography.sizeCaption,
                            fontWeight: AppTypography.medium,
                            color: highContrast ? context.secondaryInk : onHero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (content.chips.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: _heroGapMoonChips),
                  child: HeroTransitionChips(
                    chips: content.chips,
                    highContrast: highContrast,
                  ),
                ),
            ],
          ),
        ),
        // Artwork column on the right of the moon text; absent without a
        // picture (text-only layout kept). Several festivals with art stack
        // into a deck, rotate on a sideways swipe, and open as a gallery.
        if (artworks.isNotEmpty) ...[
          const SizedBox(width: _heroMoonArtworkGap),
          HeroArtworkStack(
            artworks: artworks,
            width: imageWidth,
            highContrast: highContrast,
            hint: l10n.enlargeArtworkHint,
            swipeHint: l10n.swipeArtworkHint,
            // The index keeps the gallery on the picture the user swiped to
            // instead of always starting at the day's headline festival.
            onLongPress: (index) {
              AppHaptics.impact(ref);
              showArtworkWindow(context, images: artworks, initialIndex: index);
            },
          ),
        ],
      ],
    );
  }
}

/// Transition chips row. Chips opt into multi-line labels ([HeroChip.wrap])
/// because they sit in the moon row's text column, sharing width with the
/// festival artwork.
class HeroTransitionChips extends StatelessWidget {
  const HeroTransitionChips({
    super.key,
    required this.chips,
    required this.highContrast,
  });

  final List<HeroChipData> chips;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _heroChipSpacing,
      runSpacing: _heroChipRunSpacing,
      children: [
        for (final chip in chips)
          HeroChip(
            icon: chip.icon,
            text: chip.text,
            highlight: chip.highlight,
            suffix: chip.suffix,
            inlineIcon: chip.inlineIcon,
            wrap: true,
            fontWeight: AppTypography.bold,
            fontSize: AppTypography.sizeDetail,
            highContrast: highContrast,
          ),
      ],
    );
  }
}
