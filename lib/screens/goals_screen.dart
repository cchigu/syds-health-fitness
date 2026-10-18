import 'package:flutter/material.dart';

import '../models/nutrients.dart';
import '../models/user_profile.dart';
import '../services/goal_calculator.dart';
import '../services/profile_repository.dart';
import '../widgets/daily_progress_card.dart';

/// Shows the daily calorie and macro goals, how they were worked out,
/// and lets Syd set her own.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();

  late bool _custom;

  ProfileRepository get _repo => ProfileRepository.instance;

  @override
  void initState() {
    super.initState();
    _custom = _repo.usingCustomGoals;
    _fillFields(_repo.goals);
  }

  @override
  void dispose() {
    for (final c in [_calories, _protein, _fat, _fiber]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillFields(Nutrients? g) {
    if (g == null) return;
    _calories.text = '${g.calories.round()}';
    _protein.text = '${g.protein.round()}';
    _fat.text = '${g.fat.round()}';
    _fiber.text = '${g.fiber.round()}';
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim());

  /// Carbs fill whatever calories protein and fat don't use.
  double? get _carbsFromFields {
    final cal = _num(_calories);
    final p = _num(_protein);
    final f = _num(_fat);
    if (cal == null || p == null || f == null) return null;
    return (cal - p * 4 - f * 9) / 4;
  }

  Future<void> _useRecommended() async {
    setState(() => _custom = false);
    await _repo.setCustomGoals(null);
    _fillFields(_repo.goals);
  }

  void _startCustom() {
    setState(() => _custom = true);
    _fillFields(_repo.goals);
  }

  Future<void> _saveCustom() async {
    final cal = _num(_calories);
    final p = _num(_protein);
    final f = _num(_fat);
    final fiber = _num(_fiber);
    final carbs = _carbsFromFields;

    String? problem;
    if (cal == null || p == null || f == null || fiber == null) {
      problem = 'Please fill in every box.';
    } else if (cal < 800 || cal > 6000) {
      problem = 'Calories should be between 800 and 6,000.';
    } else if (carbs == null || carbs < 0) {
      problem = 'Protein and fat use more calories than your total. '
          'Lower them or raise calories.';
    }
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    await _repo.setCustomGoals(Nutrients(
      calories: cal!,
      protein: p!,
      carbs: carbs!,
      fat: f!,
      fiber: fiber!,
    ).rounded());
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Goals saved')));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final rec = _repo.recommendation;
        final goals = _repo.goals;
        final text = Theme.of(context).textTheme;

        return Scaffold(
          appBar: AppBar(title: const Text('Daily goals')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (goals == null)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Fill in your profile (birthday, height and weight) '
                        'and your goals will be calculated for you.',
                      ),
                    ),
                  )
                else
                  _GoalsSummary(goals: goals),

                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Recommended'),
                      icon: Icon(Icons.auto_awesome),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Custom'),
                      icon: Icon(Icons.tune),
                    ),
                  ],
                  selected: {_custom},
                  onSelectionChanged: (s) {
                    if (s.first) {
                      _startCustom();
                    } else {
                      _useRecommended();
                    }
                  },
                ),
                const SizedBox(height: 16),

                if (!_custom && rec != null) _Explanation(rec: rec),
                if (!_custom && rec != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Recommended goals update automatically when your '
                      'weight, activity level or goal changes.',
                      style: text.bodySmall,
                    ),
                  ),

                if (_custom) _customForm(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _customForm(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final carbs = _carbsFromFields;
    final cal = _num(_calories);
    final floor = GoalCalculator.calorieFloor(_repo.profile.sex);

    Widget field(TextEditingController c, String label, String suffix,
            Color? accent) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: label,
              suffixText: suffix,
              border: const OutlineInputBorder(),
              prefixIcon: accent == null
                  ? const Icon(Icons.local_fire_department_outlined)
                  : Icon(Icons.circle, size: 14, color: accent),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field(_calories, 'Calories', 'kcal', null),
        field(_protein, 'Protein', 'g', MacroColors.protein),
        field(_fat, 'Fat', 'g', MacroColors.fat),
        field(_fiber, 'Fiber', 'g', MacroColors.fiber),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.circle,
                size: 14, color: MacroColors.carbs),
            title: const Text('Carbs'),
            subtitle: const Text('Fills the calories left after protein and fat'),
            trailing: Text(
              carbs == null ? '—' : '${carbs.round()} g',
              style: text.titleMedium?.copyWith(
                color: carbs != null && carbs < 0 ? colors.error : null,
              ),
            ),
          ),
        ),
        if (cal != null && cal < floor)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Heads up: that\'s below $floor calories a day, which is lower '
              'than most guidelines suggest without a doctor\'s advice.',
              style: text.bodySmall?.copyWith(color: colors.error),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saveCustom,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Save my goals'),
          ),
        ),
      ],
    );
  }
}

/// Big calorie number with the four macro goals underneath.
class _GoalsSummary extends StatelessWidget {
  const _GoalsSummary({required this.goals});

  final Nutrients goals;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget macro(String label, double grams, Color color) => Expanded(
          child: Column(
            children: [
              Icon(Icons.circle, size: 12, color: color),
              const SizedBox(height: 4),
              Text('${grams.round()} g', style: text.titleMedium),
              Text(label, style: text.bodySmall),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('${goals.calories.round()}',
                style: text.displaySmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text('calories a day', style: text.bodyMedium),
            const SizedBox(height: 20),
            Row(
              children: [
                macro('Protein', goals.protein, MacroColors.protein),
                macro('Carbs', goals.carbs, MacroColors.carbs),
                macro('Fat', goals.fat, MacroColors.fat),
                macro('Fiber', goals.fiber, MacroColors.fiber),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "How we worked this out" card for the recommended goals.
class _Explanation extends StatelessWidget {
  const _Explanation({required this.rec});

  final GoalBreakdown rec;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = ProfileRepository.instance.profile;
    final adj = rec.adjustment;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              Text(value, style: text.titleSmall),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How these were worked out', style: text.titleMedium),
            const SizedBox(height: 8),
            row('Calories burned at rest', '${rec.bmr.round()}'),
            row('× ${p.activityLevel.label.toLowerCase()} (${rec.activityFactor})',
                '${rec.tdee.round()}'),
            row(
              p.goal.label,
              adj == 0 ? '±0' : (adj > 0 ? '+$adj' : '$adj'),
            ),
            if (rec.hitCalorieFloor)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Raised to the minimum of ${rec.calorieFloor} calories.',
                  style: text.bodySmall,
                ),
              ),
            const Divider(height: 24),
            row('Protein', '${rec.proteinPerKg} g per kg body weight'),
            row('Fat', '30% of calories'),
            row('Carbs', 'the rest of calories'),
            row('Fiber', '14 g per 1,000 calories'),
          ],
        ),
      ),
    );
  }
}
