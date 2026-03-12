import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../models/app_user.dart';
import '../models/expense_group.dart';
import '../services/user_service.dart';
import '../providers/expense_provider.dart';

class AddGroupScreen extends StatefulWidget {
  const AddGroupScreen({super.key});

  @override
  State<AddGroupScreen> createState() => _AddGroupScreenState();
}

class _AddGroupScreenState extends State<AddGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final UserService _userService = UserService();
  bool _isLoading = false;
  
  String _selectedType = 'Other';
  final List<String> _groupTypes = ['Trip', 'Home', 'Couple', 'Other'];
  
  final List<String> _selectedFriendIds = [];

  void _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a group name'), backgroundColor: AppColors.error));
      return;
    }

    final currentUserId = Provider.of<ExpenseProvider>(context, listen: false).currentUserId;
    if (currentUserId == null) return;

    setState(() => _isLoading = true);

    try {
      final List<String> allMembers = [currentUserId, ..._selectedFriendIds];
      
      final newGroup = ExpenseGroup(
        name: name,
        type: _selectedType,
        memberIds: allMembers,
        createdBy: currentUserId,
      );

      await _userService.createGroup(newGroup);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group "$name" created successfully!'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleFriend(String uid) {
    setState(() {
      if (_selectedFriendIds.contains(uid)) {
        _selectedFriendIds.remove(uid);
      } else {
        _selectedFriendIds.add(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<ExpenseProvider>(context).currentUserId;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Group')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Group Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _nameController,
              label: 'Group Name',
              hint: 'e.g. Goa Trip 2026',
              prefixIcon: Icons.group,
            ),
            const SizedBox(height: 24),
            const Text('Group Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _groupTypes.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedType = type);
                  },
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            const Text('Add Members', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Select friends to add to this group', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            
            if (currentUserId != null)
              StreamBuilder<List<AppUser>>(
                stream: _userService.getFriendsStream(currentUserId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final friends = snapshot.data ?? [];
                  
                  if (friends.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('No friends found. Add friends first!', style: TextStyle(color: AppColors.textSecondary))),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: friends.length,
                    separatorBuilder: (context, index) => const Divider(color: AppColors.surface, height: 1),
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final isSelected = _selectedFriendIds.contains(friend.uid);
                      return ListTile(
                        onTap: () => _toggleFriend(friend.uid),
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.background,
                          backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
                          child: friend.photoUrl == null ? Icon(Icons.person, color: isSelected ? AppColors.primary : AppColors.textSecondary) : null,
                        ),
                        title: Text(friend.displayName, style: const TextStyle(color: AppColors.textPrimary)),
                        trailing: Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                      );
                    },
                  );
                },
              ),
              
            const SizedBox(height: 48),
            CustomButton(
              text: _isLoading ? 'Creating...' : 'Create Group',
              onPressed: _isLoading ? () {} : _createGroup,
            ),
          ],
        ),
      ),
    );
  }
}
