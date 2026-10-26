import 'package:flutter/material.dart';

import 'colors.dart';

/// Typography scale specified in PART 4.4 of Master Rulebook.
abstract class AppTypography {
  static const List<String> fontFallbacks = [
    'Noto Sans Telugu',
    'Roboto',
    'sans-serif',
  ];

  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.carob,
    letterSpacing: -0.2,
    height: 1.3,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    letterSpacing: -0.1,
    height: 1.35,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle screenTitle = title;

  static const TextStyle section = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    height: 1.4,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle subheading = section;

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
    height: 1.5, // Required for Telugu line spacing
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    height: 1.5,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.inkSoft,
    height: 1.4,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.inkSoft,
    height: 1.35,
    fontFamilyFallback: fontFallbacks,
  );

  /// Tabular numerals for money, rates, and stock quantities
  static const TextStyle tabularNumbers = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle tabularNumbersLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
    fontFamilyFallback: fontFallbacks,
  );
}
