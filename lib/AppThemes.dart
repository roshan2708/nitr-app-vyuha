import 'package:flutter/material.dart';

class AppThemes {
  // --- Constants for your colors ---
  static const Color _primaryLight = Color(0xFF007A9B);
  static const Color _primaryDark = Color(0xFF9ECAD6);

  static const Color _accentOrange = Color(0xFFF4991A);
  static const Color _accentBlue = Color(0xFF6B7FFF);

  static const Color _scaffoldLight = Color(0xFFF4F4F4);
  static const Color _scaffoldDark = Color(0xFF0D0D0D);

  static const Color _appBarLight = Color(0xFFFFFFFF);
  static const Color _appBarDark = Color(0xFF1A1A1A);

  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _cardDark = Color(0xFF1A1A1A);

  static const Color _dialogLight = Color(0xFFFDFDFD);
  static const Color _dialogDark = Color(0xFF1A1A1A);

  static const Color _textLight = Color(0xFF000000);
  static const Color _textDark = Color(0xFFFFFFFF);

  static const Color _textSecondaryLight = Colors.black54;
  static const Color _textSecondaryDark = Colors.white54;

  static const Color _iconLight = Colors.black54;
  static const Color _iconDark = Colors.white70;

  static const Color _gridLineLight = Color(0xFFE0E0E0);
  static const Color _gridLineDark = Color(0xFF1A1A1A);

  // --- Light Theme Definition ---
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: _scaffoldLight,
    primaryColor: _primaryLight,
    fontFamily: 'sans-serif', // Ensure you have this font or change it
    colorScheme: const ColorScheme.light(
      primary: _primaryLight,
      secondary: _primaryLight, // Used for zoom, node borders
      onSecondary: Colors.white, // Text on _primaryLight
      surface: _cardLight,
      onSurface: _textLight,
      background: _scaffoldLight,
      onBackground: _textLight,
      error: Colors.redAccent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _appBarLight,
      elevation: 0,
      iconTheme: IconThemeData(color: _iconLight),
      titleTextStyle: TextStyle(
          color: _textLight, fontSize: 18, fontWeight: FontWeight.w500),
    ),
    iconTheme: const IconThemeData(color: _iconLight),
    textTheme: const TextTheme(
      titleLarge: TextStyle(color: _textLight), // Dialog titles
      bodyLarge: TextStyle(color: _textLight), // Search field text
      bodyMedium: TextStyle(color: _textLight), // Dialog text
      bodySmall: TextStyle(color: _textSecondaryLight), // StatChip
      labelMedium: TextStyle(color: _textSecondaryLight), // Dialog labels
    ),
    hintColor: Colors.black38,
    dialogBackgroundColor: _dialogLight,
    popupMenuTheme: const PopupMenuThemeData(color: _dialogLight),
    bottomSheetTheme:
        const BottomSheetThemeData(modalBackgroundColor: _dialogLight),
    shadowColor: Colors.grey.withOpacity(0.2),
    extensions: const <ThemeExtension<dynamic>>[
      CustomTheme(
        accentOrange: _accentOrange,
        accentBlue: _accentBlue,
        gridLines: _gridLineLight,
      ),
    ],
  );

  // --- Dark Theme Definition ---
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _scaffoldDark,
    primaryColor: _primaryDark,
    fontFamily: 'sans-serif',
    colorScheme: const ColorScheme.dark(
      primary: _primaryDark,
      secondary: _primaryDark, // Used for zoom, node borders
      onSecondary: Colors.white, // Text on _primaryDark
      surface: _cardDark,
      onSurface: _textDark,
      background: _scaffoldDark,
      onBackground: _textDark,
      error: Color(0xFFFF6B9D), // Pinkish red
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _appBarDark,
      elevation: 0,
      iconTheme: IconThemeData(color: _iconDark),
      titleTextStyle: TextStyle(
          color: _textDark, fontSize: 18, fontWeight: FontWeight.w500),
    ),
    iconTheme: const IconThemeData(color: _iconDark),
    textTheme: const TextTheme(
      titleLarge: TextStyle(color: _textDark), // Dialog titles
      bodyLarge: TextStyle(color: _textDark), // Search field text
      bodyMedium: TextStyle(color: _textDark), // Dialog text
      bodySmall: TextStyle(color: _textSecondaryDark), // StatChip
      labelMedium: TextStyle(color: _textSecondaryDark), // Dialog labels
    ),
    hintColor: Colors.white38,
    dialogBackgroundColor: _dialogDark,
    popupMenuTheme: const PopupMenuThemeData(color: _dialogDark),
    bottomSheetTheme:
        const BottomSheetThemeData(modalBackgroundColor: _dialogDark),
    shadowColor: Colors.black.withOpacity(0.3),
    extensions: const <ThemeExtension<dynamic>>[
      CustomTheme(
        accentOrange: _accentOrange,
        accentBlue: _accentBlue,
        gridLines: _gridLineDark,
      ),
    ],
  );
}

// --- Custom Theme Extension ---
// This is a clean way to pass non-standard theme colors
@immutable
class CustomTheme extends ThemeExtension<CustomTheme> {
  const CustomTheme({
    required this.accentOrange,
    required this.accentBlue,
    required this.gridLines,
  });

  final Color accentOrange;
  final Color accentBlue;
  final Color gridLines;

  @override
  CustomTheme copyWith({Color? accentOrange, Color? accentBlue, Color? gridLines}) {
    return CustomTheme(
      accentOrange: accentOrange ?? this.accentOrange,
      accentBlue: accentBlue ?? this.accentBlue,
      gridLines: gridLines ?? this.gridLines,
    );
  }

  @override
  CustomTheme lerp(ThemeExtension<CustomTheme>? other, double t) {
    if (other is! CustomTheme) {
      return this;
    }
    return CustomTheme(
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t)!,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t)!,
      gridLines: Color.lerp(gridLines, other.gridLines, t)!,
    );
  }
}