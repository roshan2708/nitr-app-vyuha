import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeController extends GetxController {
  final _storage = GetStorage();
  final _key = 'isDarkMode';

  /// Reactive variable to hold the dark mode state
  final isDarkMode = true.obs;

  /// Returns the saved theme mode on app launch
  ThemeMode get initialThemeMode =>
      _loadThemeFromStorage() ? ThemeMode.dark : ThemeMode.light;

  @override
  void onInit() {
    super.onInit();
    // Load the saved theme when the controller is initialized
    isDarkMode.value = _loadThemeFromStorage();
  }

  /// Toggles the theme and saves the preference
  void toggleTheme() {
    isDarkMode.value = !isDarkMode.value;
    _saveThemeToStorage(isDarkMode.value);
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  /// Private helper to load the theme
  bool _loadThemeFromStorage() {
    // Default to dark mode (true) if no preference is saved
    return _storage.read(_key) ?? true;
  }

  /// Private helper to save the theme
  void _saveThemeToStorage(bool isDark) {
    _storage.write(_key, isDark);
  }
}