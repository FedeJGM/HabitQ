import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_theme.dart';
import 'habitq_card.dart';

/// Friendly error card shown where the content should have been. Screen
/// readers announce it as soon as it appears. [isConnection] adds a hint to
/// check the network; [onRetry] adds a "Reintentar" button.
class ErrorNotice extends StatelessWidget {
  const ErrorNotice({
    super.key,
    required this.message,
    this.onRetry,
    this.isConnection = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool isConnection;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('error-notice'),
      container: true,
      liveRegion: true,
      child: HabitQCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    isConnection ? Symbols.cloud_off_rounded : Symbols.error_rounded,
                    color: isConnection ? AppColors.skyDeep : AppColors.error,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (isConnection) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Revisa tu conexión e inténtalo de nuevo.',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Symbols.refresh_rounded, size: 20),
                  label: const Text('Reintentar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
