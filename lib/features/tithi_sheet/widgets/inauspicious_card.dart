import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Inauspicious day-window slot kinds, each with its timeline color.
/// Yamaganda follows onSurface so the slot stays legible in dark themes;
/// Rahu (striped red) and Gulika (green) are fixed semantic colors.
enum WindowKind { rahu, yamaganda, gulika }

/// Diagonal-stripe overlay marking the Rahu Kalam slot (dark-red lines on
/// the red base). Static decoration: never repaints.
class DiagonalStripesPainter extends CustomPainter {
  const DiagonalStripesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5;
    const gap = 8.0;
    for (var x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(DiagonalStripesPainter oldDelegate) => false;
}

/// Inauspicious timeline card: sunrise/mid/sunset axis labels, an 8-segment
/// bar from sunrise to sunset with the three inauspicious slots colored
/// (striped red Rahu, dark Yamaganda, green Gulika), and one legend row per
/// slot (dot + name + right-aligned "8:27 – 9:59 AM" range).
class InauspiciousCard extends StatelessWidget {
  const InauspiciousCard({super.key, 
    required this.axisStart,
    required this.axisMid,
    required this.axisEnd,
    required this.rahuSegment,
    required this.yamagandaSegment,
    required this.gulikaSegment,
    required this.rows,
    required this.highContrast,
  });

  final String axisStart;
  final String axisMid;
  final String axisEnd;
  final int rahuSegment;
  final int yamagandaSegment;
  final int gulikaSegment;
  final List<({ WindowKind kind, String name, String time })> rows;
  final bool highContrast;

  static const _rahuColor = Color(0xFFD32F2F);
  static const _rahuStripeColor = Color(0xFF9E1F1F);
  static const _gulikaColor = Color(0xFF7CB342);

  Color _slotColor(WindowKind kind, BuildContext context) {
    return switch (kind) {
      WindowKind.rahu => _rahuColor,
      WindowKind.yamaganda => context.colors.onSurface,
      WindowKind.gulika => _gulikaColor,
    };
  }

  WindowKind? _kindForSegment(int segment) {
    if (segment == rahuSegment) return WindowKind.rahu;
    if (segment == yamagandaSegment) return WindowKind.yamaganda;
    if (segment == gulikaSegment) return WindowKind.gulika;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.colors.onSurface.withValues(alpha: 0.1);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                axisStart,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                axisMid,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                axisEnd,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 1; i <= 8; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 8 ? 6 : 0),
                    child: _slot(i, neutral, context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          for (var j = 0; j < rows.length; j++)
            Padding(
              padding: EdgeInsets.only(bottom: j < rows.length - 1 ? 12 : 0),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _slotColor(rows[j].kind, context),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    rows[j].name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    rows[j].time,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _slot(int segment, Color neutral, BuildContext context) {
    final kind = _kindForSegment(segment);
    final base = kind == null ? neutral : _slotColor(kind, context);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: kind == WindowKind.rahu
          ? const CustomPaint(
              painter: DiagonalStripesPainter(
                color: _rahuStripeColor,
              ),
            )
          : null,
    );
  }
}
