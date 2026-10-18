import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/workout_repository.dart';

/// Five quick questions that build Syd's plan:
/// which days, how long, main goal, experience, and anything to go easy on.
class WorkoutSetupScreen extends StatefulWidget {
  const WorkoutSetupScreen({super.key});

  @override
  State<WorkoutSetupScreen> createState() => _WorkoutSetupScreenState();
}

class _WorkoutSetupScreenState extends State<WorkoutSetupScreen> {
  final _pages = PageController();
  int _page = 0;
  static const _pageCount = 5;

  late Set<int> _days;
  late int _minutes;
  WorkoutFocus? _focus;
  Experience? _experience;
  late Set<BodyArea> _avoid;
  bool _nothingToAvoid = false;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final p = WorkoutPrefsRepository.instance.prefs;
    _days = {...?p?.weekdays};
    _minutes = p?.minutes ?? 30;
    _focus = p?.focus;
    _experience = p?.experience;
    _avoid = {...?p?.avoid};
    _nothingToAvoid = p != null && p.avoid.isEmpty;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_page) {
        0 => _days.isNotEmpty,
        1 => true,
        2 => _focus != null,
        3 => _experience != null,
        _ => _nothingToAvoid || _avoid.isNotEmpty,
      };

  Future<void> _next() async {
    if (_page < _pageCount - 1) {
      await _pages.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      return;
    }
    final old = WorkoutPrefsRepository.instance.prefs;
    await WorkoutPrefsRepository.instance.save(WorkoutPrefs(
      weekdays: _days,
      minutes: _minutes,
      focus: _focus!,
      experience: _experience!,
      avoid: _nothingToAvoid ? {} : _avoid,
      // Keep swaps only if nothing about which exercises fit has changed.
      swaps: old != null &&
              old.avoid.length == _avoid.length &&
              old.avoid.containsAll(_avoid)
          ? old.swaps
          : const {},
      updatedAt: DateTime.now(),
    ));
    if (mounted) Navigator.of(context).pop(true);
  }

  void _back() {
    if (_page == 0) {
      Navigator.of(context).pop();
    } else {
      _pages.previousPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your workout plan'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_page + 1) / _pageCount),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _daysPage(),
                  _lengthPage(),
                  _focusPage(),
                  _experiencePage(),
                  _avoidPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _back,
                    child: Text(_page == 0 ? 'Cancel' : 'Back'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _canContinue ? _next : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Text(_page == _pageCount - 1
                          ? 'Build my plan'
                          : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _question(String title, String? subtitle, List<Widget> children) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(title, style: text.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle, style: text.bodyMedium),
        ],
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }

  Widget _choice({
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: selected ? colors.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: icon == null ? null : Icon(icon, color: colors.primary),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected ? colors.primary : colors.outline,
        ),
      ),
    );
  }

  Widget _daysPage() => _question(
        'Which days do you want to work out?',
        'Pick as many as you like — 3 or 4 is a great start. Rest days are '
            'when your muscles actually get stronger.',
        [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(_dayNames[d - 1]),
                  selected: _days.contains(d),
                  onSelected: (on) => setState(
                      () => on ? _days.add(d) : _days.remove(d)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _days.isEmpty
                ? 'No days picked yet'
                : '${_days.length} ${_days.length == 1 ? 'day' : 'days'} a week',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      );

  Widget _lengthPage() => _question(
        'How much time do you have per workout?',
        'Including warm-up and stretching.',
        [
          for (final (m, label, sub) in const [
            (20, '20 minutes', 'Quick and focused'),
            (30, '30 minutes', 'The sweet spot'),
            (45, '45 minutes', 'More exercises and treadmill time'),
          ])
            _choice(
              title: label,
              subtitle: sub,
              icon: Icons.timer_outlined,
              selected: _minutes == m,
              onTap: () => setState(() => _minutes = m),
            ),
        ],
      );

  Widget _focusPage() => _question(
        'What\'s your main goal?',
        null,
        [
          for (final f in WorkoutFocus.values)
            _choice(
              title: f.label,
              subtitle: f.description,
              icon: switch (f) {
                WorkoutFocus.fatLoss => Icons.local_fire_department_outlined,
                WorkoutFocus.strength => Icons.fitness_center,
                WorkoutFocus.both => Icons.balance,
              },
              selected: _focus == f,
              onTap: () => setState(() => _focus = f),
            ),
        ],
      );

  Widget _experiencePage() => _question(
        'How comfortable are you with weights?',
        'This sets how many sets you do and which dumbbells to start with '
            '(up to 25 lb).',
        [
          for (final e in Experience.values)
            _choice(
              title: e.label,
              subtitle: e.description,
              selected: _experience == e,
              onTap: () => setState(() => _experience = e),
            ),
        ],
      );

  Widget _avoidPage() {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return _question(
      'Anything to go easy on?',
      'Pick any areas that are sore, injured or cranky. Exercises that put '
          'load on them are left out of your plan.',
      [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in BodyArea.values)
              FilterChip(
                label: Text(a.label),
                selected: _avoid.contains(a),
                onSelected: (on) => setState(() {
                  on ? _avoid.add(a) : _avoid.remove(a);
                  if (on) _nothingToAvoid = false;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _choice(
          title: 'Nothing — I\'m good!',
          selected: _nothingToAvoid,
          onTap: () => setState(() {
            _nothingToAvoid = !_nothingToAvoid;
            if (_nothingToAvoid) _avoid.clear();
          }),
        ),
        const SizedBox(height: 16),
        Text(
          'If anything causes sharp pain, stop that exercise. If you have an '
          'injury, a medical condition, or are pregnant, check with your '
          'doctor first.',
          style: text.bodySmall?.copyWith(color: colors.outline),
        ),
      ],
    );
  }
}
