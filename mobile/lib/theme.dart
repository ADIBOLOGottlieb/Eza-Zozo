import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Couleurs Eza Zozo : blanc, bleu, jaune et noir (palette Material 3, clair et sombre).
class AppColors {
  // Couleurs de la marque
  static const blue = Color(0xFF2F6BFF);
  static const darkBlue = Color(0xFF1A47C7);
  static const yellow = Color(0xFFFFC21A);
  static const ink = Color(0xFF0F1115);
  /// Teinte bleue très claire (puces, encadrés) du thème clair.
  static const sky = Color(0xFFEAF1FF);
  /// Gris du thème clair uniquement : dans les widgets, préférer [mutedColor] (lisible en sombre).
  static const muted = Color(0xFF6B7280);
  static const green = Color(0xFF2E9E5B);
  /// Actions destructrices et erreurs (supprimer, déconnexion, refus).
  static const danger = Color(0xFFD32F2F);

  // Material 3 semantic colors for light theme
  static const lightPrimary = blue;
  static const lightOnPrimary = Colors.white;
  static const lightPrimaryContainer = Color(0xFFDCE6FF);
  static const lightOnPrimaryContainer = Color(0xFF001A56);

  static const lightSecondary = yellow;
  static const lightOnSecondary = ink;
  static const lightSecondaryContainer = Color(0xFFFFF1C2);
  static const lightOnSecondaryContainer = Color(0xFF3A2C00);

  static const lightTertiary = green;
  static const lightOnTertiary = Colors.white;
  static const lightTertiaryContainer = Color(0xFFA5F8D4);
  static const lightOnTertiaryContainer = Color(0xFF002015);

  static const lightBackground = Color(0xFFF7F9FC);
  static const lightSurface = Colors.white;
  static const lightSurfaceVariant = Color(0xFFE7ECF4);
  static const lightOnSurface = ink;
  static const lightOnSurfaceVariant = muted;
  static const lightOutline = Color(0xFF9AA3B2);

  // Material 3 semantic colors for dark theme
  static const darkPrimary = Color(0xFF8FB0FF);
  static const darkOnPrimary = Color(0xFF002A7A);
  static const darkPrimaryContainer = darkBlue;
  static const darkOnPrimaryContainer = Color(0xFFDCE6FF);

  static const darkSecondary = yellow;
  static const darkOnSecondary = Color(0xFF2B2100);
  static const darkSecondaryContainer = Color(0xFF5C4600);
  static const darkOnSecondaryContainer = Color(0xFFFFF1C2);

  static const darkTertiary = Color(0xFF8ADBB1);
  static const darkOnTertiary = Color(0xFF003829);
  static const darkTertiaryContainer = Color(0xFF00523D);
  static const darkOnTertiaryContainer = Color(0xFFA5F8D4);

  static const darkBackground = Color(0xFF0B0D12);
  static const darkSurface = Color(0xFF151922);
  static const darkSurfaceVariant = Color(0xFF2A303C);
  static const darkOnSurface = Color(0xFFEDF1F7);
  static const darkOnSurfaceVariant = Color(0xFFA9B2C1);
  static const darkOutline = Color(0xFF6E7787);
}

/// Texte secondaire (gris) adapté au thème courant, clair ou sombre.
Color mutedColor(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;

/// Build Material 3 theme with light mode
ThemeData buildLightTheme() {
  final scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.lightPrimary,
    onPrimary: AppColors.lightOnPrimary,
    primaryContainer: AppColors.lightPrimaryContainer,
    onPrimaryContainer: AppColors.lightOnPrimaryContainer,
    secondary: AppColors.lightSecondary,
    onSecondary: AppColors.lightOnSecondary,
    secondaryContainer: AppColors.lightSecondaryContainer,
    onSecondaryContainer: AppColors.lightOnSecondaryContainer,
    tertiary: AppColors.lightTertiary,
    onTertiary: AppColors.lightOnTertiary,
    tertiaryContainer: AppColors.lightTertiaryContainer,
    onTertiaryContainer: AppColors.lightOnTertiaryContainer,
    error: Colors.red.shade700,
    onError: Colors.white,
    errorContainer: Colors.red.shade100,
    onErrorContainer: Colors.red.shade900,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightOnSurface,
    // Paliers de surface (champs, encadrés, boutons désactivés), distincts des cartes.
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF9FBFE),
    surfaceContainer: Color(0xFFF3F6FB),
    surfaceContainerHigh: Color(0xFFEEF2F8),
    surfaceContainerHighest: AppColors.lightSurfaceVariant,
    onSurfaceVariant: AppColors.lightOnSurfaceVariant,
    outline: AppColors.lightOutline,
    outlineVariant: Color(0xFFD5DCE6),
    scrim: Colors.black,
    inverseSurface: Color(0xFF1B1F27),
    onInverseSurface: Color(0xFFF1F4F9),
    inversePrimary: Color(0xFF9DBBFF),
    surfaceTint: AppColors.lightPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins',
    brightness: Brightness.light,
    colorScheme: scheme,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    scaffoldBackgroundColor: AppColors.lightBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        elevation: 2,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      side: BorderSide.none,
      labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      circularTrackColor: scheme.surfaceContainerHighest,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: scheme.surface,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
    ),
  );
}

/// Build Material 3 theme with dark mode
ThemeData buildDarkTheme() {
  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkOnPrimary,
    primaryContainer: AppColors.darkPrimaryContainer,
    onPrimaryContainer: AppColors.darkOnPrimaryContainer,
    secondary: AppColors.darkSecondary,
    onSecondary: AppColors.darkOnSecondary,
    secondaryContainer: AppColors.darkSecondaryContainer,
    onSecondaryContainer: AppColors.darkOnSecondaryContainer,
    tertiary: AppColors.darkTertiary,
    onTertiary: AppColors.darkOnTertiary,
    tertiaryContainer: AppColors.darkTertiaryContainer,
    onTertiaryContainer: AppColors.darkOnTertiaryContainer,
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkOnSurface,
    surfaceContainerLowest: Color(0xFF080A0E),
    surfaceContainerLow: Color(0xFF12161E),
    surfaceContainer: Color(0xFF1A1F29),
    surfaceContainerHigh: Color(0xFF222834),
    surfaceContainerHighest: AppColors.darkSurfaceVariant,
    onSurfaceVariant: AppColors.darkOnSurfaceVariant,
    outline: AppColors.darkOutline,
    outlineVariant: Color(0xFF353C49),
    scrim: Colors.black,
    inverseSurface: Color(0xFFEDF1F7),
    onInverseSurface: Color(0xFF1B1F27),
    inversePrimary: AppColors.blue,
    surfaceTint: AppColors.darkPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins',
    brightness: Brightness.dark,
    colorScheme: scheme,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    scaffoldBackgroundColor: AppColors.darkBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        elevation: 2,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outline),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.5), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      side: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
      labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      circularTrackColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      linearTrackColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: scheme.surface,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
    ),
  );
}

/// Build light theme (backward compatibility)
ThemeData buildTheme() => buildLightTheme();
