import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  String _cleanError(String raw) {
    if (raw.contains('email-already-in-use')) return 'This email is already registered. Please log in instead.';
    if (raw.contains('weak-password')) return 'Password should be at least 6 characters.';
    if (raw.contains('invalid-email')) return 'Please enter a valid email address.';
    if (raw.contains('network-request-failed')) return 'No internet connection. Please try again.';
    return 'Sign up failed. Please try again.';
  }

  void _signup() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_cleanError(e.toString())), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // App Logo
              Center(
                child: Image.asset(
                  'assets/images/app_logo.png',
                  height: 140,
                  width: 140,
                ),
              ),
              const SizedBox(height: 20),

              const Text('Create Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              const Text('Join Muneem Ji to split expenses with friends', style: TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 36),

              CustomTextField(label: 'Full Name', hint: 'John Doe', prefixIcon: Icons.person_outline, controller: _nameController),
              const SizedBox(height: 16),

              CustomTextField(label: 'Email Address', hint: 'you@example.com', prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, controller: _emailController),
              const SizedBox(height: 16),

              CustomTextField(label: 'Password', hint: 'Create a strong password (min 6 chars)', prefixIcon: Icons.lock_outline, isPassword: true, controller: _passwordController),
              const SizedBox(height: 36),

              CustomButton(text: 'Create Account', isLoading: _isLoading, onPressed: _signup),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?", style: TextStyle(color: AppColors.textSecondary)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
