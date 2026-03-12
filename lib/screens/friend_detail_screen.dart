import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../models/app_user.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import 'expense_detail_screen.dart';
import '../services/firestore_service.dart';

class FriendDetailScreen extends StatelessWidget {
  final AppUser friend;

  const FriendDetailScreen({super.key, required this.friend});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final balance = provider.getBalanceWithFriend(friend.uid);
    final currentUserId = provider.currentUserId;

    // Filter expenses shared between current user and this friend
    final sharedExpenses = provider.expenses.where((e) =>
        (e.paidByUserId == friend.uid && e.splits.containsKey(currentUserId)) ||
        (e.paidByUserId == currentUserId && e.splits.containsKey(friend.uid))).toList();
    sharedExpenses.sort((a, b) => b.date.compareTo(a.date));

    final isOwed = balance > 0;
    final avatarUrl = friend.photoUrl ?? 'https://api.dicebear.com/7.x/avataaars/png?seed=${friend.displayName}';

    return Scaffold(
      appBar: AppBar(title: Text(friend.displayName)),
      body: Column(
        children: [
          // Header card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: balance == 0
                  ? LinearGradient(colors: [AppColors.primary.withOpacity(0.3), AppColors.secondary])
                  : (isOwed ? AppColors.oweYouGradient : AppColors.youOweGradient),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  backgroundImage: NetworkImage(avatarUrl),
                ),
                const SizedBox(height: 12),
                Text(
                  friend.displayName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(friend.email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 16),
                Text(
                  balance == 0
                      ? 'All settled up 🎉'
                      : (isOwed
                          ? '${friend.displayName} owes you'
                          : 'You owe ${friend.displayName}'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '₹ ${balance.abs().toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Shared Expenses
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('SHARED EXPENSES',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          ),

          Expanded(
            child: sharedExpenses.isEmpty
                ? const Center(
                    child: Text('No shared expenses yet.',
                        style: TextStyle(color: AppColors.textSecondary)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sharedExpenses.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final Expense exp = sharedExpenses[index];
                      final bool iPaid = exp.paidByUserId == currentUserId;
                      final double myShare = exp.splits[currentUserId] ?? 0;
                      final double friendShare = exp.splits[friend.uid] ?? 0;

                      return ListTile(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseDetailScreen(expense: exp))),
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: const Icon(Icons.receipt, color: AppColors.primary, size: 18),
                        ),
                        title: Text(exp.description,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        subtitle: Text(
                          iPaid
                              ? 'You paid · ${friend.displayName} owes ₹${friendShare.toStringAsFixed(2)}'
                              : '${friend.displayName} paid · You owe ₹${myShare.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${exp.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14)),
                            Text(
                              '${exp.date.day}/${exp.date.month}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
