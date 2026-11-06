import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State management for app appearance (theme mode) and display language preferences.
class ConfigProvider extends ChangeNotifier {
  static const _prefThemeMode = 'config_theme_mode';
  static const _prefLanguage = 'config_language';

  ThemeMode _themeMode = ThemeMode.dark;
  String _languageCode = 'system'; // 'system', 'vi', 'en'
  bool _isInitialized = false;

  ConfigProvider({bool autoInit = true}) {
    if (autoInit) {
      init();
    }
  }

  ThemeMode get themeMode => _themeMode;
  String get languageCode => _languageCode;
  bool get isInitialized => _isInitialized;

  /// Returns active Locale or null for system default locale.
  Locale? get locale {
    if (_languageCode == 'vi') return const Locale('vi');
    if (_languageCode == 'en') return const Locale('en');
    return null;
  }

  /// Initializes preferences from persistent storage.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_prefThemeMode);
      if (savedTheme != null) {
        switch (savedTheme) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'system':
            _themeMode = ThemeMode.system;
            break;
          case 'dark':
          default:
            _themeMode = ThemeMode.dark;
            break;
        }
      }

      final savedLang = prefs.getString(_prefLanguage);
      if (savedLang != null && ['system', 'vi', 'en'].contains(savedLang)) {
        _languageCode = savedLang;
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing ConfigProvider: $e');
    }
  }

  /// Sets the application theme mode and persists it to SharedPreferences.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'dark';
      if (mode == ThemeMode.light) val = 'light';
      if (mode == ThemeMode.system) val = 'system';
      await prefs.setString(_prefThemeMode, val);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  /// Sets display language ('system', 'vi', 'en') and persists it to SharedPreferences.
  Future<void> setLanguageCode(String code) async {
    if (_languageCode == code || !['system', 'vi', 'en'].contains(code)) return;
    _languageCode = code;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLanguage, code);
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }
}
