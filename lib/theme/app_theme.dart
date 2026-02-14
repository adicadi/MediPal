import 'package:flutter/material.dart';

class AppTheme {
  static const Color _seed = Color(0xFF2F5DAD);
  static const Color _lightBg = Color(0xFFEDEDEF);
  static const Color _darkBg = Color(0xFF0D1016);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final colorScheme = brightness == Brightness.light
        ? baseScheme.copyWith(
            surface: const Color(0xFFF4F5F8),
            surfaceContainer: const Color(0xFFF0F1F5),
            surfaceContainerHighest: const Color(0xFFE6E9F0),
            outline: const Color(0xFFD0D4DF),
            outlineVariant: const Color(0xFFE0E3EA),
          )
        : baseScheme.copyWith(
            surface: const Color(0xFF11151D),
            surfaceContainerLowest: const Color(0xFF0B0E14),
            surfaceContainerLow: const Color(0xFF141922),
            surfaceContainer: const Color(0xFF181F2B),
            surfaceContainerHigh: const Color(0xFF1D2532),
            surfaceContainerHighest: const Color(0xFF232D3D),
            outline: const Color(0xFF313D50),
            outlineVariant: const Color(0xFF273244),
          );

    final textThemeBase = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;
    final textTheme = textThemeBase.apply(
      bodyColor: brightness == Brightness.dark
          ? colorScheme.onSurface
          : const Color(0xFF1B1F27),
      displayColor: brightness == Brightness.dark
          ? colorScheme.onSurface
          : const Color(0xFF1B1F27),
      fontFamily: 'Roboto',
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      textTheme: textTheme,
      scaffoldBackgroundColor:
          brightness == Brightness.light ? _lightBg : _darkBg,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: colorScheme.surface.withValues(alpha: 0.92),
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          fontFamily: 'Roboto',
          letterSpacing: -0.5,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: brightness == Brightness.dark ? 1 : 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.10)
                : colorScheme.outlineVariant,
          ),
        ),
        color: brightness == Brightness.dark
            ? colorScheme.surfaceContainerLow.withValues(alpha: 0.94)
            : colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: brightness == Brightness.dark
            ? const Color(0xFF060D22).withValues(alpha: 0.40)
            : Colors.black.withValues(alpha: 0.08),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        minLeadingWidth: 28,
        dense: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontFamily: 'Roboto',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          foregroundColor: const Color(0xFF4E535F),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
