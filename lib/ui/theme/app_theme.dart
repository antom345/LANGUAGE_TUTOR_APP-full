import 'package:flutter/material.dart';

class AppColors {
  static const colorBgMain = Color(0xFFF5F3FF);
  static const colorBgGradientStart = Color(0xFFF5F3FF);
  static const colorBgGradientEnd = Color(0xFFE8FBFF);
  static const colorPrimary = Color(0xFF6A4DFF);
  static const colorPrimaryDark = Color(0xFF28315A);
  static const colorAccentBlue = Color(0xFFA7C8FF);
  static const colorAccentPink = Color(0xFFFFA6C9);
  static const colorAccentYellow = Color(0xFFFFE38A);
  static const colorAccentGreen = Color(0xFF9BE4B3);
  static const colorCardBase = Colors.white;
  static const colorTextPrimary = Color(0xFF111827);
  static const colorTextSecondary = Color(0xFF6B7280);
  static const colorDivider = Color(0xFFE5E7EB);

  static Color get cardBackground => colorCardBase.withOpacity(0.92);
  static const Color languageChipText = Colors.white;
}

class AppRadius {
  static const radiusLarge = 24.0;
  static const radiusMedium = 16.0;
  static const radiusChip = 999.0;
}

class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 12),
          color: Colors.black.withOpacity(0.06),
        ),
      ];
}

class AppTheme {
  static const _fontFamily = 'SF Pro Text';

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.colorPrimary,
        primary: AppColors.colorPrimary,
        secondary: AppColors.colorAccentBlue,
        background: AppColors.colorBgMain,
      ),
    );

    const headlineLarge = TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      color: AppColors.colorTextPrimary,
    );
    const titleMedium = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.colorTextPrimary,
    );
    const bodyMedium = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppColors.colorTextSecondary,
    );
    const labelLarge = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: 0.2,
    );

    final sharedButtonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
    );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: base.textTheme.copyWith(
        headlineLarge: headlineLarge,
        titleMedium: titleMedium,
        bodyMedium: bodyMedium,
        labelLarge: labelLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.colorPrimary,
          foregroundColor: Colors.white,
          shape: sharedButtonShape,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          textStyle: labelLarge,
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.colorPrimary,
          foregroundColor: Colors.white,
          shape: sharedButtonShape,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          textStyle: labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.colorPrimary,
          side: const BorderSide(color: AppColors.colorPrimary, width: 1.3),
          shape: sharedButtonShape,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          textStyle: labelLarge.copyWith(color: AppColors.colorPrimary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
          borderSide: const BorderSide(color: AppColors.colorDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
          borderSide: const BorderSide(color: AppColors.colorDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
          borderSide: const BorderSide(color: AppColors.colorPrimary),
        ),
      ),
      dividerColor: AppColors.colorDivider,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.colorTextPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.colorTextPrimary),
      ),
    );
  }
}
