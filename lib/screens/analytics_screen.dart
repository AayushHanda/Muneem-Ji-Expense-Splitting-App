import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/theme.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../providers/expense_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // Aggregate expenses by Category for the current user
  Map<String, double> _calculateCategoryTotals(List<Expense> expenses, String currentUserId) {
    final Map<String, double> totals = {};
    for (var expense in expenses) {
      if (expense.paidByUserId == currentUserId || expense.splits.containsKey(currentUserId)) {
        double myShare = 0;
        if (expense.paidByUserId == currentUserId) {
           // I paid for it, my share is total minus what others owe me
           double othersOwe = 0;
           expense.splits.forEach((key, value) {
             if (key != currentUserId) othersOwe += value;
           });
           myShare = expense.totalAmount - othersOwe;
        } else {
           // Someone else paid, my share is what I owe
           myShare = expense.splits[currentUserId] ?? 0;
        }
        
        totals[expense.category] = (totals[expense.category] ?? 0) + myShare;
      }
    }
    return totals;
  }
  
  Future<void> _exportToCsv(List<Expense> expenses, BuildContext context) async {
    try {
      if (expenses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No expenses to export')));
        return;
      }

      List<List<dynamic>> rows = [];
      // Header Row
      rows.add(["Date", "Description", "Category", "Amount", "Paid By UID", "Status"]);

      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      final currentUserId = provider.currentUserId;

      // Data Rows
      for (var expense in expenses) {
        String status = "Shared";
        if (expense.paidByUserId == currentUserId) {
          status = "You paid";
        } else if (expense.splits.containsKey(currentUserId)) {
          status = "You owe";
        }

        rows.add([
          DateFormat('yyyy-MM-dd HH:mm').format(expense.date),
          expense.description,
          expense.category,
          expense.totalAmount,
          expense.paidByUserId,
          status,
        ]);
      }

      String csvData = const CsvEncoder().convert(rows);

      final Directory directory = await getTemporaryDirectory();
      final String fileName = "muneem_ji_expenses_${DateTime.now().millisecondsSinceEpoch}.csv";
      final path = "${directory.path}/$fileName";
      final File file = File(path);
      
      await file.writeAsString(csvData);
      
      final xFile = XFile(path, mimeType: 'text/csv');
      await Share.shareXFiles([xFile], text: 'Muneem Ji Expense Export');

    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exporting CSV: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final currentUserId = provider.currentUserId;
    
    if (currentUserId == null) {
      return const Scaffold(body: Center(child: Text("Please log in", style: TextStyle(color: AppColors.textSecondary))));
    }

    final Map<String, double> categoryTotals = _calculateCategoryTotals(provider.expenses, currentUserId);
    
    // Sort categories by highest spend
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
      
    final totalSpend = sortedCategories.fold(0.0, (sum, item) => sum + item.value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: () => _exportToCsv(provider.expenses, context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Spent Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brandDeep, AppColors.brandDark, AppColors.brand],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text('TOTAL SPENT', 
                    style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('₹ ${totalSpend.toStringAsFixed(2)}', 
                    style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            if (sortedCategories.isEmpty)
               Center(
                 child: Padding(
                   padding: const EdgeInsets.all(48.0),
                   child: Column(
                     children: [
                       Icon(Icons.analytics_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                       const SizedBox(height: 16),
                       const Text("No expenses yet to analyze.", style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                     ],
                   ),
                 )
               )
            else ...[
              const Text('Spending by Category', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 24),
              
              // Pie Chart with modern container
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 65,
                      sections: sortedCategories.map((entry) {
                        final categoryDef = ExpenseCategory.predefined.firstWhere(
                          (c) => c.name == entry.key,
                          orElse: () => ExpenseCategory.predefined.first,
                        );
                        
                        final percentage = (entry.value / totalSpend) * 100;
                        
                        return PieChartSectionData(
                          color: categoryDef.color,
                          value: entry.value,
                          title: '${percentage.toStringAsFixed(0)}%',
                          radius: 55,
                          titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          badgeWidget: _Badge(categoryDef.icon, size: 34, borderColor: categoryDef.color),
                          badgePositionPercentageOffset: 1.1,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Breakdown List
              const Text('Category Breakdown', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              ...sortedCategories.map((entry) {
                 final categoryDef = ExpenseCategory.predefined.firstWhere(
                    (c) => c.name == entry.key,
                    orElse: () => ExpenseCategory.predefined.first,
                  );
                 return Container(
                   margin: const EdgeInsets.only(bottom: 16),
                   padding: const EdgeInsets.all(20),
                   decoration: BoxDecoration(
                     color: AppColors.surface,
                     borderRadius: BorderRadius.circular(20),
                     boxShadow: [
                       BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                     ],
                   ),
                   child: Row(
                     children: [
                       Container(
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(
                           color: categoryDef.color.withOpacity(0.12),
                           borderRadius: BorderRadius.circular(12),
                         ),
                         child: Icon(categoryDef.icon, color: categoryDef.color, size: 24),
                       ),
                       const SizedBox(width: 18),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(entry.key, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                             const SizedBox(height: 2),
                             Text('${((entry.value/totalSpend)*100).toStringAsFixed(1)}% of total', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                           ],
                         ),
                       ),
                       Text('₹ ${entry.value.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                     ],
                   ),
                 );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color borderColor;

  const _Badge(
    this.icon, {
    required this.size,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PieChart.defaultDuration,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(.5),
            offset: const Offset(3, 3),
            blurRadius: 3,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * .15),
      child: Center(
        child: Icon(icon, color: AppColors.textPrimary, size: size * .6),
      ),
    );
  }
}
