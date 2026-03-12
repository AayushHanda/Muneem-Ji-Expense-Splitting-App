import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';
import '../providers/expense_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

class AddExpenseScreen extends StatefulWidget {
  final Expense? existingExpense;
  const AddExpenseScreen({super.key, this.existingExpense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _descController   = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController  = TextEditingController();
  final _userService      = UserService();
  final _picker           = ImagePicker();
  final _textRecognizer   = TextRecognizer(script: TextRecognitionScript.latin);

  ExpenseCategory _selectedCategory = ExpenseCategory.predefined.first;
  String   _selectedSplitType = 'equal'; // equal | exact | percent | shares
  final Map<String, TextEditingController> _customSplitControllers = {};

  List<AppUser> _allParticipants = [];
  AppUser?  _currentUserObj;
  AppUser?  _paidByUser;
  final Set<String> _splitMemberIds = {};
  DateTime  _selectedDate = DateTime.now();

  bool _isLoadingFriends = true;
  bool _hasInitialised   = false;
  bool _isSaving         = false;

  bool get _isEditMode => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    for (final c in _customSplitControllers.values) c.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    final provider      = Provider.of<ExpenseProvider>(context, listen: false);
    final currentUserId = provider.currentUserId;
    if (currentUserId == null) return;

    try {
      _currentUserObj = await _userService.getUser(currentUserId);
    } catch (_) {
      _currentUserObj = AppUser(uid: currentUserId, email: '', displayName: 'Me');
    }

    _userService.getFriendsStream(currentUserId).listen((friends) {
      if (!mounted) return;
      setState(() {
        _allParticipants  = [if (_currentUserObj != null) _currentUserObj!, ...friends];
        _isLoadingFriends = false;
        if (_paidByUser == null) _paidByUser = _currentUserObj;

        if (_isEditMode && !_hasInitialised) {
          _hasInitialised = true;
          final e = widget.existingExpense!;
          _descController.text   = e.description;
          _amountController.text = e.totalAmount.toString();
          _notesController.text  = e.notes ?? '';
          _selectedDate          = e.date;
          try { _selectedCategory = ExpenseCategory.predefined.firstWhere((c) => c.name == e.category); } catch (_) {}
          _paidByUser = _allParticipants.firstWhere(
            (u) => u.uid == e.paidByUserId,
            orElse: () => _currentUserObj!,
          );
          _splitMemberIds.addAll(e.splits.keys);
          if (e.splits.isNotEmpty) {
            final vals     = e.splits.values.toList();
            final allEqual = vals.every((v) => (v - vals.first).abs() < 0.01);
            _selectedSplitType = allEqual ? 'equal' : 'exact';
            if (!allEqual) e.splits.forEach((uid, amt) { _customSplitControllers[uid] = TextEditingController(text: amt.toStringAsFixed(2)); });
          }
        } else if (!_isEditMode && !_hasInitialised && _currentUserObj != null) {
          _hasInitialised = true;
          _splitMemberIds.add(currentUserId);
        }
      });
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context       : context,
      initialDate   : _selectedDate,
      firstDate     : DateTime(2000),
      lastDate      : DateTime.now().add(const Duration(days: 30)),
      builder       : (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brand),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
          const Padding(padding: EdgeInsets.only(bottom: 16),
              child: Text('Select Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 16),
            itemCount: ExpenseCategory.predefined.length,
            itemBuilder: (_, i) {
              final cat = ExpenseCategory.predefined[i];
              final sel = cat.name == _selectedCategory.name;
              return GestureDetector(
                onTap: () { setState(() => _selectedCategory = cat); Navigator.pop(context); },
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sel ? cat.color : cat.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: sel ? Border.all(color: cat.color, width: 2) : null,
                    ),
                    child: Icon(cat.icon, color: sel ? Colors.white : cat.color, size: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(cat.name, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                ]),
              );
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _scanReceipt() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (image == null) return;

      setState(() => _isSaving = true); // Repurpose isSaving for scanning indicator
      
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      double? foundAmount;
      String text = recognizedText.text.toLowerCase();
      
      // Basic heuristic: look for numbers after "total", "amount", etc.
      // Or just look for all numbers and take the largest one (often the total)
      final RegExp amountRegex = RegExp(r'(\d+[\.,]\d{2})');
      final Iterable<RegExpMatch> matches = amountRegex.allMatches(text);
      
      List<double> candidates = [];
      for (final match in matches) {
        final val = double.tryParse(match.group(1)!.replaceAll(',', '.'));
        if (val != null) candidates.add(val);
      }
      
      if (candidates.isNotEmpty) {
        // Find the largest amount which is likely the total
        candidates.sort((a, b) => b.compareTo(a));
        foundAmount = candidates.first;
      }

      if (foundAmount != null && mounted) {
        setState(() {
          _amountController.text = foundAmount!.toStringAsFixed(2);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estimated Total: ₹$foundAmount'), backgroundColor: AppColors.success)
        );
      } else {
        _showError('Could not reliably detect amount from receipt.');
      }
    } catch (e) {
      _showError('OCR Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
  );

  Future<void> _saveExpense() async {
    if (_descController.text.trim().isEmpty) { _showError('Please enter a description'); return; }
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) { _showError('Please enter a valid amount'); return; }
    if (_paidByUser == null) { _showError('Please select who paid'); return; }
    if (_splitMemberIds.isEmpty) { _showError('Select at least one person to split with'); return; }

    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final currentUserId = provider.currentUserId;
    if (currentUserId == null) return;

    final Map<String, double> splitMap = {};
    switch (_selectedSplitType) {
      case 'equal':
        final share = amount / _splitMemberIds.length;
        for (final uid in _splitMemberIds) splitMap[uid] = share;
        break;
      case 'exact':
        double tot = 0;
        for (final uid in _splitMemberIds) {
          final v = double.tryParse(_customSplitControllers[uid]?.text ?? '0') ?? 0;
          splitMap[uid] = v; tot += v;
        }
        if (tot > amount + 0.01) { _showError('Splits exceed total amount!'); return; }
        break;
      case 'percent':
        double totPct = 0;
        for (final uid in _splitMemberIds) {
          final pct = double.tryParse(_customSplitControllers[uid]?.text ?? '0') ?? 0;
          splitMap[uid] = (pct / 100) * amount; totPct += pct;
        }
        if (totPct > 100.01) { _showError('Percentages exceed 100%!'); return; }
        break;
      case 'shares':
        double totalShares = 0;
        for (final uid in _splitMemberIds) {
          totalShares += double.tryParse(_customSplitControllers[uid]?.text ?? '1') ?? 1;
        }
        for (final uid in _splitMemberIds) {
          final shares = double.tryParse(_customSplitControllers[uid]?.text ?? '1') ?? 1;
          splitMap[uid] = (shares / totalShares) * amount;
        }
        break;
    }

    setState(() => _isSaving = true);
    try {
      final expense = Expense(
        id           : _isEditMode ? widget.existingExpense!.id : null,
        description  : _descController.text.trim(),
        totalAmount  : amount,
        paidByUserId : _paidByUser!.uid,
        category     : _selectedCategory.name,
        splits       : splitMap,
        date         : _selectedDate,
        notes        : _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (_isEditMode) {
        await provider.updateExpense(expense);
      } else {
        await provider.addExpense(expense);
      }
      if (!mounted) return;
      Navigator.pop(context);
      if (_isEditMode) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final bg         = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final cardColor  = isDark ? AppColors.cardDark : Colors.white;
    final textColor  = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final subColor   = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final currentUID = Provider.of<ExpenseProvider>(context, listen: false).currentUserId;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(icon: Icon(Icons.close_rounded, color: textColor), onPressed: () => Navigator.pop(context)),
        title: Text(_isEditMode ? 'Edit Expense' : 'New Expense', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveExpense,
            child: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(color: AppColors.brand, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoadingFriends
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: EdgeInsets.zero, children: [
              // ─── Gradient Header ─────────────────────────────────
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.brandDeep, AppColors.brandDark, AppColors.brand],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(children: [
                  // Category pill + Date
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    GestureDetector(
                      onTap: _showCategoryPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_selectedCategory.icon, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(_selectedCategory.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 18),
                        ]),
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          Text(IndianFormatter.date(_selectedDate),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 20),
                  // Amount
                  Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                    const Text('₹', style: TextStyle(fontSize: 32, color: Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    IntrinsicWidth(child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 46, fontWeight: FontWeight.bold, color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: '0.00', hintStyle: TextStyle(color: Colors.white38, fontSize: 46, fontWeight: FontWeight.bold),
                        border: InputBorder.none, focusedBorder: InputBorder.none, enabledBorder: InputBorder.none, filled: false,
                      ),
                    )),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.document_scanner_rounded, color: Colors.white70, size: 28),
                      tooltip: 'Scan Receipt',
                      onPressed: _scanReceipt,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Description
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
                    child: TextField(
                      controller: _descController, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'What was this expense for?', hintStyle: TextStyle(color: Colors.white54, fontSize: 15),
                        border: InputBorder.none, focusedBorder: InputBorder.none, enabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), filled: false,
                      ),
                    ),
                  ),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ─── Paid By ────────────────────────────────────────
                  _Label(text: 'PAID BY', subColor: subColor),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: _allParticipants.map((user) {
                      final sel  = _paidByUser?.uid == user.uid;
                      final isMe = user.uid == currentUID;
                      return GestureDetector(
                        onTap: () => setState(() => _paidByUser = user),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: sel ? const LinearGradient(colors: [AppColors.brandDark, AppColors.brand]) : null,
                            color: sel ? null : cardColor,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: sel ? AppColors.brand : (isDark ? Colors.white12 : Colors.black12), width: sel ? 0 : 1),
                          ),
                          child: Row(children: [
                            CircleAvatar(radius: 13, backgroundColor: sel ? Colors.white30 : AppColors.brand.withOpacity(0.15),
                              child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.brand))),
                            const SizedBox(width: 8),
                            Text(isMe ? 'You' : user.displayName.split(' ').first,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : textColor)),
                          ]),
                        ),
                      );
                    }).toList()),
                  ),

                  const SizedBox(height: 28),

                  // ─── Split Between ──────────────────────────────────
                  _Label(text: 'SPLIT BETWEEN', subColor: subColor),
                  const SizedBox(height: 12),
                  _Card(isDark: isDark, cardColor: cardColor, child: Column(
                    children: _allParticipants.asMap().entries.map((entry) {
                      final i    = entry.key;
                      final user = entry.value;
                      final isMe = user.uid == currentUID;
                      final sel  = _splitMemberIds.contains(user.uid);
                      final isLast = i == _allParticipants.length - 1;
                      return Column(children: [
                        ListTile(
                          onTap: () => setState(() {
                            if (sel) {
                              _splitMemberIds.remove(user.uid);
                              _customSplitControllers[user.uid]?.dispose();
                              _customSplitControllers.remove(user.uid);
                            } else {
                              _splitMemberIds.add(user.uid);
                            }
                          }),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                          leading: CircleAvatar(radius: 18,
                            backgroundColor: sel ? AppColors.brand.withOpacity(0.15) : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                            child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: sel ? AppColors.brand : subColor))),
                          title: Text(isMe ? 'You' : user.displayName,
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                          trailing: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24, height: 24,
                            decoration: BoxDecoration(shape: BoxShape.circle,
                              gradient: sel ? const LinearGradient(colors: [AppColors.brandDark, AppColors.brand]) : null,
                              border: sel ? null : Border.all(color: subColor.withOpacity(0.4), width: 2)),
                            child: sel ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                          ),
                        ),
                        if (!isLast) Divider(indent: 68, height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                      ]);
                    }).toList(),
                  )),

                  const SizedBox(height: 28),

                  // ─── How to Split ──────────────────────────────────
                  if (_splitMemberIds.isNotEmpty) ...[
                    _Label(text: 'HOW TO SPLIT', subColor: subColor),
                    const SizedBox(height: 12),
                    Row(children: [
                      _SplitChip(label: 'Equal',   icon: Icons.balance_rounded,        sel: _selectedSplitType == 'equal',   onTap: () => setState(() => _selectedSplitType = 'equal'),   isDark: isDark, textColor: textColor),
                      const SizedBox(width: 8),
                      _SplitChip(label: 'Exact ₹', icon: Icons.currency_rupee_rounded, sel: _selectedSplitType == 'exact',   onTap: () => setState(() => _selectedSplitType = 'exact'),   isDark: isDark, textColor: textColor),
                      const SizedBox(width: 8),
                      _SplitChip(label: '%',        icon: Icons.percent_rounded,        sel: _selectedSplitType == 'percent', onTap: () => setState(() => _selectedSplitType = 'percent'), isDark: isDark, textColor: textColor),
                      const SizedBox(width: 8),
                      _SplitChip(label: 'Shares',  icon: Icons.pie_chart_rounded,      sel: _selectedSplitType == 'shares',  onTap: () => setState(() => _selectedSplitType = 'shares'),  isDark: isDark, textColor: textColor),
                    ]),
                  ],

                  // ─── Custom Split Inputs ───────────────────────────
                  if (_selectedSplitType != 'equal' && _splitMemberIds.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _Card(isDark: isDark, cardColor: cardColor, child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(children: _allParticipants.where((u) => _splitMemberIds.contains(u.uid)).toList().asMap().entries.map((e) {
                        final i    = e.key;
                        final user = e.value;
                        final isMe = user.uid == currentUID;
                        final isLast = i == _splitMemberIds.length - 1;
                        _customSplitControllers.putIfAbsent(user.uid, TextEditingController.new);
                        return Column(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(children: [
                              Expanded(child: Text(isMe ? 'You' : user.displayName,
                                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor))),
                              SizedBox(width: 110, child: TextField(
                                controller: _customSplitControllers[user.uid],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brand),
                                decoration: InputDecoration(
                                  hintText: _selectedSplitType == 'shares' ? '1' : (_selectedSplitType == 'exact' ? '0.00' : '0%'),
                                  hintStyle: TextStyle(color: subColor),
                                  filled: true, fillColor: AppColors.brand.withOpacity(0.08),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              )),
                            ]),
                          ),
                          if (!isLast) Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                        ]);
                      }).toList()),
                    )),
                  ],

                  const SizedBox(height: 28),

                  // ─── Notes ────────────────────────────────────────
                  _Label(text: 'NOTES (OPTIONAL)', subColor: subColor),
                  const SizedBox(height: 12),
                  _Card(isDark: isDark, cardColor: cardColor, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Add a note or remark about this expense...',
                        hintStyle: TextStyle(color: subColor),
                        border: InputBorder.none, filled: false,
                      ),
                    ),
                  )),

                  const SizedBox(height: 32),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveExpense,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      backgroundColor: AppColors.brand,
                      shadowColor: AppColors.brand.withOpacity(0.4),
                      elevation: 6,
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Text(_isEditMode ? 'Update Expense' : 'Save Expense',
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  )),
                ]),
              ),
            ]),
    );
  }
}

//────────────────────────────────────────────────────────────
// Helper Widgets
//────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text; final Color subColor;
  const _Label({required this.text, required this.subColor});
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.3));
}

class _Card extends StatelessWidget {
  final bool isDark; final Color cardColor; final Widget child;
  const _Card({required this.isDark, required this.cardColor, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: cardColor, borderRadius: BorderRadius.circular(18),
      border: isDark ? Border.all(color: Colors.white.withOpacity(0.06)) : null,
      boxShadow: isDark ? null : [BoxShadow(color: AppColors.brand.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: child,
  );
}

class _SplitChip extends StatelessWidget {
  final String label; final IconData icon; final bool sel; final bool isDark; final Color textColor; final VoidCallback onTap;
  const _SplitChip({required this.label, required this.icon, required this.sel, required this.isDark, required this.textColor, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: sel ? const LinearGradient(colors: [AppColors.brandDark, AppColors.brand]) : null,
        color: sel ? null : (isDark ? AppColors.cardDark : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sel ? AppColors.brand : (isDark ? Colors.white12 : Colors.black12), width: sel ? 0 : 1),
        boxShadow: sel ? [BoxShadow(color: AppColors.brand.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Column(children: [
        Icon(icon, size: 18, color: sel ? Colors.white : AppColors.brand),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sel ? Colors.white : textColor)),
      ]),
    ),
  ));
}
