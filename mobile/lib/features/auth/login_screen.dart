import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../core/theme/app_theme.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthService _authService;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = AuthService()..addListener(_onAuthServiceChanged);
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthServiceChanged);
    super.dispose();
  }

  void _onAuthServiceChanged() => setState(() {});

  Future<void> _handleGoogleSignIn() async {
    setState(() => _errorMessage = null);
    try {
      final user = await _authService.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        user.onboardingCompleted ? AppRoutes.home : AppRoutes.onboarding,
      );
    } on AuthFailure catch (e) {
      setState(() => _errorMessage = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const _WelcomeIllustration(),
              const SizedBox(height: 32),
              RichText(
                textAlign: TextAlign.left,
                text: TextSpan(
                  style: Theme.of(context).textTheme.headlineSmall,
                  children: const [
                    TextSpan(text: '¡Bienvenido de vuelta! a '),
                    TextSpan(
                      text: 'HabitQ',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                onPressed: _authService.isLoading ? null : _handleGoogleSignIn,
                icon: _authService.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Continúa con Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder illustration matching the boceto's layout slot. Swap for the
/// real asset (bike illustration) once exported from Figma.
class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.pedal_bike,
        size: 72,
        color: AppColors.primaryDark,
      ),
    );
  }
}
