import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../models/app_user.dart';
import '../models/settlement.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import '../providers/expense_provider.dart';

class SettleUpSheet extends StatefulWidget {
  const SettleUpSheet({super.key});

  @override
  State<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends State<SettleUpSheet> {
  final TextEditingController _amountController = TextEditingController();
  final UserService _userService = UserService();
  final FirestoreService _firestoreService = FirestoreService();
  
  bool _isLoading = false;
  AppUser? _selectedFriend;
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showSheetError(String message) {
    setState(() => _errorMessage = message);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  void _submitSettlement() async {
    if (_selectedFriend == null) {
      _showSheetError('Please select a friend to pay');
      return;
    }
    
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSheetError('Enter a valid amount');
      return;
    }

    final currentUserId = Provider.of<ExpenseProvider>(context, listen: false).currentUserId;
    if (currentUserId == null) return;

    setState(() => _isLoading = true);

    try {
      final settlement = Settlement(
        fromUserId: currentUserId,
        toUserId: _selectedFriend!.uid,
        amount: amount,
      );

      await _firestoreService.addSettlement(settlement);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recorded a payment of ₹$amount to ${_selectedFriend!.displayName}'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final currentUserId = provider.currentUserId;
    
    final Map<String, double> myDebts = provider.simplifiedDebts[currentUserId] ?? {};

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('Settle Up', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Record a payment to a friend you owe.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 32),
          
          if (myDebts.isEmpty)
             Padding(
               padding: const EdgeInsets.symmetric(vertical: 40),
               child: Center(
                 child: Column(
                   children: [
                     const Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success),
                     const SizedBox(height: 16),
                     const Text('You are all settled up!', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 18)),
                   ],
                 ),
               ),
             )
          else ...[
            const Text('Who are you paying?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: myDebts.length,
                itemBuilder: (context, index) {
                  final debtEntry = myDebts.entries.elementAt(index);
                  final friendId = debtEntry.key;
                  final amountOwed = debtEntry.value;
                  final isSelected = _selectedFriend?.uid == friendId;
                  
                  return FutureBuilder<AppUser?>(
                    future: _userService.getUser(friendId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final friend = snapshot.data!;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFriend = friend;
                            _amountController.text = amountOwed.toStringAsFixed(2);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 110,
                          margin: const EdgeInsets.only(right: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.brand.withOpacity(0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected ? AppColors.brand : Colors.grey.withOpacity(0.2),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.brand.withOpacity(0.1),
                                backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
                                child: friend.photoUrl == null 
                                  ? Text(friend.displayName[0].toUpperCase(), style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold))
                                  : null,
                              ),
                              const SizedBox(height: 10),
                              Text(friend.displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                              Text('₹${amountOwed.toInt()}', style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    }
                  );
                },
              ),
            ),
            
            const SizedBox(height: 36),
            const Text('Amount to settle', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Text('₹', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.brand)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitSettlement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 4,
                  shadowColor: AppColors.brand.withOpacity(0.4),
                ),
                child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Confirm Settlement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
