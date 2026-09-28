import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../core/anim/press_scale.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n?.privacyPolicy ?? 'Privacy Policy'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: PressScale(
          child: IconButton(
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
      ),
      body: Stack(
        children: [
          // Ambient Background — delegates to AppTheme.backgroundDecoration (SMELL-1)
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
                    _buildPolicyCard(
                      context,
                      title:
                          l10n?.privacyYourDataStays ??
                          'Your Data Stays With You',
                      content:
                          l10n?.privacyYourDataDesc ??
                          'Tithi is designed with a privacy-first, offline-first architecture. All astronomical calculations, calendar generation, and event processing happen directly on your device. We do not collect, store, or transmit your personal data to any external servers.',
                      icon: Icons.offline_bolt_rounded,
                      ref: ref,
                    ),
                    const SizedBox(height: 16),
                    _buildPolicyCard(
                      context,
                      title: l10n?.privacyLocationUsage ?? 'Location Usage',
                      content:
                          l10n?.privacyLocationDesc ??
                          'We request access to your location solely to calculate accurate Tithi, Nakshatra, and sunrise/sunset timings, which depend on your specific geographic coordinates. Your location data is processed locally by the app and is never shared with third parties or stored on our servers.',
                      icon: Icons.location_on_rounded,
                      ref: ref,
                    ),
                    const SizedBox(height: 16),
                    _buildPolicyCard(
                      context,
                      title: l10n?.privacyOffline ?? 'Offline Functionality',
                      content:
                          l10n?.privacyOfflineDesc ??
                          'The app works completely offline after the initial download. It contains the Swiss Ephemeris data required for high-precision planetary calculations embedded within the app itself.',
                      icon: Icons.signal_wifi_off_rounded,
                      ref: ref,
                    ),
                    const SizedBox(height: 16),
                    _buildPolicyCard(
                      context,
                      title:
                          l10n?.privacyOpenSource ?? 'Open Source Transparency',
                      content:
                          l10n?.privacyOpenSourceDesc ??
                          'Tithi is an open-source project. Our code is publicly available for audit, ensuring that our privacy promises are backed by verifiable transparency. What you see is exactly what you get.',
                      icon: Icons.code_rounded,
                      ref: ref,
                    ),
                    const SizedBox(height: 48),
                    Center(
                      child: Text(
                        l10n?.lastUpdated ?? 'Last Updated: December 2025',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colors.onSurface.withValues(
                            alpha: 0.5,
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

  Widget _buildPolicyCard(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
    required WidgetRef ref,
  }) {
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
                child: Icon(icon, color: context.colors.primary, size: 24),
              ),
              const SizedBox(width: 16),
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
