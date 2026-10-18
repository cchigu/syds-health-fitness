import 'dart:math';

import 'package:flutter/material.dart';

import '../models/nutrients.dart';

/// Colors used for each macro everywhere in the app.
class MacroColors {
  MacroColors._();
  static const protein = Color(0xFFE85D8E);
  static const carbs = Color(0xFFF2A541);
  static const fat = Color(0xFF7B6CF6);
  static const fiber = Color(0xFF3FB58A);
}

/// Calorie ring plus a bar for each macro: eaten vs. goal.
class DailyProgressCard extends StatelessWidget {
  const DailyProgressCard({
    super.key,
    required this.eaten,
    required this.goals,
  });

  final Nutrients eaten;
  final Nutrients goals;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final remaining = goals.calories - eaten.calories;
    final calorieProgress =
        goals.calories <= 0 ? 0.0 : min(1.0, eaten.calories / goals.calories);
    final over = remaining < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: calorieProgress,
                    strokeWidth: 14,
                    strokeCap: StrokeCap.round,
                    backgroundColor: colors.surfaceContainerHighest,
                    color: over ? colors.error : colors.primary,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${remaining.abs().round()}',
                          style: text.headlineLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          over ? 'calories over' : 'calories left',
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${eaten.calories.round()} eaten  ·  '
              '${goals.calories.round()} goal',
              style: text.bodySmall,
            ),
            const SizedBox(height: 20),
            _MacroBar('Protein', eaten.protein, goals.protein,
                MacroColors.protein),
            _MacroBar('Carbs', eaten.carbs, goals.carbs, MacroColors.carbs),
            _MacroBar('Fat', eaten.fat, goals.fat, MacroColors.fat),
            _MacroBar('Fiber', eaten.fiber, goals.fiber, MacroColors.fiber),
          ],
        ),
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar(this.label, this.eaten, this.goal, this.color);

  final String label;
  final double eaten;
  final double goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final progress = goal <= 0 ? 0.0 : min(1.0, eaten / goal);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: text.titleSmall),
              const Spacer(),
              Text('${eaten.round()} / ${goal.round()} g',
                  style: text.bodyMedium),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: color,
              backgroundColor: color.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}
