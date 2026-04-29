import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../providers/expense_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService   _authService  = AuthService();
  final UserService   _userService  = UserService();
  final ImagePicker   _picker       = ImagePicker();
  bool  _uploadingPhoto = false;

  Future<void> _pickAndUploadPhoto(String userId) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _uploadingPhoto = true);

      final bytes = await image.readAsBytes();
      final ref = FirebaseStorage.instance.ref().child('profile_photos/$userId.jpg');
      debugPrint('Uploading ${bytes.length} bytes for user $userId to profile_photos/$userId.jpg');
      
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      debugPrint('Upload completed with status: ${snapshot.state}');
      
      // Add a slightly longer delay if the error persists
      await Future.delayed(const Duration(seconds: 1));
      
      final url = await snapshot.ref.getDownloadURL();
      debugPrint('Download URL fetched: $url');

      await _userService.updateUserPhoto(userId, url);

      if (mounted) {
        setState(() => _uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile photo updated!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'), backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async { 
              Navigator.pop(ctx); 
              await _authService.signOut(); 
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Log Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider       = Provider.of<ExpenseProvider>(context);
    final themeProvider  = Provider.of<ThemeProvider>(context);
    final currentUserId  = provider.currentUserId;
    final isDark         = themeProvider.isDark;
    final bgColor        = isDark ? AppColors.backgroundDark  : AppColors.backgroundLight;
    final cardColor      = isDark ? AppColors.cardDark        : Colors.white;
    final textColor      = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final subColor       = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text('My Profile', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(icon: const Icon(Icons.logout_rounded, color: AppColors.error), onPressed: () => _confirmLogout(context)),
          const SizedBox(width: 8),
        ],
      ),
      body: currentUserId == null
          ? const Center(child: Text('Not logged in'))
          : FutureBuilder<AppUser?>(
              future: _userService.getUser(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final user = snapshot.data;
                if (user == null) return const Center(child: Text('Failed to load profile'));

                final totalOwedToMe = provider.getTotalOwedToMe();
                final totalIOwe     = provider.getTotalIOwe();
                final netBalance    = totalOwedToMe - totalIOwe;

                return SingleChildScrollView(
                  child: Column(children: [
                    // ─── Hero Header ──────────────────────────────────
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.brandDeep, AppColors.brandDark, AppColors.brand],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36),
                        ),
                      ),
                      child: Stack(children: [
                        Positioned(top: -24, right: -24,
                          child: Opacity(opacity: 0.08, child: Container(width: 140, height: 140,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)))),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                            // ── Avatar with tap to change ──────────────
                            GestureDetector(
                              onTap: () => _pickAndUploadPhoto(currentUserId),
                              child: Stack(children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white30, width: 2)),
                                  child: CircleAvatar(
                                    radius: 46,
                                    backgroundColor: Colors.white.withOpacity(0.15),
                                    backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                                    child: user.photoUrl == null
                                        ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                                            style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold))
                                        : null,
                                  ),
                                ),
                                if (_uploadingPhoto)
                                  const Positioned.fill(child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
                                Positioned(right: 0, bottom: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.brand, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded, size: 14, color: AppColors.brand),
                                  )),
                              ]),
                            ),
                            const SizedBox(height: 16),
                            Text(user.displayName,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(user.email, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                            const SizedBox(height: 24),

                            // Net Balance Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Column(children: [
                                const Text('NET BALANCE', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(IndianFormatter.currency(netBalance.abs()),
                                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                                Text(netBalance == 0 ? 'All settled up 🎉' : netBalance > 0 ? 'People owe you' : 'You owe others',
                                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ),

                    // ─── Stat Cards ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Row(children: [
                        _StatCard(isDark: isDark, cardColor: cardColor, title: 'You Are Owed',
                            value: IndianFormatter.currency(totalOwedToMe), valueColor: AppColors.success,
                            icon: Icons.arrow_downward_rounded, iconBg: AppColors.success.withOpacity(0.12)),
                        const SizedBox(width: 14),
                        _StatCard(isDark: isDark, cardColor: cardColor, title: 'You Owe',
                            value: IndianFormatter.currency(totalIOwe), valueColor: AppColors.error,
                            icon: Icons.arrow_upward_rounded, iconBg: AppColors.error.withOpacity(0.12)),
                      ]),
                    ),

                    // ─── Settings ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('PREFERENCES',
                            style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.4)),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: isDark ? Border.all(color: Colors.white.withOpacity(0.06)) : null,
                            boxShadow: isDark ? null : [BoxShadow(color: AppColors.brand.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.brand.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                              child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.brand, size: 20),
                            ),
                            title: Text('Dark Mode', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15)),
                            subtitle: Text(isDark ? 'Currently enabled' : 'Currently disabled',
                                style: TextStyle(color: subColor, fontSize: 12)),
                            trailing: Switch(
                              value: isDark, onChanged: (_) => themeProvider.toggleTheme(), activeColor: AppColors.brand,
                            ),
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                        onPressed: () => _confirmLogout(context),
                        icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                        label: const Text('Log Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 16)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.error.withOpacity(0.5), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: AppColors.error.withOpacity(isDark ? 0.08 : 0.04),
                        ),
                      )),
                    ),
                    const SizedBox(height: 40),
                  ]),
                );
              },
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final bool isDark; final Color cardColor;
  final String title, value; final Color valueColor, iconBg; final IconData icon;

  const _StatCard({required this.isDark, required this.cardColor, required this.title,
      required this.value, required this.valueColor, required this.icon, required this.iconBg});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: cardColor, borderRadius: BorderRadius.circular(18),
      border: isDark ? Border.all(color: Colors.white.withOpacity(0.06)) : null,
      boxShadow: isDark ? null : [BoxShadow(color: AppColors.brand.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: valueColor, size: 18)),
      const SizedBox(height: 12),
      Text(title, style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: valueColor, fontSize: 15, fontWeight: FontWeight.bold)),
    ]),
  ));
}
