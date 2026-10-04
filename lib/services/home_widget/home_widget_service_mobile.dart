import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../../providers/festival_countdown_provider.dart';
import '../storage_service.dart';

/// Mobile implementation that syncs festival countdowns to the Android home screen widget.
///
/// Stores a JSON array under the key `festival_widget_data` that the native
/// [FestivalCountdownWidgetProvider] / [FestivalCountdownWidgetService] read
/// via SharedPreferences. The native side hosts a scrollable ListView, so all
/// entries are shown and the list scrolls when the widget is small.
/// Each entry: { title, name, date, dateLabel, daysRemaining, statusLabel }
///
/// The widget theme (`widget_theme_override`) is owned solely by the widget
/// itself (configure screen on add, long-press → Reconfigure on API 31+).
/// App syncs never write it — see [_migrateWidgetThemeOnce].
class HomeWidgetService {
  const HomeWidgetService();

  static const String _androidWidgetName = 'FestivalCountdownWidgetProvider';
  static const String _qualifiedAndroidName =
      'app.tithi.pro.widget.FestivalCountdownWidgetProvider';
  static const String _dataKey = 'festival_widget_data';
  static const String _themeKey = 'widget_theme_override';
  static const String _themeMigrationKey = 'widget_theme_own_migration_v1';

  /// Cached formatters — DateFormat construction is expensive, reuse instances.
  static final DateFormat _dateLabelFormat = DateFormat('EEE, MMM d');
  static final DateFormat _isoFormat = DateFormat('yyyy-MM-dd');

  /// Dedup cache: skip platform-channel IPC when the data is unchanged.
  /// Guarded by Dart's single-threaded event loop — no locking needed.
  static String? _lastSyncedPayload;

  Future<void> updateFestivalCountdownWidget(
    List<FestivalCountdownTarget> targets,
  ) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      await _migrateWidgetThemeOnce();

      // Persist all countdowns (bounded to 20 for IPC safety — each entry is
      // ~100 bytes, so even 20 items is ~2KB). The native ListView shows every
      // item and scrolls internally when the widget is too small to fit them,
      // so nothing is ever hidden or truncated by size.
      // take() is lazy; toList(growable: false) avoids over-allocation.
      final limited = targets.take(20).toList(growable: false);
      // Status labels follow the app language (saved locale, else English)
      // so the widget matches the app when freshly synced. The native side
      // keeps these labels while the day count is unchanged and only
      // re-renders labels in the device language after a midnight rollover
      // without the app running (see WidgetCountdownData).
      final lang = _savedLanguageCode();
      final payload = limited
          .map((t) {
            final dateLabel = _dateLabelFormat.format(t.date);
            final statusLabel = _statusLabel(t, lang);
            return {
              'title': t.title,
              'name': t.festival.name,
              'date': _isoFormat.format(t.date),
              'dateLabel': dateLabel,
              'daysRemaining': t.daysRemaining,
              'statusLabel': statusLabel,
              'lang': lang,
            };
          })
          .toList(growable: false);

      final jsonString = jsonEncode(payload);
      if (jsonString == _lastSyncedPayload) return;

      await HomeWidget.saveWidgetData<String>(_dataKey, jsonString);
      _lastSyncedPayload = jsonString;

      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        qualifiedAndroidName: _qualifiedAndroidName,
      );
    } catch (e) {
      debugPrint('HomeWidgetService.update failed: $e');
    }
  }

  /// App language saved by LocaleNotifier ('locale' key), else English.
  /// Read best-effort at sync time (no Ref here); unknown codes fall back.
  static String _savedLanguageCode() {
    try {
      final box = StorageService().getSettingsBox();
      final code = box.get('locale');
      if (code is String && _statusToday.containsKey(code)) return code;
    } catch (_) {
      // Fall through to English.
    }
    return 'en';
  }

  static const _statusToday = {
    'en': 'Today',
    'hi': 'आज',
    'bn': 'আজ',
    'sa': 'अद्य',
  };

  static const _statusTomorrow = {
    'en': 'Tomorrow',
    'hi': 'कल',
    'bn': 'আগামীকাল',
    'sa': 'श्वः',
  };

  static const _statusDaysToGo = {
    'en': '{days} days to go',
    'hi': '{days} दिन बाकी',
    'bn': '{days} দিন বাকি',
    'sa': '{days} दिनानि शेषाणि',
  };

  static String _statusLabel(FestivalCountdownTarget t, String lang) {
    if (t.isToday) return _statusToday[lang] ?? _statusToday['en']!;
    if (t.isTomorrow) return _statusTomorrow[lang] ?? _statusTomorrow['en']!;
    final template = _statusDaysToGo[lang] ?? _statusDaysToGo['en']!;
    return template.replaceFirst('{days}', t.daysRemaining.toString());
  }

  /// One-time migration: the widget theme used to mirror the app theme and was
  /// overwritten on every sync. It is now owned by the widget's own theme
  /// picker, so clear any stale value once (missing key = Auto) and never
  /// touch the key again. Flagged in Hive so it runs exactly once ever —
  /// a static would re-run (and wipe the user's choice) on every restart.
  Future<void> _migrateWidgetThemeOnce() async {
    try {
      final box = StorageService().getSettingsBox();
      if (box.get(_themeMigrationKey) == true) return;
      // Null data deletes the key on the native side.
      await HomeWidget.saveWidgetData<String>(_themeKey, null);
      await box.put(_themeMigrationKey, true);
    } catch (e) {
      debugPrint('HomeWidgetService theme migration skipped: $e');
    }
  }

  Future<bool> isRequestPinSupported() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final supported = await HomeWidget.isRequestPinWidgetSupported();
      return supported ?? false;
    } catch (e) {
      debugPrint('isRequestPinSupported failed: $e');
      return false;
    }
  }

  Future<bool> requestPinWidget() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final supported = await isRequestPinSupported();
      if (!supported) return false;
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: _qualifiedAndroidName,
      );
      return true;
    } catch (e) {
      debugPrint('requestPinWidget failed: $e');
      return false;
    }
  }

  Future<bool> isWidgetSupported() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    return true;
  }
}
