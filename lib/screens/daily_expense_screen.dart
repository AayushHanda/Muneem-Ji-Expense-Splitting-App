import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../models/expense.dart';
import '../models/daily_expenditure.dart';
import '../models/expense_category.dart';
import '../providers/expense_provider.dart';
import '../providers/daily_expenditure_provider.dart';
import '../services/user_service.dart';
import 'expense_detail_screen.dart';

class DailyExpenseScreen extends StatefulWidget {
  const DailyExpenseScreen({super.key});

  @override
  State<DailyExpenseScreen> createState() => _DailyExpenseScreenState();
}

class _DailyExpenseScreenState extends State<DailyExpenseScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final sharedProvider = Provider.of<ExpenseProvider>(context);
    final personalProvider = Provider.of<DailyExpenditureProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = sharedProvider.currentUserId;

    // 1. Filter Shared Expenses
    final dailySharedExpenses = sharedProvider.expenses.where((e) {
      final eDate = DateTime(e.date.year, e.date.month, e.date.day);
      final sDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      return eDate == sDate && (e.paidByUserId == currentUserId || e.splits.containsKey(currentUserId));
    }).toList();

    // 2. Filter Personal Expenditures
    final dailyPersonalExpenses = personalProvider.getFilteredExpenditures(
      filterType: 'Day', 
      selectedDate: _selectedDate
    );

    // 3. Calculate Totals
    final sharedTotal = sharedProvider.getDailySpending(_selectedDate);
    final personalTotal = personalProvider.calculateTotal(dailyPersonalExpenses);
    final dailyTotal = sharedTotal + personalTotal;

    // 4. Merge and Sort (using a common interface or dynamic list)
    final allDailyLog = [...dailySharedExpenses, ...dailyPersonalExpenses];
    allDailyLog.sort((a, b) {
      final aDate = (a is Expense) ? a.date : (a as DailyExpenditure).date;
      final bDate = (b is Expense) ? b.date : (b as DailyExpenditure).date;
      return bDate.compareTo(aDate);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateHeader(isDark),
          _buildSummaryCard(dailyTotal, isDark),
          Expanded(
            child: allDailyLog.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allDailyLog.length,
                    itemBuilder: (context, index) {
                      final item = allDailyLog[index];
                      if (item is Expense) {
                        return _buildExpenseTile(item, currentUserId!, isDark);
                      } else {
                        return _buildPersonalExpenditureTile(item as DailyExpenditure, currentUserId!, isDark);
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildPersonalExpenditureTile(DailyExpenditure exp, String currentUserId, bool isDark) {
    final cat = ExpenseCategory.predefined.firstWhere((c) => c.name == exp.category, orElse: () => ExpenseCategory.predefined.first);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? AppColors.cardDark : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: cat.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(cat.icon, color: cat.color),
        ),
        title: Text(exp.description, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            Text(DateFormat('hh:mm a').format(exp.date), style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            if (exp.createdBy == currentUserId)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF54C5F8).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text('Personal', style: TextStyle(fontSize: 9, color: Color(0xFF54C5F8), fontWeight: FontWeight.bold)),
              )
            else
              FutureBuilder<String>(
                future: UserService().getUser(exp.createdBy).then((u) => u?.displayName ?? 'Unknown'),
                builder: (context, snap) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.brand.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text('Shared by ${snap.data ?? "..."}', style: const TextStyle(fontSize: 9, color: AppColors.brand, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        trailing: Text(IndianFormatter.currency(exp.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.brand)),
      ),
    );
  }

  Widget _buildDateHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
          ),
          Column(
            children: [
              Text(
                DateFormat('EEEE, MMM dd').format(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day) == 
                  DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
                const Text('TODAY', style: TextStyle(color: AppColors.brand, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _selectedDate.isBefore(DateTime.now().subtract(const Duration(hours: 23))) || 
                      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
                ? () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double total, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brand, AppColors.brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.brand.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Your Total Spend', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          Text(IndianFormatter.currency(total), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(Expense expense, String currentUserId, bool isDark) {
    final cat = ExpenseCategory.predefined.firstWhere((c) => c.name == expense.category, orElse: () => ExpenseCategory.predefined.first);
    
    double myShare = 0;
    if (expense.paidByUserId == currentUserId) {
      double othersOwe = 0;
      expense.splits.forEach((uid, amt) {
        if (uid != currentUserId) othersOwe += amt;
      });
      myShare = expense.totalAmount - othersOwe;
    } else {
      myShare = expense.splits[currentUserId] ?? 0;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? AppColors.cardDark : Colors.white,
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseDetailScreen(expense: expense))),
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: cat.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(cat.icon, color: cat.color),
        ),
        title: Text(expense.description, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(DateFormat('hh:mm a').format(expense.date), style: const TextStyle(fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(IndianFormatter.currency(myShare), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.brand)),
            if (expense.splits.length > 1)
              const Text('Shared', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.brand.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('No expenses recorded for this day.', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
