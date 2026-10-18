import 'package:flutter/material.dart';
import 'placeholder_page.dart';

/// Workouts tab: home routine with dumbbells, treadmill and stretches
/// (built in Milestone 8).
class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Workouts',
      icon: Icons.fitness_center,
      comingSoon:
          'Your at-home dumbbell, treadmill and stretching routine will live here.',
    );
  }
}
