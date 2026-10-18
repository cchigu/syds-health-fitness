import 'package:flutter/material.dart';

import '../models/macro_split.dart';
import '../models/user_profile.dart';
import '../services/goal_calculator.dart';
import '../services/profile_repository.dart';
import '../utils/units.dart';
import '../widgets/daily_progress_card.dart';

/// Maintenance calories, goal and pace, daily calories, and linked macros.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  /// The split while a slider is being dragged (saved when released).
  MacroSplit? _dragSplit;

  ProfileRepository get _repo => ProfileRepository.instance;

  // ---------------------------------------------------------------- dialogs

  /// Asks for a whole number. Returns null if cancelled.
  Future<double?> _askNumber({
    required String title,
    required String suffix,
    required double initial,
    String? help,
  }) {
    final controller = TextEditingController(text: '${initial.round()}');
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: suffix,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) =>
                  Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            ),
            if (help != null) ...[
              const SizedBox(height: 12),
              Text(help, style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _editCalories(GoalPlan plan) async {
    final value = await _askNumber(
      title: 'Daily calories',
      suffix: 'kcal',
      initial: plan.calories,
      help: 'Your macros will scale to match.',
    );
    if (value == null) return;
    if (value < 800 || value > 6000) {
      _snack('Calories should be between 800 and 6,000.');
      return;
    }
    await _repo.setCaloriesOverride(value.roundToDouble());
  }

  Future<void> _editMacroGrams(GoalPlan plan, Macro macro) async {
    final current = switch (macro) {
      Macro.protein => plan.goals.protein,
      Macro.carbs => plan.goals.carbs,
      Macro.fat => plan.goals.fat,
    };
    final value = await _askNumber(
      title: macro.label,
      suffix: 'g',
      initial: current,
      help: 'The other macros adjust so the total stays at '
          '${formatKcal(plan.calories)} calories.',
    );
    if (value == null || value < 0) return;
    await _repo.setMacroSplit(
        plan.split.withGrams(macro, value, plan.calories));
  }

  Future<void> _editFiber(GoalPlan plan) async {
    final value = await _askNumber(
      title: 'Fiber',
      suffix: 'g',
      initial: plan.goals.fiber,
      help: 'Fiber is counted as part of carbs, so it doesn\'t change the '
          'other macros. It scales with calories.',
    );
    if (value == null || value < 0) return;
    await _repo.setMacroSplit(plan.split.withFiberGrams(value, plan.calories));
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final plan = _repo.plan;
        return Scaffold(
          appBar: AppBar(title: const Text('Daily goals')),
          body: SafeArea(
            child: plan == null
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Fill in your profile (birthday, height and weight) '
                      'and your goals will be worked out for you.',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _maintenanceCard(plan),
                      _goalCard(plan),
                      _caloriesCard(plan),
                      _macrosCard(plan),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _cardTitle(String title, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );

  // 1. Maintenance -----------------------------------------------------------

  Widget _maintenanceCard(GoalPlan plan) {
    final m = plan.maintenance;
    final units = _repo.profile.units;
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    final String source;
    if (!m.usesData) {
      source = 'Estimated from your profile for now. Once you\'ve logged food '
          'and weight for ${m.windowDays} days, this is worked out from what '
          'your body actually does.';
    } else if (m.confidence < 0.999) {
      source = 'Blending your own data (${(m.confidence * 100).round()}%) '
          'with the profile estimate while more days are logged.';
    } else {
      source = 'Based on your last ${m.windowDays} days of food and weight.';
    }

    Widget side(String label, String value, String note) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelMedium),
                const SizedBox(height: 4),
                Text(value, style: text.titleLarge),
                Text(note, style: text.bodySmall),
              ],
            ),
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Maintenance calories'),
            Text(
              '${formatKcal(m.calories)} cal / day',
              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('What keeps your weight steady. $source',
                style: text.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                side('Profile formula', formatKcal(m.formulaCalories),
                    'Resting ${formatKcal(plan.bmr)} × activity'),
                const SizedBox(width: 8),
                side(
                  'Your data',
                  m.dataCalories == null ? '—' : formatKcal(m.dataCalories!),
                  m.dataCalories == null
                      ? '${m.loggedDays}/${MaintenanceEstimator.minLoggedDays} food days, '
                          '${m.weighIns}/${MaintenanceEstimator.minWeighIns} weigh-ins'
                      : 'Ate ${formatKcal(m.avgIntake!)} avg, '
                          '${formatTrend(m.weightTrendKgPerWeek!, units)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2. Goal and pace ---------------------------------------------------------

  Widget _goalCard(GoalPlan plan) {
    final p = _repo.profile;
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardTitle('Your goal'),
            SegmentedButton<Goal>(
              showSelectedIcon: false,
              segments: [
                for (final g in Goal.values)
                  ButtonSegment(value: g, label: Text(g.shortLabel)),
              ],
              selected: {p.goal},
              onSelectionChanged: (s) => _repo.setGoal(s.first),
            ),
            if (plan.rateOptions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('How fast?', style: text.labelLarge),
              const SizedBox(height: 4),
              for (final o in plan.rateOptions)
                _RateTile(
                  option: o,
                  units: p.units,
                  selected: !plan.caloriesAreCustom &&
                      (o.kgPerWeek - p.rateKgPerWeek).abs() < 0.01,
                  onTap: () => _repo.setRate(o.kgPerWeek),
                ),
              if (plan.rateOptions.any((o) => o.atFloor))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Faster paces are limited to ${formatKcal(plan.calorieFloor.toDouble())} '
                    'calories a day, the usual minimum without a doctor\'s advice.',
                    style: text.bodySmall?.copyWith(color: colors.outline),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // 3. Calories --------------------------------------------------------------

  Widget _caloriesCard(GoalPlan plan) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final belowFloor = plan.calories < plan.calorieFloor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(
              'Daily calories',
              trailing: IconButton(
                tooltip: 'Set my own calories',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editCalories(plan),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatKcal(plan.calories),
                  style:
                      text.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('cal / day', style: text.bodyMedium),
                ),
                const Spacer(),
                if (plan.caloriesAreCustom)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Recommended', style: text.labelSmall),
                      Text(formatKcal(plan.autoCalories),
                          style: text.titleMedium),
                    ],
                  ),
              ],
            ),
            Text(
              plan.caloriesAreCustom
                  ? 'Your own number.'
                  : 'Recommended for your goal and pace.',
              style: text.bodySmall,
            ),
            if (belowFloor)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Heads up: that\'s below ${formatKcal(plan.calorieFloor.toDouble())} '
                  'calories a day, lower than most guidelines suggest without '
                  'a doctor\'s advice.',
                  style: text.bodySmall?.copyWith(color: colors.error),
                ),
              ),
            if (plan.caloriesAreCustom)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _repo.setCaloriesOverride(null),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                      'Use recommended (${formatKcal(plan.autoCalories)})'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 4. Macros ----------------------------------------------------------------

  Widget _macrosCard(GoalPlan plan) {
    final text = Theme.of(context).textTheme;
    final split = _dragSplit ?? plan.split;
    final goals = split.goalsFor(plan.calories);

    Color colorOf(Macro m) => switch (m) {
          Macro.protein => MacroColors.protein,
          Macro.carbs => MacroColors.carbs,
          Macro.fat => MacroColors.fat,
        };
    double gramsOf(Macro m) => switch (m) {
          Macro.protein => goals.protein,
          Macro.carbs => goals.carbs,
          Macro.fat => goals.fat,
        };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Macros'),
            Text(
              'Drag a slider or tap the grams to type a number. The others '
              'adjust so everything adds up to ${formatKcal(plan.calories)} '
              'calories.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final m in Macro.values) ...[
              Row(
                children: [
                  Icon(Icons.circle, size: 12, color: colorOf(m)),
                  const SizedBox(width: 8),
                  Text(m.label, style: text.titleSmall),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _editMacroGrams(plan, m),
                    child: Text(
                      '${gramsOf(m).round()} g  ·  '
                      '${(split.share(m) * 100).round()}%',
                    ),
                  ),
                ],
              ),
              Slider(
                value: split.share(m),
                min: MacroSplit.minShare,
                max: MacroSplit.maxShare,
                activeColor: colorOf(m),
                onChanged: (v) =>
                    setState(() => _dragSplit = split.withShare(m, v)),
                onChangeEnd: (v) async {
                  final finalSplit = (_dragSplit ?? split).withShare(m, v);
                  await _repo.setMacroSplit(finalSplit);
                  if (mounted) setState(() => _dragSplit = null);
                },
              ),
            ],
            const Divider(),
            Row(
              children: [
                const Icon(Icons.circle, size: 12, color: MacroColors.fiber),
                const SizedBox(width: 8),
                Text('Fiber', style: text.titleSmall),
                const Spacer(),
                TextButton(
                  onPressed: () => _editFiber(plan),
                  child: Text('${goals.fiber.round()} g'),
                ),
              ],
            ),
            if (plan.splitIsCustom)
              TextButton.icon(
                onPressed: () => _repo.setMacroSplit(null),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Reset macros to recommended'),
              )
            else
              Text(
                'Recommended: protein ${_proteinRule()}, fat 30%, carbs the '
                'rest, fiber 14 g per 1,000 calories.',
                style: text.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  String _proteinRule() =>
      _repo.profile.goal == Goal.maintain ? '1.6 g/kg' : '1.8 g/kg';
}

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.option,
    required this.units,
    required this.selected,
    required this.onTap,
  });

  final RateOption option;
  final Units units;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: selected ? colors.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected ? colors.primary : colors.outline,
        ),
        title: Row(
          children: [
            Text(formatRate(option.kgPerWeek, units)),
            if (option.recommended) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Recommended',
                  style: text.labelSmall?.copyWith(color: colors.onPrimary),
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatKcal(option.calories), style: text.titleMedium),
            Text(option.atFloor ? 'minimum' : 'cal / day',
                style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
