import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

enum BannerType { info, success, warning, error, neutral }

/// InlineBanner: alert notice inside screens (PART 4.7).
class InlineBanner extends StatelessWidget {
  final String message;
  final BannerType type;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const InlineBanner({
    super.key,
    String? message,
    String? text,
    this.type = BannerType.info,
    this.onRetry,
    this.retryLabel,
  }) : message = message ?? text ?? '';

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (type) {
      case BannerType.success:
        bg = AppColors.successBg;
        fg = AppColors.successFg;
        icon = Icons.check_circle_outline_rounded;
        break;
      case BannerType.warning:
        bg = AppColors.warningBg;
        fg = AppColors.warningFg;
        icon = Icons.warning_amber_rounded;
        break;
      case BannerType.error:
        bg = AppColors.dangerBg;
        fg = AppColors.dangerFg;
        icon = Icons.error_outline_rounded;
        break;
      case BannerType.neutral:
        bg = AppColors.neutralBg;
        fg = AppColors.neutralFg;
        icon = Icons.info_outline_rounded;
        break;
      case BannerType.info:
        bg = AppColors.almond;
        fg = AppColors.ink;
        icon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: fg,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(40, 32),
              ),
              onPressed: onRetry,
              child: Text(
                retryLabel ?? 'Retry',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
