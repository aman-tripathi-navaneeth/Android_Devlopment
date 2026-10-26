import 'package:flutter/material.dart';

import '../theme/colors.dart';

enum StatusType {
  draft,
  sent,
  partiallyReceived,
  received,
  cancelled,
  posted,
  pending,
  failed,
  active,
  inactive,
}

/// StatusChip strictly mapped per PART 4.3 of the Master Rulebook.
class StatusChip extends StatelessWidget {
  final StatusType status;
  final String? customLabel;

  const StatusChip({super.key, required this.status, this.customLabel});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData? icon;
    String label = customLabel ?? _defaultLabel(status);
    bool isDashed = false;
    Color? leftAccent;

    switch (status) {
      case StatusType.draft:
        bg = AppColors.neutralBg;
        fg = AppColors.ink;
        icon = Icons.edit_note_rounded;
        isDashed = true;
        break;
      case StatusType.sent:
        bg = AppColors.pistache;
        fg = AppColors.ink;
        icon = Icons.send_rounded;
        break;
      case StatusType.partiallyReceived:
        bg = AppColors.warningBg;
        fg = AppColors.warningFg;
        icon = Icons.hourglass_bottom_rounded;
        leftAccent = AppColors.chai;
        break;
      case StatusType.received:
        bg = AppColors.successBg;
        fg = AppColors.successFg;
        icon = Icons.check_circle_rounded;
        break;
      case StatusType.cancelled:
        bg = AppColors.neutralBg;
        fg = AppColors.neutralFg;
        icon = Icons.cancel_outlined;
        break;
      case StatusType.posted:
        bg = AppColors.successBg;
        fg = AppColors.successFg;
        icon = Icons.done_all_rounded;
        break;
      case StatusType.pending:
        bg = AppColors.warningBg;
        fg = AppColors.warningFg;
        icon = Icons.schedule_rounded;
        break;
      case StatusType.failed:
        bg = AppColors.dangerBg;
        fg = AppColors.dangerFg;
        icon = Icons.error_outline_rounded;
        break;
      case StatusType.active:
        bg = AppColors.successBg;
        fg = AppColors.successFg;
        icon = Icons.circle;
        break;
      case StatusType.inactive:
        bg = AppColors.neutralBg;
        fg = AppColors.neutralFg;
        icon = Icons.circle_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              leftAccent ??
              (isDashed ? AppColors.outlineStrong : AppColors.outline),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: status == StatusType.active || status == StatusType.inactive
                  ? 7
                  : 12,
              color: fg,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  String _defaultLabel(StatusType type) {
    switch (type) {
      case StatusType.draft:
        return 'Draft';
      case StatusType.sent:
        return 'Sent';
      case StatusType.partiallyReceived:
        return 'Partially Received';
      case StatusType.received:
        return 'Received';
      case StatusType.cancelled:
        return 'Cancelled';
      case StatusType.posted:
        return 'Posted';
      case StatusType.pending:
        return 'Pending';
      case StatusType.failed:
        return 'Failed';
      case StatusType.active:
        return 'Active';
      case StatusType.inactive:
        return 'Inactive';
    }
  }
}
