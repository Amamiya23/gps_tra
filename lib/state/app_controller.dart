import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppController extends ChangeNotifier {
  static const _themeModeKey = 'app.theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  SharedPreferences? _preferences;

  ThemeMode get themeMode => _themeMode;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    final stored = _preferences?.getString(_themeModeKey);
    _themeMode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  void updateThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    unawaited(_preferences?.setString(_themeModeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    }));
    notifyListeners();
  }
}
