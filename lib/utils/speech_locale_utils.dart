// lib/utils/speech_locale_utils.dart
import 'package:speech_to_text/speech_to_text.dart';

/// Central place for matching an app-level language code ('en' / 'zh' / 'ms')
/// against the locale IDs actually reported by the device's speech engine.
///
/// Android's on-device SpeechRecognizer does NOT always report Chinese as
/// "zh-CN". Mandarin is frequently reported as "cmn-Hans-CN" (or
/// "cmn-Hans-TW"), and Cantonese as "yue-Hant-HK". A naive
/// `localeId.startsWith('zh')` check misses these entirely, which is why
/// Chinese voice input looked "unsupported" even when it was installed.
///
/// Malay commonly has no on-device model at all outside certain regions —
/// that's a genuine device/OS gap, not something this matching logic can
/// paper over, but we still list known variants in case a device reports it
/// differently than expected.
class SpeechLocaleUtils {
  SpeechLocaleUtils._();

  /// Known locale-ID prefixes for each app language, lowercase.
  static const Map<String, List<String>> _prefixesByAppCode = {
    'en': ['en'],
    'zh': ['zh', 'cmn', 'yue'],
    'ms': ['ms', 'msa', 'zsm'],
  };

  /// The default/preferred speech_to_text localeId to *request* per app code.
  /// Used when calling `_speech.listen(localeId: ...)`.
  static const Map<String, String> defaultSpeechLocale = {
    'en': 'en_US',
    'zh': 'zh_CN',
    'ms': 'ms_MY',
  };

  /// True if any locale installed on the device matches the given app
  /// language code ('en' / 'zh' / 'ms').
  static bool isSupported(String appCode, List<LocaleName> availableLocales) {
    final variants = _prefixesByAppCode[appCode] ?? [appCode];
    return availableLocales.any((l) {
      final id = l.localeId.toLowerCase();
      return variants.any((v) => id.startsWith(v));
    });
  }

  /// Given an app language code, find the *actual* installed localeId to
  /// pass to `_speech.listen()`. Falls back to the generic default
  /// (e.g. 'zh_CN') if nothing more specific is installed, and to null if
  /// the language isn't supported at all on this device.
  static String? resolveInstalledLocaleId(
      String appCode, List<LocaleName> availableLocales) {
    final variants = _prefixesByAppCode[appCode] ?? [appCode];
    for (final l in availableLocales) {
      final id = l.localeId.toLowerCase();
      if (variants.any((v) => id.startsWith(v))) {
        return l.localeId; // exact installed id, e.g. "cmn-Hans-CN"
      }
    }
    return null;
  }

  /// Debug helper — dump what's actually installed on the device.
  static void logAvailableLocales(List<LocaleName> availableLocales) {
    for (final l in availableLocales) {
      // ignore: avoid_print
      print('speech locale: ${l.localeId} — ${l.name}');
    }
  }
}