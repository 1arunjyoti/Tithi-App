import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

// Canonical dotted section label extracted from
// widgets/tithi_detail_sheet.dart (_SectionLabel, finalized design):
// primary dot + letterspaced onSurface caption, e.g. TITHI TIMINGS.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.primary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
            color: context.colors.onSurface,
          ),
        ),
      ],
    );
  }
}
