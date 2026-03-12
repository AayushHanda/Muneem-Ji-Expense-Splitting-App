import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../models/expense_group.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import '../models/app_user.dart';
import '../models/settlement.dart';
import 'expense_detail_screen.dart';
import 'add_expense_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final ExpenseGroup group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserService _userService = UserService();
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, AppUser> _memberCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _preloadMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _preloadMembers() async {
    for (final uid in widget.group.memberIds) {
      final user = await _userService.getUser(uid);
      if (user != null && mounted) {
        setState(() => _memberCache[uid] = user);
      }
    }
  }

  String _name(String uid) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    if (uid == provider.currentUserId) return 'You';
    return _memberCache[uid]?.displayName ?? uid.substring(0, 6);
  }

  Future<void> _exportGroupCSV(List<Expense> expenses) async {
    try {
      final rows = [
        ['Date', 'Description', 'Category', 'Total', 'Paid By', 'Notes'],
        ...expenses.map((e) => [
          IndianFormatter.date(e.date),
          e.description,
          e.category,
          e.totalAmount.toStringAsFixed(2),
          _name(e.paidByUserId),
          e.notes ?? '',
        ]),
      ];
      final csvString = const CsvEncoder().convert(rows);
      final dir     = await getTemporaryDirectory();
      final String fileName = "${widget.group.name.replaceAll(' ', '_')}_expenses.csv";
      final file    = File('${dir.path}/$fileName');
      await file.writeAsString(csvString);
      
      final xFile = XFile(file.path, mimeType: 'text/csv');
      await Share.shareXFiles([xFile], text: '${widget.group.name} Expenses Export');

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showGroupSettleUp(String fromUid, String toUid, double amount) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool loading = false;
        return StatefulBuilder(builder: (ctx, setSt) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Icon(Icons.handshake_rounded, size: 48, color: AppColors.success),
            const SizedBox(height: 12),
            Text('${_name(fromUid)} pays ${_name(toUid)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(IndianFormatter.currency(amount),
                style: const TextStyle(color: AppColors.brand, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: loading ? null : () async {
                setSt(() => loading = true);
                try {
                  final settlement = Settlement(
                    fromUserId: fromUid,
                    toUserId  : toUid,
                    amount    : amount,
                    groupId   : widget.group.id,
                  );
                  await _firestoreService.addSettlement(settlement);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                }
                setSt(() => loading = false);
              },
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Text('Mark as Settled', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )),
          ]),
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider       = Provider.of<ExpenseProvider>(context);
    final isDark         = Theme.of(context).brightness == Brightness.dark;
    final currentUserId  = provider.currentUserId;
    final groupExpenses  = provider.expenses
        .where((e) => e.groupId == widget.group.id)
        .toList()..sort((a, b) => b.date.compareTo(a.date));

    // ── Group-level balance calculation ────────────────────
    final Map<String, double> groupBalances = {};
    for (final e in groupExpenses) {
      groupBalances[e.paidByUserId] = (groupBalances[e.paidByUserId] ?? 0) + e.totalAmount;
      e.splits.forEach((uid, amt) {
        groupBalances[uid] = (groupBalances[uid] ?? 0) - amt;
      });
    }

    // Simplified debts within the group only
    final List<_DebtRow> debts = [];
    for (final fromEntry in groupBalances.entries) {
      if (fromEntry.value < -0.01) {
        for (final toEntry in groupBalances.entries) {
          if (toEntry.value > 0.01) {
            final amt = fromEntry.value.abs() < toEntry.value ? fromEntry.value.abs() : toEntry.value;
            if (amt > 0.01) {
              debts.add(_DebtRow(from: fromEntry.key, to: toEntry.key, amount: amt));
            }
          }
        }
      }
    }

    final double totalSpend = groupExpenses.fold(0.0, (s, e) => s + e.totalAmount);
    final emoji = widget.group.iconEmoji;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: () => _exportGroupCSV(groupExpenses),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.brand,
          unselectedLabelColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          indicatorColor: AppColors.brand,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Balances'),
            Tab(text: 'Members'),
          ],
        ),
      ),
      body: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.brandDeep, AppColors.brandDark, AppColors.brand],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 4),
              Text('${widget.group.type} · ${widget.group.memberIds.length} members',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('TOTAL SPENT', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1)),
              Text(IndianFormatter.currency(totalSpend),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text('${groupExpenses.length} expense${groupExpenses.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ]),
        ),

        Expanded(child: TabBarView(controller: _tabController, children: [
          // ── TAB 1: Expenses ─────────────────────────────────────
          groupExpenses.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(emoji, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('No expenses yet!', style: TextStyle(color: AppColors.textSecondary)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: groupExpenses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final Expense exp = groupExpenses[index];
                    final bool iPaid = exp.paidByUserId == currentUserId;
                    return Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseDetailScreen(expense: exp))),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: AppColors.brand, size: 20),
                        ),
                        title: Text(exp.description,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${IndianFormatter.date(exp.date)} · ${exp.category}',
                            style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 12)),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(IndianFormatter.currency(exp.totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brand)),
                          Text(iPaid ? 'You paid' : 'Paid by ${_name(exp.paidByUserId)}',
                              style: TextStyle(fontSize: 11, color: iPaid ? AppColors.success : AppColors.textSecondary)),
                        ]),
                      ),
                    );
                  },
                ),

          // ── TAB 2: Balances (who owes whom) ────────────────────
          debts.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_rounded, size: 60, color: AppColors.success),
                  SizedBox(height: 12),
                  Text('All settled up! 🎉', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 6),
                  Text('No outstanding balances in this group.', style: TextStyle(color: AppColors.textSecondary)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: debts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final debt = debts[index];
                    final isMe = debt.from == currentUserId;
                    return Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          CircleAvatar(
                            backgroundColor: AppColors.error.withOpacity(0.12),
                            child: Text(_name(debt.from).substring(0, 1), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            RichText(text: TextSpan(
                              style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight, fontSize: 14),
                              children: [
                                TextSpan(text: _name(debt.from), style: const TextStyle(fontWeight: FontWeight.bold)),
                                const TextSpan(text: ' owes '),
                                TextSpan(text: _name(debt.to), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            )),
                            Text(IndianFormatter.currency(debt.amount),
                                style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold, fontSize: 16)),
                          ])),
                          if (isMe || debt.to == currentUserId)
                            OutlinedButton(
                              onPressed: () => _showGroupSettleUp(debt.from, debt.to, debt.amount),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.success,
                                side: const BorderSide(color: AppColors.success),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              child: const Text('Settle', style: TextStyle(fontSize: 12)),
                            ),
                        ]),
                      ),
                    );
                  },
                ),

          // ── TAB 3: Members ──────────────────────────────────────
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.group.memberIds.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final uid  = widget.group.memberIds[index];
              final user = _memberCache[uid];
              final memberBalance = groupBalances[uid] ?? 0;
              final isMe = uid == currentUserId;
              return Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.brand.withOpacity(0.15),
                    backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                    child: user?.photoUrl == null
                        ? Text((user?.displayName ?? uid)[0].toUpperCase(),
                            style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  title: Text(isMe ? 'You' : (user?.displayName ?? 'Loading...'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(user?.email ?? '', style: const TextStyle(fontSize: 12)),
                  trailing: memberBalance.abs() < 0.01
                      ? const Text('Settled', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(
                            memberBalance > 0 ? 'Gets back' : 'Owes',
                            style: TextStyle(fontSize: 11, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                          Text(IndianFormatter.currency(memberBalance.abs()),
                              style: TextStyle(fontWeight: FontWeight.bold, color: memberBalance > 0 ? AppColors.success : AppColors.error, fontSize: 13)),
                        ]),
                ),
              );
            },
          ),
        ])),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
        backgroundColor: AppColors.brand,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _DebtRow {
  final String from, to;
  final double amount;
  _DebtRow({required this.from, required this.to, required this.amount});
}
