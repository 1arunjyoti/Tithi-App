import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Custom Material Localizations delegate that falls back to English
/// for unsupported locales like Sanskrit.
class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  /// List of locale codes that GlobalMaterialLocalizations supports
  static const _supportedMaterialLocales = {
    'en', 'hi', 'bn', // Add more as needed
    'ar', 'de', 'es', 'fr', 'it', 'ja', 'ko', 'pt', 'ru', 'zh',
    'af', 'am', 'as', 'az', 'be', 'bg', 'bs', 'ca', 'cs', 'cy',
    'da', 'el', 'et', 'eu', 'fa', 'fi', 'fil', 'gl', 'gsw', 'gu',
    'he', 'hr', 'hu', 'hy', 'id', 'is', 'ka', 'kk', 'km', 'kn',
    'ky', 'lo', 'lt', 'lv', 'mk', 'ml', 'mn', 'mr', 'ms', 'my',
    'nb', 'ne', 'nl', 'no', 'or', 'pa', 'pl', 'ps', 'ro', 'si',
    'sk', 'sl', 'sq', 'sr', 'sv', 'sw', 'ta', 'te', 'th', 'tl',
    'tr', 'uk', 'ur', 'uz', 'vi', 'zu',
  };

  @override
  bool isSupported(Locale locale) {
    // We support all locales by falling back to English for unsupported ones
    return true;
  }

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    // Check if the locale is natively supported by Material
    if (_supportedMaterialLocales.contains(locale.languageCode)) {
      // Use the built-in delegate
      return GlobalMaterialLocalizations.delegate.load(locale);
    }
    // Fall back to English for unsupported locales (like Sanskrit)
    return GlobalMaterialLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(FallbackMaterialLocalizationsDelegate old) => false;
}

/// Custom Cupertino Localizations delegate that falls back to English
/// for unsupported locales like Sanskrit.
class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  /// List of supported locales for Cupertino
  static const _supportedCupertinoLocales = {
    'en',
    'hi',
    'bn',
    'ar',
    'de',
    'es',
    'fr',
    'it',
    'ja',
    'ko',
    'pt',
    'ru',
    'zh',
  };

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    // Fall back to English for unsupported locales
    if (_supportedCupertinoLocales.contains(locale.languageCode)) {
      return GlobalCupertinoLocalizations.delegate.load(locale);
    }
    return GlobalCupertinoLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(FallbackCupertinoLocalizationsDelegate old) => false;
}
