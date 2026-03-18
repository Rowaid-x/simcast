import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../providers/auth_provider.dart';

/// Login screen with email and password authentication.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authStateProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (mounted) {
        context.go('/conversations');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _extractErrorMessage(e),
              style: const TextStyle(color: WhisperColors.textPrimary),
            ),
            backgroundColor: WhisperColors.surfaceElevated,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _extractErrorMessage(dynamic error) {
    if (error.toString().contains('401')) {
      return 'Invalid email or password.';
    }
    if (error.toString().contains('429')) {
      return 'Too many attempts. Please try again later.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: WhisperSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: WhisperSpacing.xxxl * 1.5),

                // Logo
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: WhisperColors.accent,
                    borderRadius: BorderRadius.circular(WhisperRadius.md),
                  ),
                  child: const Center(
                    child: Text(
                      'W',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.0, 1.0),
                      duration: 400.ms,
                    ),

                const SizedBox(height: WhisperSpacing.xxl),

                // Heading
                Text(
                  'Welcome back',
                  style: WhisperTypography.heading1,
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: WhisperSpacing.sm),

                Text(
                  'Sign in to continue your conversations',
                  style: WhisperTypography.bodyMedium.copyWith(
                    color: WhisperColors.textSecondary,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                const SizedBox(height: WhisperSpacing.xxxl),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  style: WhisperTypography.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Email address',
                    prefixIcon: Icon(
                      LucideIcons.mail,
                      color: WhisperColors.textTertiary,
                      size: 20,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(
                      begin: 0.1,
                      end: 0,
                      delay: 300.ms,
                      duration: 400.ms,
                    ),

                const SizedBox(height: WhisperSpacing.lg),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: WhisperTypography.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(
                      LucideIcons.lock,
                      color: WhisperColors.textTertiary,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? LucideIcons.eyeOff
                            : LucideIcons.eye,
                        color: WhisperColors.textTertiary,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(
                      begin: 0.1,
                      end: 0,
                      delay: 400.ms,
                      duration: 400.ms,
                    ),

                const SizedBox(height: WhisperSpacing.xxl),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign In'),
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

                const SizedBox(height: WhisperSpacing.xl),

                // Register link
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: WhisperTypography.bodyMedium.copyWith(
                        color: WhisperColors.textSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: 'Create one',
                          style: WhisperTypography.bodyMedium.copyWith(
                            color: WhisperColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
