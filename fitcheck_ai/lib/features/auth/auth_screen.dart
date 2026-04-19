import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../core/extensions.dart';
import '../../services/supabase_service.dart';
import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _usingMagicLink = true;
  bool _otpSent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(supabaseServiceProvider).signInWithEmailOtp(email);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _isLoading = false;
      });
      context.showSnackBar('Check your inbox — link + 6-digit code sent');
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not send link. Try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final token = _otpController.text.trim();
    if (token.length < 6) {
      setState(() => _error = 'Paste the 6-digit code from your email');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(supabaseServiceProvider).verifyEmailOtp(
            email: email,
            token: token,
          );
      if (!mounted) return;
      context.go('/home');
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Invalid code. Try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (mounted) {
          context.showSnackBar('Check your email to confirm, then sign in!');
          setState(() => _isSignUp = false);
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (mounted) context.go('/home');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 60),

              // Logo & Title
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.checkroom,
                  size: 48,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'GRWM',
                style: context.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Get Ready With Me',
                style: context.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 48),

              // Email field (always visible)
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Magic-link path: show OTP field after sending.
              if (_usingMagicLink && _otpSent)
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _verifyOtp(),
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: '6-digit code',
                    hintText: 'From your email',
                    counterText: '',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

              // Password path: traditional email+password.
              if (!_usingMagicLink)
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signInWithEmail(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: _isSignUp ? 'Min 6 characters' : '',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

              // Error message
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 24),

              // Primary action button — copy depends on mode + state.
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _usingMagicLink
                          ? (_otpSent ? _verifyOtp : _sendMagicLink)
                          : _signInWithEmail,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _usingMagicLink
                              ? (_otpSent ? 'Verify code' : 'Email me a link')
                              : (_isSignUp ? 'Create Account' : 'Sign In'),
                        ),
                ),
              ),

              const SizedBox(height: 8),

              // Secondary: switch between magic-link and password flows.
              TextButton(
                onPressed: () => setState(() {
                  _usingMagicLink = !_usingMagicLink;
                  _otpSent = false;
                  _isSignUp = false;
                  _error = null;
                }),
                child: Text(
                  _usingMagicLink
                      ? 'Prefer a password? Use email + password'
                      : 'Skip the password — email me a link',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),

              // Only show sign-in / sign-up toggle in password mode.
              if (!_usingMagicLink)
                TextButton(
                  onPressed: () => setState(() {
                    _isSignUp = !_isSignUp;
                    _error = null;
                  }),
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign in'
                        : 'Don\'t have an account? Create one',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),

              const SizedBox(height: 24),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),

              const SizedBox(height: 24),

              // Social sign in buttons
              _SignInButton(
                label: 'Continue with Apple',
                icon: Icons.apple,
                onPressed: () async {
                  await ref
                      .read(authControllerProvider.notifier)
                      .signInWithApple();
                  if (!context.mounted) return;
                  context.go('/home');
                },
                isPrimary: true,
              ),
              const SizedBox(height: 12),
              _SignInButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata,
                onPressed: () async {
                  await ref
                      .read(authControllerProvider.notifier)
                      .signInWithGoogle();
                },
                isPrimary: false,
              ),

              const SizedBox(height: 32),

              // Terms
              Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy',
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _SignInButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 22),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 22),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
    );
  }
}
