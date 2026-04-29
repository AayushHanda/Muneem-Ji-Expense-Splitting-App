import 'package:flutter/material.dart';
import '../models/daily_expenditure.dart';
import '../services/daily_expenditure_service.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class DailyExpenditureProvider with ChangeNotifier {
  final DailyExpenditureService _service = DailyExpenditureService();
  final AuthService _authService = AuthService();

  List<DailyExpenditure> _allExpenditures = [];
  StreamSubscription? _subscription;
  double _budgetLimit = 0;
  bool _isBiometricEnabled = false;

  List<DailyExpenditure> get allExpenditures => _allExpenditures;
  double get budgetLimit => _budgetLimit;
  bool get isBiometricEnabled => _isBiometricEnabled;
  String? get currentUserId => _authService.currentUserId;

  DailyExpenditureProvider() {
    _initStream();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _budgetLimit = prefs.getDouble('daily_expenditure_budget') ?? 0;
    _isBiometricEnabled = prefs.getBool('daily_expenditure_biometric') ?? false;
    notifyListeners();
  }

  Future<void> setBudgetLimit(double limit) async {
    _budgetLimit = limit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('daily_expenditure_budget', limit);
    notifyListeners();
  }

  Future<void> toggleBiometric(bool value) async {
    _isBiometricEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_expenditure_biometric', value);
    notifyListeners();
  }

  void _initStream() {
    _authService.user.listen((user) {
      if (user != null) {
        _subscription = _service.getExpendituresStream(user.uid).listen((data) {
          _allExpenditures = data;
          notifyListeners();
        });
      } else {
        _allExpenditures = [];
        _subscription?.cancel();
        notifyListeners();
      }
    });
  }

  Future<void> addExpenditure(DailyExpenditure expenditure) async {
    await _service.addExpenditure(expenditure);
  }

  Future<void> updateExpenditure(DailyExpenditure expenditure) async {
    await _service.updateExpenditure(expenditure);
  }

  Future<void> deleteExpenditure(String id) async {
    await _service.deleteExpenditure(id);
  }

  Future<void> shareLog(String targetUserId) async {
    if (currentUserId == null) return;
    await _service.shareLog(currentUserId!, targetUserId);
  }

  // --- Filtering Logic ---

  List<DailyExpenditure> getFilteredExpenditures({
    required String filterType, // 'Day', 'Month', 'Year', 'Custom'
    DateTime? selectedDate,
    DateTimeRange? customRange,
  }) {
    if (selectedDate == null && filterType != 'Custom') return [];
    
    return _allExpenditures.where((exp) {
      if (filterType == 'Day') {
        return exp.date.year == selectedDate!.year &&
               exp.date.month == selectedDate.month &&
               exp.date.day == selectedDate.day;
      } else if (filterType == 'Month') {
        return exp.date.year == selectedDate!.year &&
               exp.date.month == selectedDate.month;
      } else if (filterType == 'Year') {
        return exp.date.year == selectedDate!.year;
      } else if (filterType == 'Custom') {
        if (customRange == null) return false;
        return exp.date.isAfter(customRange.start.subtract(const Duration(seconds: 1))) &&
               exp.date.isBefore(customRange.end.add(const Duration(days: 1)));
      }
      return false;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  double calculateTotal(List<DailyExpenditure> list) {
    return list.fold(0, (sum, item) => sum + item.amount);
  }

  // --- Smart Categorization (ML-Lite) ---
  
  String? getSuggestedCategory(String description) {
    if (description.length < 3) return null;
    
    final descLower = description.toLowerCase();
    final Map<String, int> categoryCounts = {};

    // Look for exact or fuzzy matches in history
    for (var exp in _allExpenditures) {
      if (exp.description.toLowerCase().contains(descLower) || 
          descLower.contains(exp.description.toLowerCase())) {
        categoryCounts[exp.category] = (categoryCounts[exp.category] ?? 0) + 1;
      }
    }

    if (categoryCounts.isEmpty) return null;

    // Return the most frequent category for this description
    return categoryCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
