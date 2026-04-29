import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../models/app_user.dart';
import '../models/expense_group.dart';
import '../models/activity.dart';
import '../services/user_service.dart';
import '../providers/expense_provider.dart';
import '../providers/daily_expenditure_provider.dart';
import 'package:intl/intl.dart';
import 'friend_detail_screen.dart';
import 'group_detail_screen.dart';
import 'settle_up_sheet.dart';

class DashboardScreen extends StatefulWidget {
  DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Image.asset('assets/images/app_logo.png', height: 40, width: 40),
        ),
        title: Text(
          'Muneem Ji',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.brand),
            onPressed: () => Navigator.pushNamed(context, '/chat'),
          ),
          IconButton(
            icon: Icon(Icons.bar_chart_rounded,
                color: isDark ? AppColors.textPrimaryDark : AppColors.brand),
            onPressed: () => Navigator.pushNamed(context, '/analytics'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.brand.withOpacity(0.2),
                child: const Icon(Icons.person, size: 18, color: AppColors.brand),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(context),
            const SizedBox(height: 20),
            _buildDailySummaryCard(context),
            const SizedBox(height: 20),

            // ── Search Bar ─────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? null : [BoxShadow(color: AppColors.brand.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
                border: isDark ? Border.all(color: Colors.white.withOpacity(0.07)) : null,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                decoration: InputDecoration(
                  hintText: 'Search expenses by name...',
                  hintStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.brand),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                      : null,
                  border: InputBorder.none, filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionButton(
                      context, 
                      'Expenditure', 
                      Icons.account_balance_wallet_rounded, 
                      const Color(0xFFE91E63), 
                      () => Navigator.pushNamed(context, '/expenditure_list')
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickActionButton(
                      context, 
                      'Activity', 
                      Icons.history_rounded, 
                      const Color(0xFF673AB7),
                      () => Navigator.pushNamed(context, '/activity')
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildSectionHeader(context, 'Groups', () => Navigator.pushNamed(context, '/add_group'), Icons.group_add_rounded),
              const SizedBox(height: 12),
              _buildGroupsList(context),
              const SizedBox(height: 28),
              _buildSectionHeader(context, 'Friends', () => Navigator.pushNamed(context, '/add_friend'), Icons.person_add_rounded),
              const SizedBox(height: 12),
              _buildFriendsList(context),
              const SizedBox(height: 28),
              _buildSectionHeader(context, 'Recent Activity', () => Navigator.pushNamed(context, '/activity'), Icons.history),
              const SizedBox(height: 12),
              _buildActivityPreview(context),
            ] else ...[
              const SizedBox(height: 20),
              Text('Search Results', style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              )),
              const SizedBox(height: 12),
              _buildActivityFeed(context, filter: _searchQuery),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add_expense'),
        backgroundColor: AppColors.brand,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 6,
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final provider      = Provider.of<ExpenseProvider>(context);
    final totalOwedToMe = provider.getTotalOwedToMe();
    final totalIOwe     = provider.getTotalIOwe();
    final netBalance    = totalOwedToMe - totalIOwe;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandDeep, AppColors.brandDark, AppColors.brand],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppColors.brand.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Stack(children: [
        Positioned(top: -20, right: -20,
            child: Container(width: 120, height: 120,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)))),
        Positioned(bottom: -30, left: 60,
            child: Container(width: 100, height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)))),

        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const Text('NET BALANCE',
                style: TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(IndianFormatter.currency(netBalance.abs()),
                style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
            Text(netBalance == 0 ? 'All settled up 🎉' : netBalance > 0 ? 'You are owed overall' : 'You owe overall',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 24),
            Container(height: 1, color: Colors.white24),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Column(children: [
                Text('You Owe', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 4),
                Text(IndianFormatter.currency(totalIOwe),
                    style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 18, fontWeight: FontWeight.bold)),
              ])),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(child: Column(children: [
                Text("You\u2019re Owed", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 4),
                Text(IndianFormatter.currency(totalOwedToMe),
                    style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 18, fontWeight: FontWeight.bold)),
              ])),
            ]),
            if (totalIOwe > 0.0) ...[
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: OutlinedButton(
                onPressed: () => _showSettleUpSheet(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Settle Up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              )),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildDailySummaryCard(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final dailyProv = Provider.of<DailyExpenditureProvider>(context);
    
    final sharedSpentToday = expenseProvider.getDailySpending(DateTime.now());
    final personalSpentToday = dailyProv.getFilteredExpenditures(
      filterType: 'Day', 
      selectedDate: DateTime.now()
    ).fold(0.0, (sum, item) => sum + item.amount);
    
    final totalSpentToday = sharedSpentToday + personalSpentToday;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? null : [BoxShadow(color: AppColors.brand.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.07)) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brand.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.today_rounded, color: AppColors.brand, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL SPENT TODAY', 
                  style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 4),
                Text(IndianFormatter.currency(totalSpentToday), 
                  style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/daily_log'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brand,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: AppColors.brand.withOpacity(0.08),
            ),
            child: const Text('View Log', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onAction, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)),
      IconButton(
        onPressed: onAction,
        icon: Icon(icon, color: AppColors.brand, size: 22),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.brand.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]);
  }

  void _showSettleUpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const SettleUpSheet(),
      ),
    );
  }

  Widget _buildGroupsList(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final userId   = provider.currentUserId;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<List<ExpenseGroup>>(
      stream: _userService.getUserGroupsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        if (snapshot.hasError) return Text('Could not load groups', style: TextStyle(color: AppColors.error));
        final groups = snapshot.data ?? [];
        if (groups.isEmpty) return _buildEmptyState('No groups yet. Tap + to create one!', Icons.group_rounded);

        return SizedBox(height: 130, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group))),
              child: Container(
                width: 140, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.brand.withOpacity(0.15)),
                  boxShadow: [BoxShadow(color: AppColors.brand.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.brand.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Text(group.iconEmoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(height: 10),
                  Text(group.name,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${group.memberIds.length} members', style: const TextStyle(fontSize: 11, color: AppColors.brand)),
                ]),
              ),
            );
          },
        ));
      },
    );
  }

  Widget _buildFriendsList(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final userId   = provider.currentUserId;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<List<AppUser>>(
      stream: _userService.getFriendsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        final friends = snapshot.data ?? [];
        if (friends.isEmpty) return _buildEmptyState('No friends yet. Tap + to add friends!', Icons.person_rounded);

        return ListView.separated(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemCount: friends.length,
          separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white10 : const Color(0xFFEBF5FB), height: 1),
          itemBuilder: (context, index) {
            final friend  = friends[index];
            final balance = provider.getBalanceWithFriend(friend.uid);
            String amountText  = 'Settled up ✓';
            Color  amountColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
            if (balance > 0.01) { amountText = 'Owes you ${IndianFormatter.currency(balance)}'; amountColor = AppColors.success; }
            else if (balance < -0.01) { amountText = 'You owe ${IndianFormatter.currency(balance.abs())}'; amountColor = AppColors.error; }

            return ListTile(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FriendDetailScreen(friend: friend))),
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.brand.withOpacity(0.15),
                child: Text(friend.displayName.isNotEmpty ? friend.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold)),
              ),
              title: Text(friend.displayName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)),
              subtitle: Text(amountText, style: TextStyle(color: amountColor, fontSize: 12)),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            );
          },
        );
      },
    );
  }

  Widget _buildActivityPreview(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        final activities = provider.activities.take(3).toList();
        if (activities.isEmpty) {
          return _buildEmptyState('No recent activity', Icons.history);
        }
        return Column(
          children: activities.map((activity) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.surfaceDark 
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                _getActivityIcon(activity.type), 
                color: _getActivityColor(activity.type), 
                size: 18
              ),
              title: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppColors.textPrimaryDark 
                        : AppColors.textPrimaryLight,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(text: activity.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: ' ${activity.description}'),
                  ],
                ),
              ),
              subtitle: Text(
                DateFormat('MMM dd, hh:mm a').format(activity.timestamp),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          )).toList(),
        );
      },
    );
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.expenseAdded: return Icons.add_circle_outline;
      case ActivityType.expenseUpdated: return Icons.edit_outlined;
      case ActivityType.expenseDeleted: return Icons.delete_outline;
      case ActivityType.settlementAdded: return Icons.handshake_outlined;
      case ActivityType.commentAdded: return Icons.comment_outlined;
    }
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.expenseAdded: return AppColors.brand;
      case ActivityType.expenseUpdated: return Colors.orange;
      case ActivityType.expenseDeleted: return AppColors.error;
      case ActivityType.settlementAdded: return AppColors.success;
      case ActivityType.commentAdded: return Colors.purple;
    }
  }

  Widget _buildActivityFeed(BuildContext context, {String? filter}) {
    final provider = Provider.of<ExpenseProvider>(context);
    final userId   = provider.currentUserId;
    if (userId == null) return const SizedBox.shrink();

    final filteredActivities = provider.activities.where((a) {
      if (filter == null || filter.isEmpty) return true;
      final query = filter.toLowerCase();
      return a.description.toLowerCase().contains(query) || 
             a.userName.toLowerCase().contains(query);
    }).toList();

    if (filteredActivities.isEmpty) {
      return _buildEmptyState('No activities matched your search', Icons.search_off_rounded);
    }

    return Column(
      children: filteredActivities.map((activity) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppColors.surfaceDark 
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ListTile(
          onTap: activity.expenseId != null 
              ? () => Navigator.pushNamed(context, '/expense_detail', arguments: activity.expenseId)
              : null,
          leading: CircleAvatar(
            backgroundColor: _getActivityColor(activity.type).withOpacity(0.12),
            child: Icon(_getActivityIcon(activity.type), color: _getActivityColor(activity.type), size: 20),
          ),
          title: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppColors.textPrimaryDark 
                    : AppColors.textPrimaryLight,
                fontSize: 14,
              ),
              children: [
                TextSpan(text: activity.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: ' ${activity.description}'),
              ],
            ),
          ),
          subtitle: Text(
            DateFormat('MMM dd, hh:mm a').format(activity.timestamp),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
        ),
      )).toList(),
    );
  }

  Widget _buildQuickActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.brand.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brand.withOpacity(0.1)),
      ),
      child: Column(children: [
        Icon(icon, color: AppColors.brand.withOpacity(0.4), size: 36),
        const SizedBox(height: 10),
        Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
      ]),
    );
  }
}
