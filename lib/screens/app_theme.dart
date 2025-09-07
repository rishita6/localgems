import 'package:flutter/material.dart';

class AppColors {
  static const lilacLight = Color(0xFFF4F2FF);
  static const lilacDark = Color(0xFF6D9EEB);
  static const reddishPink = Color(0xFFE85D75);
  static const darkLavender = Color(0xFF2D2A41);
  static const softGray = Color(0xFF7A7D9C);
  static const cardBackground = Colors.white;
}

class AppTheme {
  static ThemeData theme = ThemeData(
    scaffoldBackgroundColor: AppColors.lilacLight,
    primaryColor: AppColors.reddishPink,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lilacLight,
      foregroundColor: AppColors.darkLavender,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.darkLavender),
      bodySmall: TextStyle(color: AppColors.softGray),
    ),
  );
}
