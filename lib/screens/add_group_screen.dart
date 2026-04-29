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
      appBar: AppBar(
        title: const Text('Create Group'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Group Details'),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _nameController,
              hint: 'e.g. Goa Trip 2026',
              prefixIcon: Icons.group_work_rounded,
            ),
            const SizedBox(height: 24),
            Text('Group Type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.textPrimary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _groupTypes.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedType = type);
                  },
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  selectedColor: AppColors.brand,
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.cardDark : Colors.grey.withOpacity(0.1),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('Add Members'),
            const Text('Select friends to add to this group', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            
            if (currentUserId != null)
              StreamBuilder<List<AppUser>>(
                stream: _userService.getFriendsStream(currentUserId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  
                  final friends = snapshot.data ?? [];
                  
                  if (friends.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.brand.withOpacity(0.1)),
                      ),
                      child: const Center(child: Text('No friends found. Add friends first!', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: friends.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final isSelected = _selectedFriendIds.contains(friend.uid);
                      return ListTile(
                        onTap: () => _toggleFriend(friend.uid),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.brand.withOpacity(0.12),
                          backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
                          child: friend.photoUrl == null ? Text(friend.displayName[0].toUpperCase(), style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold)) : null,
                        ),
                        title: Text(friend.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        trailing: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                          color: isSelected ? AppColors.brand : Colors.grey.withOpacity(0.5),
                          size: 26,
                        ),
                      );
                    },
                  );
                },
              ),
              
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: _isLoading ? 'Creating...' : 'Create Group',
                onPressed: _isLoading ? () {} : _createGroup,
              ),
            ),
            const SizedBox(height: 32), // Add bottom padding for better scroll experience
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18, 
        fontWeight: FontWeight.bold, 
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textPrimary,
        letterSpacing: 0.5,
      ),
    );
  }
}
