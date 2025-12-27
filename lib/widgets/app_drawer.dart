import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/settings_screen.dart';
import '../providers/version_provider.dart';
import '../providers/view_mode_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const borderRadius = BorderRadius.only(
      topRight: Radius.circular(32),
      bottomRight: Radius.circular(32),
    );

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: 280,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: context.theme.scaffoldBackgroundColor.withValues(
                alpha: 0.85,
              ),
              borderRadius: borderRadius,
              border: Border.all(
                color: context.colors.onSurface.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    children: [
                      // View Mode Toggle
                      _buildViewModeToggle(context, ref),

                      _buildDrawerItem(
                        context,
                        icon: Icons.settings_rounded,
                        title: 'Settings',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),

                      _buildDrawerItem(
                        context,
                        icon: Icons.share_rounded,
                        title: 'Share App',
                        onTap: () {
                          Navigator.pop(context);
                          SharePlus.instance.share(
                            ShareParams(
                              text:
                                  'Check out Tithi - The Vedic Calendar App! Download now: https://example.com/tithi',
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        context,
                        icon: Icons.star_rounded,
                        title: 'Rate Us',
                        onTap: () async {
                          Navigator.pop(context);
                          final Uri url = Uri.parse(
                            'https://play.google.com/store/apps/details?id=com.example.tithi',
                          ); // TODO: Replace with actual ID
                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        color: context.colors.onSurface.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 12),
                      _buildDrawerItem(
                        context,
                        icon: Icons.info_outline_rounded,
                        title: 'About',
                        onTap: () async {
                          Navigator.pop(context);
                          final version = await ref.read(
                            versionStringProvider.future,
                          );
                          if (context.mounted) {
                            showAboutDialog(
                              context: context,
                              applicationName: 'Tithi',
                              applicationVersion: version,
                              applicationIcon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: context.colors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.wb_sunny_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              applicationLegalese:
                                  '© 2025 Tithi Project\nMade with ❤️ for Sanatan Dharma',
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(32)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: context.colors.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.wb_sunny_rounded, // Solar/Tithi icon
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tithi',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.onSurface,
                ),
              ),
              Text(
                'Vedic Calendar',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // hover/splash colors handle themselves on ListTile, but we can add subtle bg
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.colors.onSurface.withValues(alpha: 0.05),
            ),
          ),
          child: Icon(icon, color: context.colors.primary, size: 20),
        ),
        title: Text(
          title,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color: context.colors.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildViewModeToggle(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(homeViewModeProvider);
    final isSchedule = currentMode == HomeViewMode.schedule;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () {
          ref.read(homeViewModeProvider.notifier).toggle();
          Navigator.pop(context);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.colors.onSurface.withValues(alpha: 0.05),
            ),
          ),
          child: Icon(
            isSchedule
                ? Icons.calendar_month_rounded
                : Icons.view_agenda_rounded,
            color: context.colors.primary,
            size: 20,
          ),
        ),
        title: Text(
          isSchedule ? 'Calendar View' : 'Schedule View',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          isSchedule ? 'Switch to month calendar' : 'Switch to event list',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.swap_horiz_rounded,
          size: 20,
          color: context.colors.primary.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Consumer(
        builder: (context, ref, _) {
          final versionAsync = ref.watch(versionStringProvider);
          return Text(
            'Version ${versionAsync.when(data: (v) => v, loading: () => '...', error: (_, _) => '?')}',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.4),
            ),
          );
        },
      ),
    );
  }
}
