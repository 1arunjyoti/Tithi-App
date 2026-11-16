/// Layout scale for Tithi: spacing, corner radius and icon sizes.
///
/// Typography got a job-named ladder because a text size has a job ("this is
/// a section heading"). Spacing does not have fourteen jobs; it has a base
/// grid, so the steps are named by their dp value and the grid itself is the
/// rule:
///
///  * Padding and gaps use a 4dp rhythm (4, 8, 12, 16, 20, 24, 28, 32), with
///    2dp steps (2, 6, 10, 14, 18, 22) for things that sit next to a glyph
///    or a 12-14pt line box, where 4dp either crowds or drifts.
///  * Anything above 32 is a *component dimension* - a 44dp avatar, a 168dp
///    moon disc, a 48dp tap target - not spacing, and stays a literal at the
///    widget that owns it.
///  * Padding is never a one-off number: if a value is on the ladder it must
///    be the token, so the next screen cannot quietly introduce 13.
///
/// Radius and icon sizes *do* have jobs, so those are named by role and their
/// values were snapped to a shorter scale (see [AppRadius.ladder]).
library;

import 'package:flutter/painting.dart';

/// The spacing ladder: every padding and gap up to 32dp.
abstract final class AppSpacing {
  /// 2dp - hairline inset: a 1-2dp badge, a divider's optical offset.
  static const double s2 = 2;

  /// 4dp - the smallest rhythm step: icon-to-edge, chip inner gap.
  static const double s4 = 4;

  /// 6dp - icon-to-label gap at body size.
  static const double s6 = 6;

  /// 8dp - compact row padding, stacked metadata lines.
  static const double s8 = 8;

  /// 10dp - inner padding of a small badge or tile.
  static const double s10 = 10;

  /// 12dp - page gutter, standard row inset.
  static const double s12 = 12;

  /// 14dp - a dense card's inner padding.
  static const double s14 = 14;

  /// 16dp - card padding, section gap (the base step).
  static const double s16 = 16;

  /// 18dp - a roomy card's inner padding.
  static const double s18 = 18;

  /// 20dp - page section padding, sheet body inset.
  static const double s20 = 20;

  /// 22dp - gap between a large glyph and its label.
  static const double s22 = 22;

  /// 24dp - screen padding, empty-state body.
  static const double s24 = 24;

  /// 28dp - generous inset around a share card's content.
  static const double s28 = 28;

  /// 32dp - the largest spacing step: empty-state frame padding.
  static const double s32 = 32;

  /// The whole ladder, smallest first. Tests walk this to prove it stays
  /// ascending, unique, and on the 2dp grid.
  static const List<double> ladder = <double>[
    s2,
    s4,
    s6,
    s8,
    s10,
    s12,
    s14,
    s16,
    s18,
    s20,
    s22,
    s24,
    s28,
    s32,
  ];

  /// The largest value [ladder] covers. Above it a number is a component
  /// dimension and is allowed to live at its own widget.
  static const double maxStep = s32;
}

/// Corner radii, named by the surface they wrap.
///
/// These were 18 distinct values (1, 2, 3, 4, 6, 8, 10, 12, 13, 14, 16, 20,
/// 24, 28, 32, 50, 99, 999). Half of them were the same surface drawn a
/// point or two differently, so the scale is now nine steps and the old
/// values were snapped to the nearest role: 1/3 -> [micro], 6 -> [chip],
/// 10/13 -> [dense], 14 -> [tile], 28 -> [card], 50/99 -> [pill].
///
/// There is no "radius 12" argument in the codebase: pick the role.
abstract final class AppRadius {
  /// 2dp - hairline marks: progress tracks, the sheet drag handle.
  static const double micro = 2;

  /// 4dp - the smallest rounded mark: a dot or a colour swatch.
  static const double small = 4;

  /// 8dp - chips, small badges, tiny thumbnails.
  static const double chip = 8;

  /// 12dp - dense tiles, text fields, inline surfaces.
  static const double dense = 12;

  /// 16dp - compact cards and nested tiles.
  static const double tile = 16;

  /// 20dp - round-ish icon tiles and calendar day cells.
  static const double round = 20;

  /// 24dp - page-level cards.
  static const double card = 24;

  /// 32dp - bottom sheets, dialogs, the drawer edge.
  static const double sheet = 32;

  /// 999dp - fully rounded: pills, chips, circular avatars.
  ///
  /// Not a diameter: `BorderRadius.circular` clamps to half the box, so any
  /// large number looks identical. 999 is the one spelling.
  static const double pill = 999;

  /// The whole scale, smallest first, with [pill] last. Tests walk this.
  static const List<double> ladder = <double>[
    micro,
    small,
    chip,
    dense,
    tile,
    round,
    card,
    sheet,
    pill,
  ];

  /// The top corners of a bottom sheet or dialog.
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}

/// Icon sizes, named by the row they sit in.
///
/// Icons were set at 13 sizes (14, 16, 18, 20, 22, 24, 28, 32, 40, 44, 48,
/// 56, 64) and every one of them was doing a different job - 20 in a list
/// row, 22 in a sheet header, 24 in the drawer, 48 in an empty state. They are
/// kept as-is (an icon rounded from 22 to 24 is visibly heavier), but they now
/// have names, so new code picks a role instead of a number.
abstract final class AppIconSize {
  /// 14dp - inline with 12-13pt text: chip glyphs, calendar legend marks.
  static const double inline = 14;

  /// 16dp - metadata row icon, small button.
  static const double small = 16;

  /// 18dp - dense list leading/trailing glyph.
  static const double dense = 18;

  /// 20dp - the default: list rows, tiles, inline actions.
  static const double medium = 20;

  /// 22dp - sheet header and app-bar action.
  static const double large = 22;

  /// 24dp - navigation bar, drawer rows, full-size tap target glyph.
  static const double nav = 24;

  /// 28dp - a card's heading glyph.
  static const double title = 28;

  /// 32dp - a primary action or stat glyph.
  static const double hero = 32;

  /// 40dp - a feature illustration glyph.
  static const double feature = 40;

  /// 44dp - a thumbnail-sized glyph.
  static const double avatar = 44;

  /// 48dp - empty-state illustration.
  static const double empty = 48;

  /// 56dp - a large empty-state or countdown glyph.
  static const double display = 56;

  /// 64dp - the biggest glyph: splash, search prompt, weather.
  static const double splash = 64;

  /// The whole scale, smallest first. Tests walk this.
  static const List<double> ladder = <double>[
    inline,
    small,
    dense,
    medium,
    large,
    nav,
    title,
    hero,
    feature,
    avatar,
    empty,
    display,
    splash,
  ];
}
