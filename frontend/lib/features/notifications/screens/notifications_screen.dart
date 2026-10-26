import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/ui/app_top_bar.dart';

/// Notification Centre Screen - Section 10.11
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Low stock alert: Augmentin 625 Duo',
      'body': 'Current balance is 25 tablets, below the configured threshold of 30 tablets.',
      'time': '10 mins ago',
      'isRead': false,
      'type': 'stock',
    },
    {
      'title': 'Delivery pending: PO-2026-000101',
      'body': 'Sent to Sri Venkateswara Pharma Distributors. 210 units awaiting receipt.',
      'time': '2 hours ago',
      'isRead': false,
      'type': 'po',
    },
    {
      'title': 'Customer refill reminder due today',
      'body': 'Scheduled prescription refill due for regular customer account.',
      'time': 'Today, 09:00 AM',
      'isRead': true,
      'type': 'refill',
    },
    {
      'title': 'Batch expiry warning',
      'body': 'Augmentin 625 (Batch AG-2024) reaches expiry within 42 days.',
      'time': 'Yesterday',
      'isRead': true,
      'type': 'expiry',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppTopBar(
        title: 'Notification Center',
        showLanguageToggle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            child: const Text('Mark all read'),
            onPressed: () {
              setState(() {
                for (var n in _notifications) {
                  n['isRead'] = true;
                }
              });
            },
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final n = _notifications[i];
          final isRead = n['isRead'] as bool;

          IconData icon = Icons.notifications_outlined;
          Color iconColor = AppColors.matchaDeep;
          if (n['type'] == 'stock') {
            icon = Icons.warning_amber_rounded;
            iconColor = AppColors.dangerFg;
          } else if (n['type'] == 'po') {
            icon = Icons.hourglass_top_rounded;
            iconColor = AppColors.warningFg;
          } else if (n['type'] == 'refill') {
            icon = Icons.medication_outlined;
            iconColor = AppColors.matchaDeep;
          }

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isRead
                  ? AppColors.surface
                  : AppColors.vanilla.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isRead ? AppColors.outline : AppColors.outlineStrong,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              n['title'],
                              style: AppTypography.bodyStrong.copyWith(
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            n['time'],
                            style: AppTypography.caption.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n['body'],
                        style: AppTypography.caption.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
