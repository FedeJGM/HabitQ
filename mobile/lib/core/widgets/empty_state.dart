import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Friendly "nothing here yet" block: a small illustration drawn with the app
/// palette, a title, an optional message and an optional action, so an empty
/// screen always tells the user what to do next.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              key: const ValueKey('empty-state-art'),
              width: 132,
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned.fill(child: CustomPaint(painter: _ArtPainter())),
                  Icon(icon, size: 48, fill: 1, color: AppColors.skyDeep),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48), shape: const StadiumBorder()),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  const _ArtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint();

    paint.color = AppColors.sky.withValues(alpha: 0.45);
    canvas.drawCircle(center, size.shortestSide * 0.46, paint);

    paint.color = AppColors.primary.withValues(alpha: 0.16);
    canvas.drawCircle(center + Offset(size.width * 0.30, size.height * 0.22), size.shortestSide * 0.17, paint);

    paint.color = AppColors.skyDeep.withValues(alpha: 0.30);
    canvas.drawCircle(center + Offset(-size.width * 0.34, -size.height * 0.28), size.shortestSide * 0.07, paint);
    canvas.drawCircle(center + Offset(-size.width * 0.26, size.height * 0.34), size.shortestSide * 0.045, paint);
  }

  @override
  bool shouldRepaint(_ArtPainter oldDelegate) => false;
}
