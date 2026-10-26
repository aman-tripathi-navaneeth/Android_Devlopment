import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// EntityCard: compact card per PART 4.7.
/// Leading icon/initial, title, 2 meta lines, trailing status chip; hairline outline.
class EntityCard extends StatelessWidget {
  final String title;
  final String? subtitle1;
  final String? subtitle2;
  final String? leadingText;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? leftAccentColor;

  const EntityCard({
    super.key,
    required this.title,
    this.subtitle1,
    this.subtitle2,
    this.leadingText,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.leftAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outline, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (leftAccentColor != null)
                  Container(width: 4, color: leftAccentColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (leadingText != null || leadingIcon != null) ...[
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.almond,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.outline,
                                width: 0.8,
                              ),
                            ),
                            child: leadingIcon != null
                                ? Icon(
                                    leadingIcon,
                                    color: AppColors.matchaDeep,
                                    size: 20,
                                  )
                                : Text(
                                    leadingText!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.matchaDeep,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: AppTypography.bodyStrong,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subtitle1 != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle1!,
                                  style: AppTypography.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (subtitle2 != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle2!,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.inkSoft,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 8),
                          trailing!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
