import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/settlement.dart';
import '../models/activity.dart';
import '../models/comment.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/splitwise_algorithm.dart';
import '../services/user_service.dart';
import 'dart:async';

class ExpenseProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  
  List<Expense> _expenses = [];
  List<Settlement> _settlements = []; // New
  List<Activity> _activities = [];
  Map<String, double> _balances = {}; 
  Map<String, Map<String, double>> _simplifiedDebts = {}; 
  
  StreamSubscription? _expensesSub;
  StreamSubscription? _settlementsSub;
  StreamSubscription? _activitiesSub;

  List<Expense> get expenses => _expenses;
  List<Settlement> get settlements => _settlements;
  List<Activity> get activities => _activities;
  Map<String, double> get balances => _balances;
  Map<String, Map<String, double>> get simplifiedDebts => _simplifiedDebts;
  
  String? get currentUserId => _authService.currentUserId;

  ExpenseProvider() {
    _initStream();
  }

  void _initStream() {
    _authService.user.listen((user) {
      if (user != null) {
        _expensesSub = _firestoreService.getExpensesStream(user.uid).listen((expensesData) {
          _expenses = expensesData;
          _recalculateBalances();
        });
        
        _settlementsSub = _firestoreService.getSettlementsStream(user.uid).listen((settlementsData) {
          _settlements = settlementsData;
          _recalculateBalances();
        });

        _activitiesSub = _firestoreService.getActivitiesStream().listen((activitiesData) {
          _activities = activitiesData;
          notifyListeners();
        });
      } else {
        _expenses = [];
        _settlements = [];
        _activities = [];
        _expensesSub?.cancel();
        _settlementsSub?.cancel();
        _activitiesSub?.cancel();
        _recalculateBalances();
      }
    });
  }
  
  Future<void> logActivity(ActivityType type, String description, {String? expenseId, Map<String, dynamic>? metadata}) async {
    final user = await UserService().getUser(currentUserId!);
    if (user == null) return;
    
    final activity = Activity(
      id: '',
      type: type,
      userId: currentUserId!,
      userName: user.displayName,
      expenseId: expenseId,
      description: description,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    await _firestoreService.addActivity(activity);
  }

  Future<void> addExpense(Expense expense) async {
    // Save to Cloud Firestore
    await _firestoreService.addExpense(expense);
    logActivity(ActivityType.expenseAdded, 'added an expense: ${expense.description}', expenseId: expense.id);
    // Note: State updates automatically via the firestore stream listener above
  }

  Future<void> deleteExpense(String expenseId) async {
    final expense = _expenses.firstWhere((e) => e.id == expenseId);
    await _firestoreService.deleteExpense(expenseId);
    logActivity(ActivityType.expenseDeleted, 'removed an expense: ${expense.description}');
  }

  Future<void> updateExpense(Expense expense) async {
    await _firestoreService.updateExpense(expense);
    logActivity(ActivityType.expenseUpdated, 'updated the expense: ${expense.description}', expenseId: expense.id);
  }

  Future<void> addComment(String expenseId, String text) async {
    final user = await UserService().getUser(currentUserId!);
    if (user == null) return;

    final comment = Comment(
      id: '',
      userId: currentUserId!,
      userName: user.displayName,
      userPhotoUrl: user.photoUrl ?? '',
      text: text,
      timestamp: DateTime.now(),
    );

    await _firestoreService.addComment(expenseId, comment);
    logActivity(ActivityType.commentAdded, 'commented on "${_expenses.firstWhere((e) => e.id == expenseId).description}"', expenseId: expenseId);
  }

  void _recalculateBalances() {
    _balances.clear();
    
    // Add Debts from Expenses
    for (var expense in _expenses) {
      _balances[expense.paidByUserId] = (_balances[expense.paidByUserId] ?? 0) + expense.totalAmount;
      
      expense.splits.forEach((userId, amount) {
        _balances[userId] = (_balances[userId] ?? 0) - amount;
      });
    }
    
    // Deduct Settled amounts
    for (var settlement in _settlements) {
       // A repayment reduces the 'fromUser' balance negativity, and decreases 'toUser' positiveness.
       _balances[settlement.fromUserId] = (_balances[settlement.fromUserId] ?? 0) + settlement.amount;
       _balances[settlement.toUserId] = (_balances[settlement.toUserId] ?? 0) - settlement.amount;
    }

    _simplifiedDebts = SplitwiseAlgorithm.simplifyDebts(_balances);
    notifyListeners();
  }

  // --- Helpers for Dashboard ---
  double getTotalOwedToMe() {
    if (currentUserId == null) return 0.0;
    double total = 0;
    _simplifiedDebts.forEach((fromUser, toUsers) {
      if (toUsers.containsKey(currentUserId)) {
        total += toUsers[currentUserId]!;
      }
    });
    return total;
  }

  double getTotalIOwe() {
    if (currentUserId == null) return 0.0;
    double total = 0;
    if (_simplifiedDebts.containsKey(currentUserId)) {
      _simplifiedDebts[currentUserId]!.forEach((toUser, amount) {
        total += amount;
      });
    }
    return total;
  }

  /// Returns balance with a specific friend.
  /// Positive = that friend owes the current user.
  /// Negative = current user owes that friend.
  double getBalanceWithFriend(String friendId) {
    if (currentUserId == null) return 0.0;
    double balance = 0.0;

    // How much friend owes me (friend -> me in simplifiedDebts)
    _simplifiedDebts[friendId]?.forEach((toUser, amount) {
      if (toUser == currentUserId) balance += amount;
    });

    // How much I owe friend (me -> friend in simplifiedDebts)
    _simplifiedDebts[currentUserId]?.forEach((toUser, amount) {
      if (toUser == friendId) balance -= amount;
    });

    return balance;
  }
}
