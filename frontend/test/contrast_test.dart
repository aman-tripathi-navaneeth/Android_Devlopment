import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_app/core/theme/colors.dart';

double _luminance(Color color) {
  double sRGB(double channel) {
    if (channel <= 0.03928) {
      return channel / 12.92;
    } else {
      return pow((channel + 0.055) / 1.055, 2.4).toDouble();
    }
  }

  final r = sRGB(color.red / 255.0);
  final g = sRGB(color.green / 255.0);
  final b = sRGB(color.blue / 255.0);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color c1, Color c2) {
  final l1 = _luminance(c1);
  final l2 = _luminance(c2);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Part 4.2 WCAG Contrast Verification Unit Tests', () {
    test('ink on canvas should exceed 4.5:1', () {
      final ratio = _contrastRatio(AppColors.ink, AppColors.canvas);
      expect(ratio, greaterThan(4.5));
    });

    test('ink on almond should exceed 4.5:1', () {
      final ratio = _contrastRatio(AppColors.ink, AppColors.almond);
      expect(ratio, greaterThan(4.5));
    });

    test('ink on vanilla should exceed 4.5:1', () {
      final ratio = _contrastRatio(AppColors.ink, AppColors.vanilla);
      expect(ratio, greaterThan(4.5));
    });

    test('ink on matcha should exceed 4.5:1', () {
      final ratio = _contrastRatio(AppColors.ink, AppColors.matcha);
      expect(ratio, greaterThan(4.5));
    });

    test('white on matchaDeep should exceed 4.5:1 for buttons', () {
      final ratio = _contrastRatio(Colors.white, AppColors.matchaDeep);
      expect(ratio, greaterThan(4.5));
    });

    test('matchaDeep on surface should exceed 4.5:1', () {
      final ratio = _contrastRatio(AppColors.matchaDeep, AppColors.surface);
      expect(ratio, greaterThan(4.5));
    });

    test('inkSoft on surface should exceed 4.5:1', () {
      final ratio = _contrastRatio(AppColors.inkSoft, AppColors.surface);
      expect(ratio, greaterThan(4.5));
    });

    test('carob on canvas should exceed 4.5:1', () {
      final ratio = _contrastRatio(AppColors.carob, AppColors.canvas);
      expect(ratio, greaterThan(4.5));
    });

    test('danger fg on danger bg should exceed 4.5:1', () {
      final ratio = _contrastRatio(AppColors.dangerFg, AppColors.dangerBg);
      expect(ratio, greaterThan(4.5));
    });

    test('warning fg on warning bg should exceed 4.5:1', () {
      final ratio = _contrastRatio(AppColors.warningFg, AppColors.warningBg);
      expect(ratio, greaterThan(4.5));
    });

    test('success fg on success bg should exceed 4.5:1', () {
      final ratio = _contrastRatio(AppColors.successFg, AppColors.successBg);
      expect(ratio, greaterThan(4.5));
    });
  });
}
