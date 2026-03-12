import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import '../models/app_user.dart';
import '../models/comment.dart';
import '../utils/formatters.dart';
import 'package:intl/intl.dart';
import 'add_expense_screen.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final _commentController = TextEditingController();
  final _firestoreService = FirestoreService();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    await provider.addComment(widget.expense.id, text);
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final userService = UserService();
    final currentUserId = provider.currentUserId;
    final bool iPaid = widget.expense.paidByUserId == currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddExpenseScreen(existingExpense: widget.expense),
                ),
              );
            },
            tooltip: 'Edit Expense',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.error),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Expense'),
                  content: const Text('Are you sure you want to permanently delete this expense?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                try {
                  await provider.deleteExpense(widget.expense.id);
                  if (context.mounted) {
                    Navigator.pop(context); // Go back to dashboard after deleting
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense deleted'), backgroundColor: AppColors.success));
                  }
                } catch (e) {
                  if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                  }
                }
              }
            },
            tooltip: 'Delete Expense',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.surface,
              child: Icon(Icons.receipt_long, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              widget.expense.description,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '₹ ${widget.expense.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'Added on ${widget.expense.date.day}/${widget.expense.date.month}/${widget.expense.date.year}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 32),
            
            // Payment Summary Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PAID BY', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  FutureBuilder<AppUser?>(
                    future: userService.getUser(widget.expense.paidByUserId),
                    builder: (context, snapshot) {
                      String payerName = 'Loading...';
                      if (snapshot.hasData) {
                        payerName = iPaid ? 'You' : snapshot.data!.displayName;
                      }
                      return Text(
                        '$payerName paid ₹ ${widget.expense.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Split Details Section
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('SPLIT DETAILS', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.expense.splits.length,
                separatorBuilder: (context, index) => const Divider(color: AppColors.background, height: 1),
                itemBuilder: (context, index) {
                  String uid = widget.expense.splits.keys.elementAt(index);
                  double amountOwed = widget.expense.splits[uid]!;
                  final bool isMe = uid == currentUserId;

                  return FutureBuilder<AppUser?>(
                    future: userService.getUser(uid),
                    builder: (context, snapshot) {
                      String displayName = isMe ? 'You' : 'Loading...';
                      String? avatarUrl;
                      
                      if (snapshot.hasData) {
                        displayName = isMe ? 'You' : snapshot.data!.displayName;
                        avatarUrl = snapshot.data!.photoUrl;
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.background,
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null ? Icon(Icons.person, color: isMe ? AppColors.primary : AppColors.textSecondary) : null,
                        ),
                        title: Text(displayName, style: TextStyle(color: AppColors.textPrimary, fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
                        trailing: Text(
                          '₹ ${amountOwed.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _buildCommentsSection(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection(BuildContext context, bool isDark) {
    final bgColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('COMMENTS', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              StreamBuilder<List<Comment>>(
                stream: _firestoreService.getCommentsStream(widget.expense.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ));
                  }
                  final comments = snapshot.data ?? [];
                  if (comments.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No comments yet.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.brand.withOpacity(0.1),
                            backgroundImage: comment.userPhotoUrl.isNotEmpty ? NetworkImage(comment.userPhotoUrl) : null,
                            child: comment.userPhotoUrl.isEmpty ? Text(comment.userName[0].toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.brand)) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(comment.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(DateFormat('MMM dd, hh:mm a').format(comment.timestamp), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(comment.text, style: TextStyle(fontSize: 13, color: textColor)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: const TextStyle(fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.brand),
                    onPressed: _addComment,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
