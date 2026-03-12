import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../services/user_service.dart';
import '../providers/expense_provider.dart';
import '../models/app_user.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _emailController = TextEditingController();
  final UserService _userService = UserService();
  bool _isLoading = false;
  AppUser? _foundUser;
  String _errorMessage = '';
  
  // Default dicebear avatar logic
  String _getAvatarUrl(String name) {
    return 'https://api.dicebear.com/7.x/avataaars/png?seed=$name';
  }

  void _searchUser() async {
    if (_emailController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _foundUser = null;
    });

    try {
      final user = await _userService.searchUserByEmail(_emailController.text.trim());
      
      final currentUserId = Provider.of<ExpenseProvider>(context, listen: false).currentUserId;
      if (user != null && user.uid == currentUserId) {
         setState(() {
          _errorMessage = "You cannot add yourself as a friend.";
        });
      } else {
        setState(() {
          _foundUser = user;
          if (user == null) {
            _errorMessage = "No user found with that email address.";
          }
        });
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addFriend() async {
    if (_foundUser == null) return;
    final currentUserId = Provider.of<ExpenseProvider>(context, listen: false).currentUserId;
    if (currentUserId == null) return;
    setState(() => _isLoading = true);
    try {
      await _userService.addFriend(currentUserId, _foundUser!.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully added ${_foundUser!.displayName}!'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _inviteByEmail() async {
    final currentUserId = Provider.of<ExpenseProvider>(context, listen: false).currentUserId;
    if (currentUserId == null) return;
    setState(() => _isLoading = true);
    try {
      await _userService.storePendingInvite(currentUserId, _emailController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite sent! They\'ll be added when they join Muneem Ji.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a Friend')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search by Email',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask your friend for the email they used to sign up.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _emailController,
                    hint: 'friend@email.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.textDark, strokeWidth: 2))
                        : const Icon(Icons.search, color: AppColors.textDark),
                    onPressed: _isLoading ? null : _searchUser,
                  ),
                ),
              ],
            ),
            
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 24),
              if (_errorMessage.contains('No user found') && _emailController.text.trim().isNotEmpty)
                // ── Invite flow ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.brand.withOpacity(0.3)),
                  ),
                  child: Column(children: [
                    const Icon(Icons.mail_outline_rounded, color: AppColors.brand, size: 36),
                    const SizedBox(height: 10),
                    Text('${_emailController.text.trim()} is not on Muneem Ji yet.',
                        style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    const Text('Send them an invite! They\'ll be connected when they sign up.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _inviteByEmail,
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      label: const Text('Send Invite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )),
                  ]),
                )
              else
                Text(_errorMessage, style: const TextStyle(color: AppColors.error)),
            ],
            
            if (_foundUser != null) ...[
              const SizedBox(height: 32),
              const Text('Result', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.background,
                      backgroundImage: _foundUser!.photoUrl != null 
                        ? NetworkImage(_foundUser!.photoUrl!) 
                        : NetworkImage(_getAvatarUrl(_foundUser!.displayName)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _foundUser!.displayName, 
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)
                          ),
                          Text(_foundUser!.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addFriend,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
