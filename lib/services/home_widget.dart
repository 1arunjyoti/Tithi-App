import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../features/home_widget/domain/panchang_widget_payload.dart';
import '../providers/festival_countdown_provider.dart';
import 'storage_service.dart';

/// Every Android home-screen widget the app ships.
///
/// The native class names are the contract with the manifest receivers; a
/// mismatch fails silently in the launcher, so they live in one place.
enum HomeWidgetKind {
  countdowns(
    androidName: 'FestivalCountdownWidgetProvider',
    qualifiedName: 'app.tithi.pro.widget.FestivalCountdownWidgetProvider',
  ),
  hero(
    androidName: 'HeroWidgetProvider',
    qualifiedName: 'app.tithi.pro.widget.HeroWidgetProvider',
  ),
  auspicious(
    androidName: 'AuspiciousTimingsWidgetProvider',
    qualifiedName: 'app.tithi.pro.widget.AuspiciousTimingsWidgetProvider',
  ),
  inauspicious(
    androidName: 'InauspiciousTimingsWidgetProvider',
    qualifiedName: 'app.tithi.pro.widget.InauspiciousTimingsWidgetProvider',
  ),
  combined(
    androidName: 'CombinedTimingsWidgetProvider',
    qualifiedName: 'app.tithi.pro.widget.CombinedTimingsWidgetProvider',
  );

  const HomeWidgetKind({
    required this.androidName,
    required this.qualifiedName,
  });

  final String androidName;
  final String qualifiedName;
}

/// Syncs panchang data to the Android home screen widgets.
///
/// Festival countdowns are stored as a JSON array under
/// `festival_widget_data`; the panchang widgets read two more documents:
/// [kHeroWidgetDataKey] (one object) and [kTimingsWidgetDataKey] (today and
/// tomorrow, all windows). All keys are read natively from
/// `HomeWidgetPreferences`.
///
/// Every user-visible string is localized on the Dart side at sync time. The
/// native widgets only recompute what they safely can without the ephemeris:
/// countdown day counts (from ISO dates) and which timing window is current
/// (from ISO instants).
///
/// The widget theme (`widget_theme_override`) is owned solely by the widget
/// itself (configure screen on add, long-press → Reconfigure on API 31+).
/// App syncs never write it — see [_migrateWidgetThemeOnce].
class HomeWidgetService {
  const HomeWidgetService();

  static const String _dataKey = 'festival_widget_data';
  static const String _themeKey = 'widget_theme_override';
  static const String _themeMigrationKey = 'widget_theme_own_migration_v1';

  /// Cached formatters — DateFormat construction is expensive, reuse instances.
  static final DateFormat _dateLabelFormat = DateFormat('EEE, MMM d');
  static final DateFormat _isoFormat = DateFormat('yyyy-MM-dd');

  /// Dedup caches: skip platform-channel IPC when a payload is unchanged.
  /// Guarded by Dart's single-threaded event loop — no locking needed.
  static String? _lastSyncedPayload;
  static String? _lastHeroPayload;
  static String? _lastTimingsPayload;

  Future<void> updateFestivalCountdownWidget(
    List<FestivalCountdownTarget> targets,
  ) async {
    if (!Platform.isAndroid) return;

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
      // Cache only after the repaint broadcast succeeds: a failed notify
      // must be retried by the next sync, not masked by the dedup cache.
      if (await _notify(HomeWidgetKind.countdowns)) {
        _lastSyncedPayload = jsonString;
      }
    } catch (e) {
      debugPrint('HomeWidgetService.update failed: $e');
    }
  }

  /// Persists and repaints the hero and timing widgets.
  ///
  /// [hero] and [timings] are the payloads from
  /// `features/home_widget/domain/panchang_widget_payload.dart`. Each document
  /// dedups independently, so a language-only change repaints everything
  /// while an unchanged hero does not cost a second broadcast.
  Future<void> updatePanchangWidgets({
    required Map<String, dynamic> hero,
    required Map<String, dynamic> timings,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      await _migrateWidgetThemeOnce();

      final heroJson = jsonEncode(hero);
      final timingsJson = jsonEncode(timings);
      final heroChanged = heroJson != _lastHeroPayload;
      final timingsChanged = timingsJson != _lastTimingsPayload;
      if (!heroChanged && !timingsChanged) return;

      if (heroChanged) {
        await HomeWidget.saveWidgetData<String>(kHeroWidgetDataKey, heroJson);
        // Cache only after the repaint broadcast succeeds, so a transient
        // platform-channel failure is retried instead of being deduped away.
        if (await _notify(HomeWidgetKind.hero)) {
          _lastHeroPayload = heroJson;
        }
      }
      if (timingsChanged) {
        await HomeWidget.saveWidgetData<String>(
          kTimingsWidgetDataKey,
          timingsJson,
        );
        // Notify every timing widget even if one host fails; only skip the
        // cache when any repaint was lost, so the next sync retries all three.
        var repainted = true;
        for (final kind in const [
          HomeWidgetKind.auspicious,
          HomeWidgetKind.inauspicious,
          HomeWidgetKind.combined,
        ]) {
          final ok = await _notify(kind);
          repainted = ok && repainted;
        }
        if (repainted) _lastTimingsPayload = timingsJson;
      }
    } catch (e) {
      debugPrint('HomeWidgetService panchang update failed: $e');
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

  /// Returns false (instead of throwing) when the repaint broadcast fails, so
  /// callers can decide whether the payload is safe to dedup.
  Future<bool> _notify(HomeWidgetKind kind) async {
    try {
      await HomeWidget.updateWidget(
        name: kind.androidName,
        qualifiedAndroidName: kind.qualifiedName,
      );
      return true;
    } catch (e) {
      debugPrint('HomeWidgetService notify ${kind.name} failed: $e');
      return false;
    }
  }

  Future<bool> isRequestPinSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      final supported = await HomeWidget.isRequestPinWidgetSupported();
      return supported ?? false;
    } catch (e) {
      debugPrint('isRequestPinSupported failed: $e');
      return false;
    }
  }

  Future<bool> requestPinWidget([
    HomeWidgetKind kind = HomeWidgetKind.countdowns,
  ]) async {
    if (!Platform.isAndroid) return false;
    try {
      final supported = await isRequestPinSupported();
      if (!supported) return false;
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: kind.qualifiedName,
      );
      return true;
    } catch (e) {
      debugPrint('requestPinWidget failed: $e');
      return false;
    }
  }

  Future<bool> isWidgetSupported() async {
    if (!Platform.isAndroid) return false;
    return true;
  }
}
