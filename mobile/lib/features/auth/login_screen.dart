import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/decor/background_shapes.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../consent/consent_storage.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthService _authService;
  final _consentStorage = const ConsentStorage();
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
      final nextRoute =
          user.onboardingCompleted ? AppRoutes.home : AppRoutes.onboarding;
      final hasConsented = await _consentStorage.hasAccepted();
      if (!mounted) return;
      if (hasConsented) {
        Navigator.of(context).pushReplacementNamed(nextRoute);
      } else {
        Navigator.of(context)
            .pushReplacementNamed(AppRoutes.consent, arguments: nextRoute);
      }
    } on AuthFailure catch (e) {
      setState(() => _errorMessage = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Stack(
          children: [
            const Positioned.fill(child: BackgroundShapes()),
            SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    const FadeSlideIn(child: _WelcomeIllustration()),
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: RichText(
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
                      ),
                    ),
                    const SizedBox(height: 48),
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const SizedBox(height: 16),
                    ],
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 160),
                      child: OutlinedButton.icon(
                        onPressed:
                            _authService.isLoading ? null : _handleGoogleSignIn,
                        icon: _authService.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Image.asset('assets/images/google.png',
                                width: 18, height: 18),
                        label: const Text('Continúa con Google'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 380 / 253.333,
        child: Image.asset(
          'assets/images/eco_traveling.png',
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
