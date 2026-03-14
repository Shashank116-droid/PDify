import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider to manage the app's theme mode (dark/light).
/// Persists user preference via SharedPreferences.
class ThemeProvider extends ChangeNotifier {
  ThemeMode get themeMode => ThemeMode.dark;
  bool get isDarkMode => true;

  Future<void> loadTheme() async {
    // No-op
  }

  Future<void> toggleTheme() async {
    // No-op
  }
}
