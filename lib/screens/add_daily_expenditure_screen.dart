import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../models/daily_expenditure.dart';
import '../models/expense_category.dart';
import '../providers/daily_expenditure_provider.dart';

class AddDailyExpenditureScreen extends StatefulWidget {
  const AddDailyExpenditureScreen({super.key});

  @override
  State<AddDailyExpenditureScreen> createState() => _AddDailyExpenditureScreenState();
}

class _AddDailyExpenditureScreenState extends State<AddDailyExpenditureScreen> {
  final _descController   = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController  = TextEditingController();
  
  ExpenseCategory _selectedCategory = ExpenseCategory.predefined.first;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  bool _hasManuallySelectedCategory = false;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _descController.addListener(_onDescriptionChanged);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            final text = val.recognizedWords;
            _descController.text = text;
            _parseSpeech(text);
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _parseSpeech(String text) {
    // Basic regex: try to find a number
    final amountMatch = RegExp(r'(\d+)').firstMatch(text);
    if (amountMatch != null) {
      _amountController.text = amountMatch.group(1)!;
    }
    
    // Check if description has "for X" or "on X"
    final descMatch = RegExp(r'(?:for|on)\s+(.*)', caseSensitive: false).firstMatch(text);
    if (descMatch != null) {
      _descController.text = descMatch.group(1)!.trim();
    }
  }

  void _onDescriptionChanged() {
    if (_hasManuallySelectedCategory) return;
    
    final provider = Provider.of<DailyExpenditureProvider>(context, listen: false);
    final suggestion = provider.getSuggestedCategory(_descController.text.trim());
    
    if (suggestion != null) {
      final category = ExpenseCategory.predefined.firstWhere(
        (c) => c.name == suggestion,
        orElse: () => _selectedCategory,
      );
      if (category != _selectedCategory) {
        setState(() => _selectedCategory = category);
      }
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final desc = _descController.text.trim();
    final amount = double.tryParse(_amountController.text);

    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a description')));
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
      return;
    }

    setState(() => _isSaving = true);
    final provider = Provider.of<DailyExpenditureProvider>(context, listen: false);
    final userId = provider.currentUserId;

    if (userId == null) return;

    final expenditure = DailyExpenditure(
      description: desc,
      amount: amount,
      category: _selectedCategory.name,
      createdBy: userId,
      date: _selectedDate,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    try {
      await provider.addExpenditure(expenditure);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Add Daily Spend', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isListening ? Icons.mic_rounded : Icons.mic_none_rounded, color: Colors.white),
            onPressed: _listen,
          ),
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Amount Heading Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 56, 24, 40),
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const Text('AMOUNT SPENT', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      hintText: '₹ 0.00',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 48),
                      filled: false,
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildInputCard(
                    child: Column(
                      children: [
                        _buildInputField(
                          icon: Icons.description_rounded,
                          label: 'What did you buy?',
                          controller: _descController,
                        ),
                        const Divider(height: 1),
                        _buildPickerField(
                          icon: _selectedCategory.icon,
                          label: 'Category',
                          value: _selectedCategory.name,
                          onTap: _showCategoryPicker,
                        ),
                        const Divider(height: 1),
                        _buildPickerField(
                          icon: Icons.today_rounded,
                          label: 'Date',
                          value: IndianFormatter.date(_selectedDate),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) setState(() => _selectedDate = picked);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInputCard(
                    child: _buildInputField(
                      icon: Icons.note_rounded,
                      label: 'Add some notes (Optional)',
                      controller: _notesController,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 4,
                        shadowColor: AppColors.brand.withOpacity(0.4),
                      ),
                      child: _isSaving 
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('RECORD EXPENDITURE', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
      ),
      child: child,
    );
  }

  Widget _buildInputField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.brand),
      title: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: label,
          border: InputBorder.none,
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildPickerField({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.brand),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: GridView.builder(
          shrinkWrap: true,
          itemCount: ExpenseCategory.predefined.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 16, crossAxisSpacing: 16),
          itemBuilder: (ctx, i) {
            final cat = ExpenseCategory.predefined[i];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = cat;
                  _hasManuallySelectedCategory = true;
                });
                Navigator.pop(context);
              },
              child: Column(
                children: [
                  CircleAvatar(backgroundColor: cat.color.withOpacity(0.12), child: Icon(cat.icon, color: cat.color)),
                  const SizedBox(height: 4),
                  Text(cat.name, style: const TextStyle(fontSize: 10)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
