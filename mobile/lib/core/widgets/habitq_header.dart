import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Top bar from the Figma: HQ logo, centered "HabitQ" wordmark and logout.
class HabitQHeader extends StatelessWidget implements PreferredSizeWidget {
  const HabitQHeader({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/logo_hq.png',
                  width: 42,
                  height: 44,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
                const Expanded(
                  child: Text(
                    'HabitQ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout, color: AppColors.primary),
                  tooltip: 'Cerrar sesión',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
