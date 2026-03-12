import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../models/activity.dart';
import '../utils/theme.dart';

class ActivityFeedScreen extends StatelessWidget {
  const ActivityFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Feed'),
        centerTitle: true,
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          final activities = provider.activities;

          if (activities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.history_rounded, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                   const SizedBox(height: 16),
                   const Text('No recent activity', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return _ActivityItem(activity: activity);
            },
          );
        },
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Activity activity;
  const _ActivityItem({required this.activity});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    
    switch (activity.type) {
      case ActivityType.expenseAdded:
        icon = Icons.add_circle_outline_rounded;
        color = AppColors.brand;
        break;
      case ActivityType.expenseUpdated:
        icon = Icons.edit_notifications_outlined;
        color = Colors.orange;
        break;
      case ActivityType.expenseDeleted:
        icon = Icons.delete_outline_rounded;
        color = AppColors.error;
        break;
      case ActivityType.settlementAdded:
        icon = Icons.handshake_outlined;
        color = AppColors.success;
        break;
      case ActivityType.commentAdded:
        icon = Icons.comment_outlined;
        color = Colors.purple;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? AppColors.textPrimaryDark 
                          : AppColors.textPrimaryLight,
                      fontSize: 14,
                    ),
                    children: [
                      TextSpan(
                        text: activity.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: ' ${activity.description}'),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, hh:mm a').format(activity.timestamp),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
