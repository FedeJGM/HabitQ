import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../../core/widgets/habitq_bottom_nav.dart';
import '../../core/widgets/habitq_card.dart';
import '../../core/widgets/habitq_shell.dart';
import '../auth/user.dart';

/// Landing tab after login/onboarding: greeting card plus entry points to
/// Chat and Mis hábitos (Perfil lives in the bottom navigation). No task list:
/// the backend has no daily tasks.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AuthService _authService;
  HabitQUser? _user;
  bool _isLoadingUser = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _authService.fetchCurrentUser();
      if (!mounted) return;
      setState(() {
        _user = user;
        _isLoadingUser = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return HabitQShell(
      currentTab: HabitQTab.home,
      onLogout: _handleSignOut,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GreetingCard(
              isLoading: _isLoadingUser,
              errorMessage: _errorMessage,
              userName: _user?.name,
            ),
            const SizedBox(height: 24),
            HabitQCard(
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.chat),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 30),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Chat con HabitQ', style: _cardTitle),
                        SizedBox(height: 2),
                        Text('¿Qué deseas preguntar?', style: _cardSubtitle),
                      ],
                    ),
                  ),
                  _arrowButton(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            HabitQCard(
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.habits),
              child: Row(
                children: [
                  const Icon(Icons.checklist, color: AppColors.primary, size: 30),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Mis hábitos', style: _cardTitle)),
                  _arrowButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _cardTitle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );
  static const _cardSubtitle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  Widget _arrowButton() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.arrow_forward, size: 14, color: AppColors.textPrimary),
    );
  }
}

/// Greeting card: avatar with initials, greeting copy and the sun illustration.
class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.isLoading, this.errorMessage, this.userName});

  final bool isLoading;
  final String? errorMessage;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    final name = userName;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF79747E), width: 0.2),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 86,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          _initials(name),
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _text(context, name)),
                    ],
                  ),
                ),
              ),
              Container(
                width: 86,
                color: const Color(0xFFF4F5FC),
                child: Image.asset('assets/images/sun.png', fit: BoxFit.contain),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _text(BuildContext context, String? name) {
    if (isLoading) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (errorMessage != null) {
      return Text(
        errorMessage!,
        style: const TextStyle(color: AppColors.error, fontSize: 12),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¡Hola, $name!',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Es un nuevo día.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  static String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'HQ';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }
}
