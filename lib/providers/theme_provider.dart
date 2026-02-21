import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider to manage the app's theme mode (dark/light).
/// Persists user preference via SharedPreferences.
class ThemeProvider extends ChangeNotifier {
  static const String _key = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.dark; // Default to dark

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Load saved theme preference from disk.
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  /// Toggle between dark and light mode.
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}
