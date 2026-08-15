import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_cabinet/providers/language_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('LanguageProvider', () {
    test('normalizes locale variants like zh_CN and ms_MY to supported codes',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await prefs.setString('selected_language_code', 'zh_CN');
      final zhProvider = LanguageProvider(prefs);
      expect(zhProvider.locale.languageCode, 'zh');

      await prefs.setString('selected_language_code', 'ms_MY');
      final msProvider = LanguageProvider(prefs);
      expect(msProvider.locale.languageCode, 'ms');
    });

    test('falls back to English for unsupported saved locale codes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await prefs.setString('selected_language_code', 'fr');
      final provider = LanguageProvider(prefs);
      expect(provider.locale.languageCode, 'en');
    });
  });
}
