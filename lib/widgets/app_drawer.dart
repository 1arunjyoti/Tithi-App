import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/settings_screen.dart';
import '../screens/temple_map_screen.dart';
import '../screens/moon_phases_screen.dart';
import '../providers/version_provider.dart';
import '../providers/view_mode_provider.dart';
import '../screens/sankalpa/sankalpa_list_screen.dart';
import 'responsive_layout.dart';

// Conditional imports for FFI-dependent screens (only available on native platforms)
// On web, we import a stub file that provides placeholder widgets
import 'native_screens/native_screens.dart'
    if (dart.library.html) 'native_screens/native_screens_stub.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.isSidebar = false});

  /// When true, renders as a persistent sidebar without Drawer wrapper
  final bool isSidebar;

  static const _drawerBorderRadius = BorderRadius.only(
    topRight: Radius.circular(32),
    bottomRight: Radius.circular(32),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Use solid color with opacity instead of expensive BackdropFilter
    final backgroundColor = isDark
        ? const Color(0xF5121212) // Dark theme: near-black with high opacity
        : const Color(0xF5FAFAFA); // Light theme: off-white with high opacity

    final content = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: isSidebar ? null : _drawerBorderRadius,
        border: Border(
          right: BorderSide(color: colors.onSurface.withValues(alpha: 0.1)),
        ),
        boxShadow: isSidebar
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(2, 0),
                ),
              ],
      ),
      child: Column(
        children: [
          _DrawerHeader(colors: colors),
          Expanded(child: _DrawerMenuList(colors: colors)),
          const _DrawerFooter(),
        ],
      ),
    );

    // When used as sidebar, don't wrap with Drawer
    if (isSidebar) {
      return content;
    }

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: 280,
      child: ClipRRect(borderRadius: _drawerBorderRadius, child: content),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(32)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.wb_sunny_rounded,
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
                l10n?.appTitle ?? 'Tithi',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              Text(
                l10n?.vedaCalendar ?? 'Vedic Calendar',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Menu list with all drawer items
class _DrawerMenuList extends StatelessWidget {
  const _DrawerMenuList({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        // View Mode Toggle
        const _ViewModeToggleItem(),

        _DrawerMenuItem(
          icon: Icons.spa_rounded,
          title: 'My Sankalpas',
          onTap: () => _navigateTo(context, const SankalpaListScreen()),
        ),

        _DrawerMenuItem(
          icon: Icons.temple_buddhist,
          title: 'Nearby Temples',
          onTap: () => _navigateTo(context, const TempleMapScreen()),
        ),

        _DrawerMenuItem(
          icon: Icons.nightlight_round,
          title: l10n?.moonPhases ?? 'Moon Phases',
          onTap: () => _navigateTo(context, const MoonPhasesScreen()),
        ),

        // FFI-dependent features - hide on web
        if (!kIsWeb) ...[
          _DrawerMenuItem(
            icon: Icons.public,
            title: l10n?.solarSystem ?? 'Solar System',
            onTap: () => _navigateTo(context, const SolarSystemScreen()),
          ),

          _DrawerMenuItem(
            icon: Icons.brightness_3_rounded,
            title: l10n?.eclipses ?? 'Eclipses',
            onTap: () => _navigateTo(context, const EclipseScreen()),
          ),
        ],

        _DrawerMenuItem(
          icon: Icons.settings_rounded,
          title: l10n?.settings ?? 'Settings',
          onTap: () => _navigateTo(context, const SettingsScreen()),
        ),

        const SizedBox(height: 12),
        Divider(color: colors.onSurface.withValues(alpha: 0.1)),
        const SizedBox(height: 12),

        _DrawerMenuItem(
          icon: Icons.share_rounded,
          title: l10n?.shareApp ?? 'Share App',
          onTap: () {
            // Only pop if we're in a drawer
            if (Scaffold.maybeOf(context)?.hasDrawer == true) {
              Navigator.pop(context);
            }
            SharePlus.instance.share(
              ShareParams(
                text:
                    l10n?.shareAppMessage ??
                    'Check out Tithi - The Vedic Calendar App! Download now: https://example.com/tithi',
              ),
            );
          },
        ),

        _DrawerMenuItem(
          icon: Icons.star_rounded,
          title: l10n?.rateUs ?? 'Rate Us',
          onTap: () => _launchRating(context),
        ),

        // About item
        const _AboutMenuItem(),
      ],
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    final navigator = Navigator.of(context);
    final isWideScreen = ResponsiveLayout.isTabletOrLarger(context);

    // Only pop if we are in a drawer (mobile/narrow screen)
    if (!isWideScreen) {
      navigator.pop();
    }
    navigator.push(MaterialPageRoute(builder: (context) => screen));
  }

  Future<void> _launchRating(BuildContext context) async {
    final navigator = Navigator.of(context);
    final isWideScreen = ResponsiveLayout.isTabletOrLarger(context);

    // Only pop if we are in a drawer
    if (!isWideScreen) {
      navigator.pop();
    }
    final Uri url = Uri.parse(
      'https://play.google.com/store/apps/details?id=app.tithi.pro',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

/// Single drawer menu item
class _DrawerMenuItem extends StatelessWidget {
  const _DrawerMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
          ),
          child: Icon(icon, color: colors.primary, size: 20),
        ),
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color: colors.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

/// View mode toggle
class _ViewModeToggleItem extends ConsumerWidget {
  const _ViewModeToggleItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(homeViewModeProvider);
    final isSchedule = currentMode == HomeViewMode.schedule;
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          ref.read(homeViewModeProvider.notifier).toggle();
          final navigator = Navigator.of(context);
          if (!ResponsiveLayout.isTabletOrLarger(context)) {
            navigator.pop();
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
          ),
          child: Icon(
            isSchedule
                ? Icons.calendar_month_rounded
                : Icons.view_agenda_rounded,
            color: colors.primary,
            size: 20,
          ),
        ),
        title: Text(
          isSchedule
              ? (l10n?.calendarView ?? 'Calendar View')
              : (l10n?.scheduleView ?? 'Schedule View'),
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          isSchedule
              ? (l10n?.switchToCalendar ?? 'Switch to month calendar')
              : (l10n?.switchToSchedule ?? 'Switch to event list'),
          style: textTheme.bodySmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.swap_horiz_rounded,
          size: 20,
          color: colors.primary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

/// About menu item - isolated Consumer for async version loading
class _AboutMenuItem extends ConsumerWidget {
  const _AboutMenuItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showAboutDialog(context, ref, l10n),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
          ),
          child: Icon(
            Icons.info_outline_rounded,
            color: colors.primary,
            size: 20,
          ),
        ),
        title: Text(
          l10n?.aboutApp ?? 'About',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color: colors.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Future<void> _showAboutDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations? l10n,
  ) async {
    final navigator = Navigator.of(context);
    // Use ResponsiveLayout to check if we are in a drawer
    if (!ResponsiveLayout.isTabletOrLarger(context)) {
      navigator.pop();
    }

    final version = await ref.read(versionStringProvider.future);

    if (!navigator.mounted) return;

    final colors = Theme.of(navigator.context).colorScheme;
    showAboutDialog(
      context: navigator.context,
      applicationName: l10n?.appTitle ?? 'Tithi',
      applicationVersion: version,
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.wb_sunny_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
      applicationLegalese:
          l10n?.applicationLegalese ??
          '© 2025 Tithi Project\nMade with ❤️ for Sanatan Dharma',
    );
  }
}

/// Footer with version info
class _DrawerFooter extends ConsumerWidget {
  const _DrawerFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(versionStringProvider);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Version ${versionAsync.when(data: (v) => v, loading: () => '...', error: (e, s) => '?')}',
        style: textTheme.labelSmall?.copyWith(
          color: colors.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
