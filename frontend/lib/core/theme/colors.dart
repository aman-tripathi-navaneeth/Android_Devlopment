import 'package:flutter/material.dart';

/// Design tokens strictly conforming to PART 4 of the Master Rulebook.
/// High contrast ratios verified against WCAG AA/AAA (> 4.5:1).
abstract class AppColors {
  // BRAND CORE
  static const Color matcha = Color(0xFF809671);
  static const Color almond = Color(0xFFE5E0D8);
  static const Color pistache = Color(0xFFB3B792);
  static const Color chai = Color(0xFFD2AB80);
  static const Color carob = Color(0xFF725C3A);
  static const Color vanilla = Color(0xFFE5D2B8);

  // DERIVED TOKENS
  static const Color canvas = Color(0xFFF4F1EA);
  static const Color surface = Color(0xFFFBF9F5);
  static const Color outline = Color(0xFFD8D1C4);
  static const Color outlineStrong = Color(0xFFB9B09F);
  static const Color ink = Color(0xFF2B2118);
  static const Color inkSoft = Color(0xFF6B5A44);
  static const Color matchaDeep = Color(0xFF5B7050);
  static const Color matchaPressed = Color(0xFF4F6345);
  static const Color onMatcha = Color(0xFF2B2118);

  // STATUS TOKENS (Muted, non-neon, WCAG verified)
  static const Color successBg = Color(0xFFDDE9D3);
  static const Color successFg = Color(0xFF2F5E3A);

  static const Color warningBg = Color(0xFFF6E7C1);
  static const Color warningFg = Color(0xFF7A5B14);

  static const Color dangerBg = Color(0xFFF4DAD5);
  static const Color dangerFg = Color(0xFFA33B2F);

  static const Color neutralBg = Color(0xFFE6E2DA);
  static const Color neutralFg = Color(0xFF5E5445);
}
