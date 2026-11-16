import 'package:material_ui/material_ui.dart';

import '../theme/app_metrics.dart';
import '../theme/app_theme.dart';

/// A single grey block standing in for content that is still loading.
///
/// The app's skeletons were three separate builders with three tints, three
/// radii and three heights. One tint ([AppTheme] surface at 6% onSurface) and
/// one radius per context is enough: pass [radius] when the block stands in
/// for a [AppRadius.chip] cell (calendar) rather than a [AppRadius.tile] row.
///
/// Static on purpose. A shimmer would add a dependency and a Reduce Motion
/// gate for no information gain - the block already says "loading".
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.height,
    this.width,
    this.radius = AppRadius.tile,
  });

  final double? height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: context.colors.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A vertical run of [SkeletonBox]es, for list and card bodies.
///
/// Heights stay at the call site's item height so the skeleton keeps the
/// loaded layout's footprint - the home card, for example, must not resize
/// when content arrives.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 3,
    this.itemHeight = 76,
    this.gap = AppSpacing.s10,
    this.radius = AppRadius.tile,
  });

  final int count;
  final double itemHeight;
  final double gap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) SizedBox(height: gap),
          SkeletonBox(height: itemHeight, radius: radius),
        ],
      ],
    );
  }
}

/// The small spinner that sits next to a label while one row updates.
///
/// Full-screen loads keep `CircularProgressIndicator.adaptive()`; this is the
/// inline size, which used to ship with stroke widths of 1.5, 2 and 2.4 and
/// inconsistent colours across eight files.
class InlineSpinner extends StatelessWidget {
  const InlineSpinner({super.key, this.size = AppIconSize.small, this.color});

  final double size;

  /// Defaults to the theme's primary ink; pass [AppTheme.festivalAccent] when
  /// the spinner sits on a festival-tinted surface.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? context.colors.primary,
      ),
    );
  }
}
