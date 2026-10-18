import 'package:flutter/material.dart';
import 'placeholder_page.dart';

/// Progress tab: weight log and chart (built in Milestone 7).
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Progress',
      icon: Icons.show_chart,
      comingSoon: 'Your weight history and progress chart will live here.',
    );
  }
}
