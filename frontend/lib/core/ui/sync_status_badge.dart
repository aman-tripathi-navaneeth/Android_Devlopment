import 'package:flutter/material.dart';

import '../theme/colors.dart';

enum SyncState { savedLocally, queued, syncing, posted, failed }

/// SyncStatusBadge: visual representation of offline/sync status (PART 4.7, 10.12).
class SyncStatusBadge extends StatelessWidget {
  final SyncState state;

  const SyncStatusBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (state) {
      case SyncState.savedLocally:
        bg = AppColors.neutralBg;
        fg = AppColors.inkSoft;
        label = 'Saved locally';
        icon = Icons.save_outlined;
        break;
      case SyncState.queued:
        bg = AppColors.warningBg;
        fg = AppColors.warningFg;
        label = 'Queued';
        icon = Icons.hourglass_top_rounded;
        break;
      case SyncState.syncing:
        bg = AppColors.pistache;
        fg = AppColors.ink;
        label = 'Syncing…';
        icon = Icons.sync_rounded;
        break;
      case SyncState.posted:
        bg = AppColors.successBg;
        fg = AppColors.successFg;
        label = 'Posted';
        icon = Icons.check_circle_outline;
        break;
      case SyncState.failed:
        bg = AppColors.dangerBg;
        fg = AppColors.dangerFg;
        label = 'Failed';
        icon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.outline, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
