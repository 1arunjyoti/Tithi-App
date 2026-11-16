import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../core/navigation/haptic_back_button.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/screen_body.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PageScaffold(
      title: Text(l10n?.privacyPolicy ?? 'Privacy Policy'),
      leading: const HapticBackButton(),
      body: ScreenBody(
        child: ListView(
          padding: EdgeInsets.only(
            top: AppSpacing.s16,
            bottom: AppSpacing.s16 + AppTheme.navigationBarInset(context),
          ),
          children: [
            _buildPolicyCard(
              context,
              title: l10n?.privacyYourDataStays ?? 'Your Data Stays With You',
              content:
                  l10n?.privacyYourDataDesc ??
                  'Tithi is designed with a privacy-first, offline-first architecture. All astronomical calculations, calendar generation, and event processing happen directly on your device. We do not collect, store, or transmit your personal data to any external servers.',
              icon: Icons.offline_bolt_rounded,
            ),
            const SizedBox(height: AppSpacing.s16),
            _buildPolicyCard(
              context,
              title: l10n?.privacyLocationUsage ?? 'Location Usage',
              content:
                  l10n?.privacyLocationDesc ??
                  'We request access to your location solely to calculate accurate Tithi, Nakshatra, and sunrise/sunset timings, which depend on your specific geographic coordinates. Your location data is processed locally by the app and is never shared with third parties or stored on our servers.',
              icon: Icons.location_on_rounded,
            ),
            const SizedBox(height: AppSpacing.s16),
            _buildPolicyCard(
              context,
              title: l10n?.privacyAiTitle ?? 'AI Assist (Optional)',
              content:
                  l10n?.privacyAiDesc ??
                  'AI assist is off by default. When you turn it on and choose to ask AI, Tithi builds a short summary of the panchang for your city (date, tithi, nakshatra, sunrise and sunset) and hands it to the AI app you pick from the system share sheet. Your GPS coordinates are never included, Tithi sends nothing by itself, and the conversation afterwards is governed by that app\'s own privacy policy.',
              icon: Icons.auto_awesome_outlined,
            ),
            const SizedBox(height: AppSpacing.s16),
            _buildPolicyCard(
              context,
              title: l10n?.privacyOffline ?? 'Offline Functionality',
              content:
                  l10n?.privacyOfflineDesc ??
                  'The app works completely offline after the initial download. It contains the Swiss Ephemeris data required for high-precision planetary calculations embedded within the app itself.',
              icon: Icons.signal_wifi_off_rounded,
            ),
            const SizedBox(height: AppSpacing.s16),
            _buildPolicyCard(
              context,
              title: l10n?.privacyOpenSource ?? 'Open Source Transparency',
              content:
                  l10n?.privacyOpenSourceDesc ??
                  'Tithi is an open-source project. Our code is publicly available for audit, ensuring that our privacy promises are backed by verifiable transparency. What you see is exactly what you get.',
              icon: Icons.code_rounded,
            ),
            const SizedBox(height: 48),
            Center(
              child: Text(
                l10n?.lastUpdated ?? 'Last Updated: October 2026',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.hintInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyCard(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s10),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.dense),
                ),
                child: Icon(
                  icon,
                  color: context.colors.primary,
                  size: AppIconSize.nav,
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Text(
                  title,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: AppTypography.bold,
                    color: context.colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            content,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
