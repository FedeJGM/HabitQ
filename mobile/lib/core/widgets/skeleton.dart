import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'habitq_card.dart';

/// A soft rounded block that stands in for content that is still loading, so
/// the layout does not jump when the real content arrives. Deliberately still
/// (no shimmer loop): the screen settles and stays cheap to draw.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.sky.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder shaped like a typical card: a title line and two shorter ones.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: HabitQCard(
        key: ValueKey('skeleton-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 160, height: 16),
            SizedBox(height: 12),
            SkeletonBox(height: 12),
            SizedBox(height: 8),
            SkeletonBox(width: 110, height: 12),
          ],
        ),
      ),
    );
  }
}

/// [count] skeleton cards separated like a real list.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          const SkeletonCard(),
        ],
      ],
    );
  }
}
