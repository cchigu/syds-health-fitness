import 'package:flutter/material.dart';

import '../models/workout.dart';

/// Colored bar + legend: how a workout's minutes split between warm-up,
/// strength, treadmill and stretching.
class TimeBreakdown extends StatelessWidget {
  const TimeBreakdown({super.key, required this.breakdown, this.onColor});

  final WorkoutBreakdown breakdown;

  /// Text color when drawn on a colored card.
  final Color? onColor;

  static const warmupColor = Color(0xFFF2A541);
  static const strengthColor = Color(0xFFE85D8E);
  static const treadmillColor = Color(0xFF7B6CF6);
  static const stretchColor = Color(0xFF3FB58A);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final b = breakdown;
    final parts = [
      ('Warm-up', b.warmup, warmupColor),
      ('Strength', b.strength, strengthColor),
      ('Treadmill', b.treadmill, treadmillColor),
      ('Stretching', b.stretching, stretchColor),
    ].where((p) => p.$2 > 0).toList();
    if (parts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final (_, minutes, color) in parts)
                  Expanded(flex: minutes, child: Container(color: color)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final (label, minutes, color) in parts)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 10, color: color),
                  const SizedBox(width: 4),
                  Text(
                    '$label $minutes min',
                    style: text.bodySmall?.copyWith(color: onColor),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// "15 strength · 8 treadmill · 4 stretching" for list rows.
String breakdownSummary(WorkoutBreakdown b) => [
      if (b.strength > 0) '${b.strength} strength',
      if (b.treadmill > 0) '${b.treadmill} treadmill',
      if (b.stretching > 0) '${b.stretching} stretching',
    ].join(' · ');
