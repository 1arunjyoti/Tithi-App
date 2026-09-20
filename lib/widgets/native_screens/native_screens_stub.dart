import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

// Stub classes for web - these screens are not available on web
// but we need placeholders to satisfy type checking

class SolarSystemScreen extends StatelessWidget {
  const SolarSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(child: Text(l10n?.solarSystemNotAvailableOnWeb ?? 'Solar System is not available on web')),
    );
  }
}

class EclipseScreen extends StatelessWidget {
  const EclipseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(child: Text(l10n?.eclipseScreenNotAvailableOnWeb ?? 'Eclipse screen is not available on web')),
    );
  }
}
