import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totp_authenticator/providers/config_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConfigProvider Tests', () {
    test('default state is ThemeMode.dark and system language', () {
      SharedPreferences.setMockInitialValues({});
      final provider = ConfigProvider(autoInit: false);

      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.languageCode, 'system');
      expect(provider.locale, isNull);
    });

    test('initializes from persistent preferences correctly', () async {
      SharedPreferences.setMockInitialValues({
        'config_theme_mode': 'light',
        'config_language': 'vi',
      });

      final provider = ConfigProvider(autoInit: false);
      await provider.init();

      expect(provider.themeMode, ThemeMode.light);
      expect(provider.languageCode, 'vi');
      expect(provider.locale, const Locale('vi'));
      expect(provider.isInitialized, isTrue);
    });

    test('initializes system theme mode and en language', () async {
      SharedPreferences.setMockInitialValues({
        'config_theme_mode': 'system',
        'config_language': 'en',
      });

      final provider = ConfigProvider(autoInit: false);
      await provider.init();

      expect(provider.themeMode, ThemeMode.system);
      expect(provider.languageCode, 'en');
      expect(provider.locale, const Locale('en'));
    });

    test('setThemeMode updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ConfigProvider(autoInit: false);
      await provider.init();

      bool notified = false;
      provider.addListener(() => notified = true);

      await provider.setThemeMode(ThemeMode.light);

      expect(provider.themeMode, ThemeMode.light);
      expect(notified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('config_theme_mode'), 'light');
    });

    test('setLanguageCode updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ConfigProvider(autoInit: false);
      await provider.init();

      bool notified = false;
      provider.addListener(() => notified = true);

      await provider.setLanguageCode('en');

      expect(provider.languageCode, 'en');
      expect(provider.locale, const Locale('en'));
      expect(notified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('config_language'), 'en');
    });
  });
}
