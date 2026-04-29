import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/daily_expenditure.dart';
import '../models/expense_category.dart';
import '../providers/daily_expenditure_provider.dart';
import '../services/report_service.dart';

class ExpenditureAnalyticsScreen extends StatefulWidget {
  const ExpenditureAnalyticsScreen({super.key});

  @override
  State<ExpenditureAnalyticsScreen> createState() => _ExpenditureAnalyticsScreenState();
}

class _ExpenditureAnalyticsScreenState extends State<ExpenditureAnalyticsScreen> {
  DateTime _focusedDay = DateTime.now();
  
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DailyExpenditureProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final allLogs = provider.allExpenditures;
    final monthlyLogs = allLogs.where((e) => e.date.year == _focusedDay.year && e.date.month == _focusedDay.month).toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Export Report',
            onPressed: () => ReportService.generateExpenditurePdf(
              monthlyLogs, 
              DateFormat('MMMM yyyy').format(_focusedDay)
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMonthPicker(),
            const SizedBox(height: 24),
            _buildSectionHeader('Category Breakdown', Icons.pie_chart_rounded),
            const SizedBox(height: 16),
            _buildPieChart(monthlyLogs, isDark),
            const SizedBox(height: 32),
            _buildSectionHeader('Spending Heatmap', Icons.calendar_view_month_rounded),
            const SizedBox(height: 16),
            _buildHeatmap(monthlyLogs, isDark),
            const SizedBox(height: 32),
            _buildSectionHeader('Monthly Trend', Icons.show_chart_rounded),
            const SizedBox(height: 16),
            _buildLineChart(allLogs, isDark),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1)),
        ),
        Text(
          DateFormat('MMMM yyyy').format(_focusedDay),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE91E63)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1)),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFE91E63)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPieChart(List<DailyExpenditure> logs, bool isDark) {
    if (logs.isEmpty) return _buildEmptyState('No data for this month');
    
    final Map<String, double> categoryTotals = {};
    for (var log in logs) {
      categoryTotals[log.category] = (categoryTotals[log.category] ?? 0) + log.amount;
    }

    final total = categoryTotals.values.reduce((a, b) => a + b);

    return AspectRatio(
      aspectRatio: 1.3,
      child: PieChart(
        PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 40,
          sections: categoryTotals.entries.map((entry) {
            final cat = ExpenseCategory.predefined.firstWhere((c) => c.name == entry.key, orElse: () => ExpenseCategory.predefined.first);
            final percentage = (entry.value / total * 100).toStringAsFixed(1);
            return PieChartSectionData(
              color: cat.color,
              value: entry.value,
              title: '$percentage%',
              radius: 60,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              badgeWidget: _buildPieBadge(cat.icon, cat.color),
              badgePositionPercentageOffset: 1.1,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPieBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }

  Widget _buildHeatmap(List<DailyExpenditure> logs, bool isDark) {
    final Map<int, double> dailyTotals = {};
    for (var log in logs) {
      dailyTotals[log.date.day] = (dailyTotals[log.date.day] ?? 0) + log.amount;
    }

    // Determine color intensity based on max daily spend
    double maxSpend = dailyTotals.isEmpty ? 0 : dailyTotals.values.reduce((a, b) => a > b ? a : b);

    return TableCalendar(
      firstDay: DateTime(2000),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      headerVisible: false,
      calendarFormat: CalendarFormat.month,
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) => _buildHeatmapCell(day, dailyTotals[day.day] ?? 0, maxSpend, isDark),
        todayBuilder: (context, day, focusedDay) => _buildHeatmapCell(day, dailyTotals[day.day] ?? 0, maxSpend, isDark, isToday: true),
      ),
    );
  }

  Widget _buildHeatmapCell(DateTime day, double amount, double maxSpend, bool isDark, {bool isToday = false}) {
    Color? bgColor;
    if (amount > 0) {
      final intensity = (amount / maxSpend).clamp(0.1, 1.0);
      bgColor = const Color(0xFFE91E63).withOpacity(intensity);
    }
    
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor ?? (isDark ? Colors.white10 : Colors.black.withOpacity(0.03)),
        borderRadius: BorderRadius.circular(4),
        border: isToday ? Border.all(color: const Color(0xFFE91E63), width: 1.5) : null,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 12,
            color: amount > 0 ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
            fontWeight: amount > 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(List<DailyExpenditure> logs, bool isDark) {
    if (logs.isEmpty) return _buildEmptyState('No historical data');

    // Aggregate by month for the last 6 months
    final List<FlSpot> spots = [];
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      final total = logs.where((e) => e.date.year == month.year && e.date.month == month.month)
                        .fold(0.0, (sum, e) => sum + e.amount);
      spots.add(FlSpot((5 - i).toDouble(), total));
    }

    return AspectRatio(
      aspectRatio: 1.7,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final month = DateTime(now.year, now.month - (5 - value.toInt()).toInt());
                  return Text(DateFormat('MMM').format(month), style: const TextStyle(fontSize: 10));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFFE91E63),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFE91E63).withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(message, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }
}
