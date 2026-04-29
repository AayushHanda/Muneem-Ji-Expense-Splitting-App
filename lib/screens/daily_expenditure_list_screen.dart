import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../models/daily_expenditure.dart';
import '../models/expense_category.dart';
import '../providers/daily_expenditure_provider.dart';
import '../services/user_service.dart';
import 'package:local_auth/local_auth.dart';

class DailyExpenditureListScreen extends StatefulWidget {
  const DailyExpenditureListScreen({super.key});

  @override
  State<DailyExpenditureListScreen> createState() => _DailyExpenditureListScreenState();
}

class _DailyExpenditureListScreenState extends State<DailyExpenditureListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _customRange;
  final List<String> _filters = ['Day', 'Month', 'Year', 'Custom'];
  
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    
    // Check biometrics after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometrics();
    });
  }

  Future<void> _checkBiometrics() async {
    final provider = Provider.of<DailyExpenditureProvider>(context, listen: false);
    if (provider.isBiometricEnabled) {
      try {
        final authenticated = await _auth.authenticate(
          localizedReason: 'Please authenticate to view your expenditures',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
        );
        if (!authenticated) {
          if (mounted) Navigator.pop(context);
        } else {
          setState(() => _isAuthenticated = true);
        }
      } catch (e) {
        print('Biometric error: $e');
        setState(() => _isAuthenticated = true); // Fallback to allowed if error (usually simulator or no sensor)
      }
    } else {
      setState(() => _isAuthenticated = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentFilter => _filters[_tabController.index];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DailyExpenditureProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredList = provider.getFilteredExpenditures(
      filterType: _currentFilter,
      selectedDate: _selectedDate,
      customRange: _customRange,
    );

    final total = provider.calculateTotal(filteredList);

    if (!_isAuthenticated && provider.isBiometricEnabled) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Expenditure'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_rounded),
            tooltip: 'Analytics',
            onPressed: () => Navigator.pushNamed(context, '/expenditure_analytics'),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Log',
            onPressed: () => _showShareDialog(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => _showSettingsDialog(context, provider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _filters.map((f) => Tab(text: f)).toList(),
          indicatorColor: AppColors.brand,
          labelColor: AppColors.brand,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
      body: Column(
        children: [
          _buildFilterSelector(isDark),
          _buildSummaryCard(total, provider.budgetLimit, isDark, provider),
          Expanded(
            child: filteredList.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final exp = filteredList[index];
                      return _buildExpenditureTile(exp, isDark, provider);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add_expenditure'),
        backgroundColor: AppColors.brand,
        label: const Text('Add Spend', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterSelector(bool isDark) {
    if (_currentFilter == 'Custom') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              initialDateRange: _customRange,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _customRange = picked);
          },
          icon: const Icon(Icons.date_range_rounded),
          label: Text(_customRange == null 
              ? 'Select Range' 
              : '${DateFormat('MMM dd').format(_customRange!.start)} - ${DateFormat('MMM dd').format(_customRange!.end)}'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => _navigateDate(-1),
          ),
          GestureDetector(
            onTap: _pickDate,
            child: Column(
              children: [
                Text(
                  _getDateDisplayText(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => _navigateDate(1),
          ),
        ],
      ),
    );
  }

  void _navigateDate(int delta) {
    setState(() {
      if (_currentFilter == 'Day') {
        _selectedDate = _selectedDate.add(Duration(days: delta));
      } else if (_currentFilter == 'Month') {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta);
      } else if (_currentFilter == 'Year') {
        _selectedDate = DateTime(_selectedDate.year + delta);
      }
    });
  }

  String _getDateDisplayText() {
    if (_currentFilter == 'Day') return DateFormat('EEE, MMM dd, yyyy').format(_selectedDate);
    if (_currentFilter == 'Month') return DateFormat('MMMM yyyy').format(_selectedDate);
    if (_currentFilter == 'Year') return DateFormat('yyyy').format(_selectedDate);
    return '';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Widget _buildSummaryCard(double total, double budget, bool isDark, DailyExpenditureProvider provider) {
    final progress = budget > 0 ? (total / budget).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = budget > 0 && total > budget;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE91E63),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFFE91E63).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PERIOD TOTAL', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    SizedBox(height: 4),
                    Text('Total Expenditure', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(IndianFormatter.currency(total), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  if (budget > 0)
                    Text('of ${IndianFormatter.currency(budget)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, color: Colors.white70, size: 20),
                onPressed: () => _showSetBudgetDialog(context, provider),
              ),
            ],
          ),
          if (budget > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(isOverBudget ? Colors.yellow : Colors.white),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOverBudget ? 'Over budget!' : '${(progress * 100).toInt()}% of budget used',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                Text(
                  budget - total > 0 ? '${IndianFormatter.currency(budget - total)} left' : '${IndianFormatter.currency(total - budget)} over',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showSetBudgetDialog(BuildContext context, DailyExpenditureProvider provider) {
    final controller = TextEditingController(text: provider.budgetLimit > 0 ? provider.budgetLimit.toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? 0;
              provider.setBudgetLimit(val);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenditureTile(DailyExpenditure exp, bool isDark, DailyExpenditureProvider provider) {
    final cat = ExpenseCategory.predefined.firstWhere((c) => c.name == exp.category, orElse: () => ExpenseCategory.predefined.first);
    return Dismissible(
      key: Key(exp.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => provider.deleteExpenditure(exp.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        color: isDark ? AppColors.cardDark : Colors.white,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: cat.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(cat.icon, color: cat.color),
          ),
          title: Text(exp.description, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Row(
            children: [
              Text(DateFormat('MMM dd, hh:mm a').format(exp.date), style: const TextStyle(fontSize: 12)),
              if (exp.createdBy != provider.currentUserId) ...[
                const SizedBox(width: 8),
                FutureBuilder<String>(
                  future: UserService().getUser(exp.createdBy).then((u) => u?.displayName ?? 'Unknown'),
                  builder: (context, snap) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.brand.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text('By ${snap.data ?? "..."}', style: const TextStyle(fontSize: 9, color: AppColors.brand, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
          trailing: Text(IndianFormatter.currency(exp.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.brand)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_rounded, size: 64, color: AppColors.brand.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('No expenditures recorded for this period.', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, DailyExpenditureProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Expenditure Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Biometric Lock'),
                subtitle: const Text('Require fingerprint/face to open'),
                value: provider.isBiometricEnabled,
                activeTrackColor: const Color(0xFFE91E63),
                onChanged: (val) async {
                  await provider.toggleBiometric(val);
                  setDialogState(() {});
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Monthly Budget'),
                subtitle: Text(provider.budgetLimit > 0 ? IndianFormatter.currency(provider.budgetLimit) : 'Not set'),
                trailing: const Icon(Icons.edit_rounded, size: 18),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSetBudgetDialog(context, provider);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  void _showShareDialog(BuildContext context, DailyExpenditureProvider provider) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share Expenditure Log'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this log with another person so they can view and add expenditures.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(hintText: 'Enter email address', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              
              final user = await UserService().searchUserByEmail(email);
              if (!context.mounted) return;
              
              if (user != null) {
                if (user.uid == provider.currentUserId) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You cannot share with yourself')));
                  return;
                }
                await provider.shareLog(user.uid);
                if (!context.mounted) return;
                
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully shared with ${user.displayName}'), backgroundColor: AppColors.success));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
              }
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }
}
