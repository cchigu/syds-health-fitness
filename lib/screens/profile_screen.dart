import 'package:flutter/material.dart';
import 'placeholder_page.dart';

/// Profile tab: sign-in, body stats and settings (built in Milestone 2).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Profile',
      icon: Icons.person,
      comingSoon: 'Sign-in, your body stats and settings will live here.',
    );
  }
}
