import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../providers/version_provider.dart';
import '../theme/app_theme.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  // TODO: Change the URL to the actual privacy policy page once it's live
  static final Uri _privacyPolicyUrl = Uri.parse('https://tithi.app/privacy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final versionAsync = ref.watch(packageInfoProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n?.aboutApp ?? 'About'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: Container(
                decoration: AppTheme.backgroundDecoration(context),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _AboutHeroCard(versionAsync: versionAsync),
                    const SizedBox(height: 20),
                    const _AboutSectionCard(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Built for daily practice',
                      description:
                          'Tithi blends traditional Panchang wisdom with modern clarity, so your rituals and observances stay on time and effortless.',
                    ),
                    const SizedBox(height: 16),
                    const _AboutSectionCard(
                      icon: Icons.explore_rounded,
                      title: 'What\'s inside',
                      description:
                          'Accurate tithi and nakshatra tracking, festival countdowns, local sunrise and sunset, and calm daily inspiration.',
                    ),
                    const SizedBox(height: 16),

                    _AboutSectionCard(
                      icon: Icons.offline_bolt_rounded,
                      title:
                          l10n?.privacyYourDataStays ??
                          'Your Data Stays With You',
                      description:
                          l10n?.privacyYourDataDesc ??
                          'Tithi is designed with a privacy-first, offline-first architecture. All astronomical calculations, calendar generation, event processing happen directly on your device and the app keeps working without a network. We do not collect, store, or transmit your personal data to any external servers.',
                    ),
                    const SizedBox(height: 16),
                    _AboutSectionCard(
                      icon: Icons.location_on_rounded,
                      title: l10n?.privacyLocationUsage ?? 'Location Usage',
                      description:
                          l10n?.privacyLocationDesc ??
                          'We request access to your location solely to calculate accurate Tithi, Nakshatra, and sunrise/sunset timings, which depend on your specific geographic coordinates. Your location data is processed locally by the app and is never shared with third parties or stored on our servers.',
                    ),
                    const SizedBox(height: 16),
                    _AboutSectionCard(
                      icon: Icons.signal_wifi_off_rounded,
                      title: l10n?.privacyOffline ?? 'Offline Functionality',
                      description:
                          l10n?.privacyOfflineDesc ??
                          'The app works completely offline. It contains the Swiss Ephemeris data required for high-precision planetary calculations embedded within the app itself.',
                    ),
                    const SizedBox(height: 16),
                    _AboutSectionCard(
                      icon: Icons.code_rounded,
                      title:
                          l10n?.privacyOpenSource ?? 'Open Source Transparency',
                      description:
                          l10n?.privacyOpenSourceDesc ??
                          'Tithi is an open-source project. Our code is publicly available for audit, ensuring that our privacy promises are backed by verifiable transparency. What you see is exactly what you get.',
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassmorphism(
                        context: context,
                        ref: ref,
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.colors.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.language_rounded,
                            color: context.colors.primary,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          'Detailed privacy policy',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.colors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'Read the full policy on our website',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        trailing: Icon(
                          Icons.open_in_new_rounded,
                          color: context.colors.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        onTap: () => _openPrivacyPolicy(context),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        l10n?.applicationLegalese ??
                            '© 2026 Tithi Project\nMade with love for Sanatan Dharma',
                        textAlign: TextAlign.center,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colors.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await canLaunchUrl(_privacyPolicyUrl)) {
      await launchUrl(_privacyPolicyUrl, mode: LaunchMode.externalApplication);
      return;
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Unable to open the privacy policy website.'),
      ),
    );
  }
}

class _AboutHeroCard extends ConsumerWidget {
  const _AboutHeroCard({required this.versionAsync});

  final AsyncValue<PackageInfo> versionAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassmorphism(context: context, ref: ref),
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
              padding: const EdgeInsets.all(12),
              child: Image.asset('assets/icons/logo_transparent.png'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tithi',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vedic calendar for modern life',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
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
    return versionAsync.when(
      data: (info) {
        final versionLabel = '${info.version} (${info.buildNumber})';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.colors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Version $versionLabel',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Version ...',
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
      error: (error, stack) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Version ?',
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _AboutSectionCard extends ConsumerWidget {
  const _AboutSectionCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassmorphism(context: context, ref: ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: context.colors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
