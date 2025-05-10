import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // You need to add a definition for darkTheme:
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue, // Or a different color scheme for dark mode
    // Example: use a different primary color for dark mode
    // primaryColor: Colors.indigo,
    // scaffoldBackgroundColor: Colors.grey[850],
    // cardColor: Colors.grey[800],
    // textTheme: Typography.whiteMountainView, // Example dark theme text
    // appBarTheme: AppBarTheme(
    //   color: Colors.grey[900],
    // ),
    // ... other dark theme properties
  );
  static ThemeData lightTheme = ThemeData(
    primarySwatch: MaterialColor(AppColors.primaryColor.value, <int, Color>{
      50: AppColors.primaryColor.withOpacity(0.1),
      100: AppColors.primaryColor.withOpacity(0.2),
      200: AppColors.primaryColor.withOpacity(0.3),
      300: AppColors.primaryColor.withOpacity(0.4),
      400: AppColors.primaryColor.withOpacity(0.5),
      500: AppColors.primaryColor.withOpacity(0.6),
      600: AppColors.primaryColor.withOpacity(0.7),
      700: AppColors.primaryColor.withOpacity(0.8),
      800: AppColors.primaryColor.withOpacity(0.9),
      900: AppColors.primaryColor,
    }),
    primaryColor: AppColors.primaryColor,
    primaryColorLight: AppColors.primaryColorLight,
    colorScheme: ColorScheme.fromSwatch().copyWith(
      secondary: AppColors.accentColor,
    ),
    scaffoldBackgroundColor: AppColors.backgroundColor,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.textColorPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textColorPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textColorPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.textColorPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.textColorSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: AppButtonStyles.primaryButtonStyle,
    ),
    // Define otros temas para botones, AppBar, etc. si es necesario
  );

  // Puedes definir un tema oscuro aquí si lo necesitas en el futuro
}

class AppButtonStyles {
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    foregroundColor: AppColors.buttonTextColor,
    backgroundColor: AppColors.primaryColor,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    textStyle: const TextStyle(fontSize: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}
