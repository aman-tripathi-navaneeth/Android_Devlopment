import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'language_toggle.dart';

/// AppTopBar: left-aligned title, subtitle, actions and language toggle (PART 4.7).
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showLanguageToggle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showLanguageToggle = true,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final Widget? effectiveLeading =
        leading ??
        (automaticallyImplyLeading && canPop
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.ink,
                  size: 22,
                ),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outline, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Row(
            children: [
              if (effectiveLeading != null) ...[
                effectiveLeading,
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.title.copyWith(fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (showLanguageToggle) ...[
                const LanguageToggle(),
                const SizedBox(width: 6),
              ],
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}
