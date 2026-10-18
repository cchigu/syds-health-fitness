import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_repository.dart';
import '../utils/units.dart';
import 'edit_profile_screen.dart';
import 'sign_in_screen.dart';

/// Profile tab: cloud account, body stats and settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openEdit(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
      );

  void _openSignIn(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
      );

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your profile stays on this phone. Sign back in any time to sync.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ProfileRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final p = repo.profile;
        final user = repo.user;
        final colors = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        final displayName = p.name.trim().isEmpty ? 'Hi there!' : p.name;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Edit profile',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _openEdit(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              Center(
                child: _Avatar(
                  photoUrl: user?.photoURL,
                  name: p.name,
                ),
              ),
              const SizedBox(height: 12),
              Text(displayName,
                  textAlign: TextAlign.center, style: text.headlineSmall),
              const SizedBox(height: 20),

              // Cloud account
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: user == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Icon(Icons.cloud_off_outlined,
                                  color: colors.outline),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Not signed in. Your data is saved on '
                                  'this phone only.',
                                ),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => _openSignIn(context),
                              child: const Text('Sign in to back up'),
                            ),
                          ],
                        )
                      : Row(children: [
                          Icon(Icons.cloud_done_outlined,
                              color: colors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Backed up to the cloud'),
                                Text(
                                  user.email ?? 'Signed in',
                                  style: text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _confirmSignOut(context),
                            child: const Text('Sign out'),
                          ),
                        ]),
                ),
              ),

              // Prompt to finish setup
              if (!p.isComplete)
                Card(
                  color: colors.primaryContainer,
                  child: ListTile(
                    leading: Icon(Icons.auto_awesome,
                        color: colors.onPrimaryContainer),
                    title: Text(
                      'Set up your profile',
                      style: TextStyle(color: colors.onPrimaryContainer),
                    ),
                    subtitle: Text(
                      'Your stats are used to calculate your calorie '
                      'and macro goals.',
                      style: TextStyle(color: colors.onPrimaryContainer),
                    ),
                    trailing: Icon(Icons.chevron_right,
                        color: colors.onPrimaryContainer),
                    onTap: () => _openEdit(context),
                  ),
                ),

              // Details
              Card(
                child: Column(
                  children: [
                    _row(Icons.wc, 'Sex', p.sex.label),
                    _row(Icons.cake_outlined, 'Age',
                        p.age == null ? '—' : '${p.age}'),
                    _row(Icons.height, 'Height',
                        formatHeight(p.heightCm, p.units)),
                    _row(Icons.monitor_weight_outlined, 'Weight',
                        formatWeight(p.weightKg, p.units)),
                    _row(Icons.directions_walk, 'Activity',
                        p.activityLevel.label),
                    _row(Icons.flag_outlined, 'Goal', p.goal.label),
                    _row(Icons.straighten, 'Units', p.units.label),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(IconData icon, String label, String value) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(value),
      );
}

/// Shows the Google profile photo when signed in with Google, otherwise
/// the first letter of the name (or a heart before a name is set).
class _Avatar extends StatefulWidget {
  const _Avatar({required this.photoUrl, required this.name});

  final String? photoUrl;
  final String name;

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> {
  bool _photoFailed = false;

  @override
  void didUpdateWidget(covariant _Avatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) _photoFailed = false;
  }

  /// Google photo links default to a tiny 96px image; ask for a sharper one.
  String _sharper(String url) =>
      url.replaceFirst(RegExp(r'=s\d+-c$'), '=s400-c');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = widget.photoUrl;
    final showPhoto = url != null && url.isNotEmpty && !_photoFailed;
    final trimmed = widget.name.trim();

    return CircleAvatar(
      radius: 40,
      backgroundColor: colors.primaryContainer,
      backgroundImage: showPhoto ? NetworkImage(_sharper(url)) : null,
      onBackgroundImageError: showPhoto
          ? (_, __) {
              if (mounted) setState(() => _photoFailed = true);
            }
          : null,
      child: showPhoto
          ? null
          : Text(
              trimmed.isEmpty ? '♥' : trimmed[0].toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: colors.onPrimaryContainer),
            ),
    );
  }
}
