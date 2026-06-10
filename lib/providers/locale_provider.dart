import 'dart:ui' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

/// Supported locale information with display names
class SupportedLocale {
  final Locale locale;
  final String name;
  final String nativeName;

  const SupportedLocale({
    required this.locale,
    required this.name,
    required this.nativeName,
  });
}

/// List of all supported locales in the app
const supportedLocales = [
  SupportedLocale(locale: Locale('en'), name: 'English', nativeName: 'English'),
  SupportedLocale(locale: Locale('hi'), name: 'Hindi', nativeName: 'हिंदी'),
  SupportedLocale(locale: Locale('bn'), name: 'Bengali', nativeName: 'বাংলা'),
  SupportedLocale(
    locale: Locale('sa'),
    name: 'Sanskrit',
    nativeName: 'संस्कृतम्',
  ),
];

/// Provider for the current locale selection
/// Returns null to use system default locale
final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

/// Manages locale state with Hive persistence
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final box = StorageService().getSettingsBox();
    final savedLocale = box.get('locale') as String?;
    if (savedLocale != null) {
      return Locale(savedLocale);
    }
    return null;
  }

  /// Load the saved locale from Hive storage
  Future<void> setLocale(Locale locale) async {
    state = locale;
    final box = StorageService().getSettingsBox();
    await box.put('locale', locale.languageCode);
  }

  /// Clear the locale preference (use system default)
  Future<void> clearLocale() async {
    state = null;
    final box = StorageService().getSettingsBox();
    await box.delete('locale');
  }
}

/// Helper to find the SupportedLocale for a given Locale
SupportedLocale? findSupportedLocale(Locale? locale) {
  if (locale == null) return null;
  try {
    return supportedLocales.firstWhere(
      (l) => l.locale.languageCode == locale.languageCode,
    );
  } catch (e) {
    return null;
  }
}
