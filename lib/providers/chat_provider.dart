import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/ai_assistant_service.dart';
import '../services/user_service.dart';
import '../providers/expense_provider.dart';
import '../providers/daily_expenditure_provider.dart';
import 'package:provider/provider.dart';

class ChatProvider with ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  final AIAssistantService _aiService = AIAssistantService();
  final UserService _userService = UserService();

  // Cache: userId -> displayName
  final Map<String, String> _nameCache = {};

  List<ChatMessage> get messages => _messages;
  bool get isTyping => _isTyping;

  Future<String> _resolveUserName(String userId) async {
    if (_nameCache.containsKey(userId)) return _nameCache[userId]!;
    try {
      final user = await _userService.getUser(userId);
      final name = user?.displayName ?? userId;
      _nameCache[userId] = name;
      return name;
    } catch (_) {
      return userId;
    }
  }

  Future<void> sendMessage(String text, BuildContext context) async {
    if (text.trim().isEmpty) return;

    _messages.add(ChatMessage(text: text, role: MessageRole.user));
    _isTyping = true;
    notifyListeners();

    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      final dailyProvider = Provider.of<DailyExpenditureProvider>(context, listen: false);
      
      final String contextData = await _buildContextData(expenseProvider, dailyProvider);
      final response = await _aiService.generateResponse(text, contextData);
      
      _messages.add(ChatMessage(text: response, role: MessageRole.assistant));
    } catch (e) {
      _messages.add(ChatMessage(
        text: 'Sorry, I encountered an error: $e',
        role: MessageRole.assistant,
      ));
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  Future<String> _buildContextData(ExpenseProvider exP, DailyExpenditureProvider daP) async {
    // Resolve all user IDs to names
    final allUserIds = <String>{};

    for (var e in exP.expenses) {
      allUserIds.add(e.paidByUserId);
      allUserIds.addAll(e.splits.keys);
    }
    for (var entry in exP.simplifiedDebts.entries) {
      allUserIds.add(entry.key);
      allUserIds.addAll(entry.value.keys);
    }

    // Resolve all names in parallel
    await Future.wait(allUserIds.map((id) => _resolveUserName(id)));

    // Build shared expenses with names
    final sharedExpenses = exP.expenses.map((e) {
      final paidByName = _nameCache[e.paidByUserId] ?? e.paidByUserId;
      return '- ${e.description}: ₹${e.totalAmount} (Paid by: $paidByName, Date: ${e.date.toIso8601String()})';
    }).join('\n');

    // Build debts with names
    final debts = exP.simplifiedDebts.entries.map((entry) {
      final fromName = _nameCache[entry.key] ?? entry.key;
      return entry.value.entries.map((v) {
        final toName = _nameCache[v.key] ?? v.key;
        return '- $fromName owes $toName: ₹${v.value.toStringAsFixed(2)}';
      }).join('\n');
    }).join('\n');

    // Personal expenses 
    final personalExpenses = daP.allExpenditures.map((e) => 
      '- ${e.description}: ₹${e.amount} (Category: ${e.category}, Date: ${e.date.toIso8601String()})'
    ).join('\n');

    // Current user name
    final currentUserName = exP.currentUserId != null 
        ? (_nameCache[exP.currentUserId!] ?? 'Current User')
        : 'Current User';

    return """
USER FINANCIAL CONTEXT:
Current User: $currentUserName

1. Shared Expenses:
$sharedExpenses

2. Outstanding Balances/Debts:
$debts

3. Personal Daily Expenditures:
$personalExpenses
""";
  }

  void clearChat() {
    _messages.clear();
    notifyListeners();
  }
}
