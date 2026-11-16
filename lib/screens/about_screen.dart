import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../core/feedback/app_messages.dart';
import '../core/location/timezone_resolver.dart';
import '../core/navigation/haptic_back_button.dart';
import '../providers/version_provider.dart';
import '../features/settings/widgets/app_update_settings.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/screen_body.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static final Uri _privacyPolicyUrl = Uri.parse(
    'https://tithiapp.netlify.app/privacy',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final versionAsync = ref.watch(packageInfoProvider);

    return PageScaffold(
      title: Text(l10n?.aboutApp ?? 'About'),
      leading: const HapticBackButton(),
      body: ScreenBody(
        child: ListView(
          padding: EdgeInsets.only(
            top: AppSpacing.s16,
            bottom: AppSpacing.s16 + AppTheme.navigationBarInset(context),
          ),
          children: [
            _AboutHeroCard(versionAsync: versionAsync),
            const SizedBox(height: AppSpacing.s20),
            const AppUpdateCard(),
            const SizedBox(height: AppSpacing.s20),
            _AboutSectionCard(
              icon: Icons.auto_awesome_rounded,
              title:
                  l10n?.aboutBuiltForDailyPractice ??
                  'Built for daily practice',
              description:
                  l10n?.aboutDailyPracticeDescription ??
                  'Tithi blends traditional Panchang wisdom with modern clarity, so your rituals and observances stay on time and effortless.',
            ),
            const SizedBox(height: AppSpacing.s16),
            _AboutSectionCard(
              icon: Icons.explore_rounded,
              title: l10n?.aboutWhatsInside ?? 'What\'s inside',
              description:
                  l10n?.aboutFeaturesDescription ??
                  'Accurate tithi and nakshatra tracking, festival countdowns, local sunrise and sunset, and calm daily inspiration.',
            ),
            const SizedBox(height: AppSpacing.s16),

            _AboutSectionCard(
              icon: Icons.offline_bolt_rounded,
              title: l10n?.privacyYourDataStays ?? 'Your Data Stays With You',
              description:
                  l10n?.privacyYourDataDesc ??
                  'Tithi is designed with a privacy-first, offline-first architecture. All astronomical calculations, calendar generation, event processing happen directly on your device and the app keeps working without a network. We do not collect, store, or transmit your personal data to any external servers.',
            ),
            const SizedBox(height: AppSpacing.s16),
            _AboutSectionCard(
              icon: Icons.location_on_rounded,
              title: l10n?.privacyLocationUsage ?? 'Location Usage',
              description:
                  l10n?.privacyLocationDesc ??
                  'We request access to your location solely to calculate accurate Tithi, Nakshatra, and sunrise/sunset timings, which depend on your specific geographic coordinates. Your location data is processed locally by the app and is never shared with third parties or stored on our servers.',
            ),
            const SizedBox(height: AppSpacing.s16),
            _AboutSectionCard(
              icon: Icons.signal_wifi_off_rounded,
              title: l10n?.privacyOffline ?? 'Offline Functionality',
              description:
                  l10n?.privacyOfflineDesc ??
                  'The app works completely offline. It contains the Swiss Ephemeris data required for high-precision planetary calculations embedded within the app itself.',
            ),
            const SizedBox(height: AppSpacing.s16),
            _AboutSectionCard(
              icon: Icons.code_rounded,
              title: l10n?.privacyOpenSource ?? 'Open Source Transparency',
              description:
                  l10n?.privacyOpenSourceDesc ??
                  'Tithi is an open-source project. Our code is publicly available for audit, ensuring that our privacy promises are backed by verifiable transparency. What you see is exactly what you get.',
            ),
            const SizedBox(height: AppSpacing.s20),
            // Full-card tap target: AppCard owns the ripple, the radius
            // shared by card and ripple, and the haptic. It keeps the
            // default pressedScale of 1.0 so the splash reads as a
            // full-card press instead of popping inside a scaled box.
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.s20),
              onTap: () => _openPrivacyPolicy(context),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s10),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.dense),
                    ),
                    child: Icon(
                      Icons.language_rounded,
                      color: context.colors.primary,
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
                          l10n?.detailedPrivacyPolicy ??
                              'Detailed privacy policy',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: AppTypography.bold,
                            color: context.colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Text(
                          l10n?.readFullPrivacyPolicy ??
                              'Read the full policy on our website',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.secondaryInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.open_in_new_rounded, color: context.secondaryInk),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            // ODbL credit for the bundled time zone boundaries; the
            // package's licence requires it wherever the data ships.
            Center(
              child: Text(
                l10n?.timezoneDataCredit ?? kTimezoneBoundaryAttribution,
                textAlign: TextAlign.center,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.hintInk,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Center(
              child: Text(
                l10n?.applicationLegalese ??
                    '© 2026 Tithi Project\nMade with love for Sanatan Dharma',
                textAlign: TextAlign.center,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.secondaryInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    if (await canLaunchUrl(_privacyPolicyUrl)) {
      await launchUrl(_privacyPolicyUrl, mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    showAppMessage(
      context,
      l10n?.unableToOpenPrivacyPolicy ??
          'Unable to open the privacy policy website.',
      kind: AppMessageKind.error,
    );
  }
}

class _AboutHeroCard extends StatelessWidget {
  const _AboutHeroCard({required this.versionAsync});

  final AsyncValue<PackageInfo> versionAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Image.asset(
                'assets/icons/logo_transparent.png',
                excludeFromSemantics: true,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            l10n?.tithi ?? 'Tithi',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: AppTypography.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            l10n?.aboutTagline ?? 'Vedic calendar for modern life',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.secondaryInk,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          _VersionChip(versionAsync: versionAsync),
        ],
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({required this.versionAsync});

  final AsyncValue<PackageInfo> versionAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return versionAsync.when(
      data: (info) {
        final versionLabel = '${info.version} (${info.buildNumber})';
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s6,
          ),
          decoration: BoxDecoration(
            color: context.colors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            l10n?.versionText(versionLabel) ?? 'Version $versionLabel',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.secondaryInk,
            ),
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s6,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          l10n?.versionText('...') ?? 'Version ...',
          style: context.textTheme.labelMedium?.copyWith(
            color: context.secondaryInk,
          ),
        ),
      ),
      error: (error, stack) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s6,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          l10n?.versionText('?') ?? 'Version ?',
          style: context.textTheme.labelMedium?.copyWith(
            color: context.secondaryInk,
          ),
        ),
      ),
    );
  }
}

class _AboutSectionCard extends StatelessWidget {
  const _AboutSectionCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
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
                  size: AppIconSize.large,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
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
            description,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.78),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
