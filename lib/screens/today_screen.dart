import 'package:flutter/material.dart';
import 'placeholder_page.dart';

/// Today tab: food log, calories and macros (built in Milestones 3–6).
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Today',
      icon: Icons.restaurant,
      comingSoon:
          'Your meals, calories and macros for the day will live here.',
    );
  }
}
