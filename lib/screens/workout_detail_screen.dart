import 'package:flutter/material.dart';

import '../data/exercise_library.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';
import '../services/profile_repository.dart';
import '../services/workout_repository.dart';
import '../utils/dates.dart';
import '../utils/units.dart';
import '../widgets/time_breakdown.dart';

/// One workout: warm-up, exercises, treadmill and stretches.
///
/// Tap an exercise for how-to steps, to swap it, to set her own sets /
/// reps / weight, or to take it out. "+" adds an exercise (from the
/// library or one she makes up). Tick them off as you go.
class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({
    super.key,
    required this.workout,
    required this.day,
    this.canSwap = true,
    this.rebuild,
  });

  final PlannedWorkout workout;

  /// Rebuilds the workout after an edit (so changes show right away).
  final PlannedWorkout? Function()? rebuild;
  final DateTime day;
  final bool canSwap;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final Set<String> _ticked = {};
  late PlannedWorkout _workout = widget.workout;

  WorkoutPrefsRepository get _prefs => WorkoutPrefsRepository.instance;
  String? get _session => _workout.sessionKey;
  Units get _units => ProfileRepository.instance.profile.units;

  String _key(int s, int i) => '$s:$i';

  int get _total =>
      _workout.sections.fold(0, (n, s) => n + s.exercises.length);

  void _refresh() {
    final fresh = widget.rebuild?.call();
    if (fresh != null && mounted) setState(() => _workout = fresh);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ---------------------------------------------------------- exercise sheet

  Future<void> _showExercise(PlannedExercise pe) async {
    final result = await showModalBottomSheet<(String, Exercise?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ExerciseSheet(
        planned: pe,
        canSwap: widget.canSwap && pe.slotKey != null && pe.extraIndex == null,
        canEdit: _session != null,
      ),
    );
    if (result == null || !mounted) return;
    final (action, swapTo) = result;
    final session = _session;

    switch (action) {
      case 'swap':
        if (swapTo == null || pe.slotKey == null) return;
        await _prefs.swap(pe.slotKey!, swapTo.id);
        _snack('Swapped for ${swapTo.name}');
      case 'edit':
        if (session == null) return;
        final o = await _askNumbers(pe.exercise,
            current: pe.prescription, currentWeight: pe.weight);
        if (o == null) return;
        if (pe.extraIndex != null) {
          await _prefs.updateExtra(
            session,
            pe.extraIndex!,
            ExtraExercise(
              exerciseId: pe.exercise.id,
              prescription: o.prescription,
              weightLb: o.weightLb,
            ),
          );
        } else {
          await _prefs.setOverride(session, pe.exercise.id, o);
        }
      case 'reset':
        if (session == null) return;
        await _prefs.setOverride(session, pe.exercise.id, null);
      case 'remove':
        if (session == null) return;
        if (pe.extraIndex != null) {
          await _prefs.updateExtra(session, pe.extraIndex!, null);
        } else {
          await _prefs.setRemoved(session, pe.exercise.id, true);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Removed ${pe.exercise.name}'),
            action: pe.extraIndex != null
                ? null
                : SnackBarAction(
                    label: 'Undo',
                    onPressed: () async {
                      await _prefs.setRemoved(session, pe.exercise.id, false);
                      _refresh();
                    },
                  ),
          ));
    }
    _refresh();
  }

  // ------------------------------------------------------ her own numbers

  /// Asks for sets × reps (+ weight) for strength/core, or a single amount
  /// (time) for cardio, stretches and warm-ups.
  Future<ExerciseOverride?> _askNumbers(Exercise e,
      {String? current, String? currentWeight}) async {
    final setsBased =
        e.kind == ExerciseKind.strength || e.kind == ExerciseKind.core;
    final unit = _units == Units.imperial ? 'lb' : 'kg';

    // Pre-fill from what's shown now, e.g. "3 × 10–12 each side".
    var setsText = '3';
    var repsText = e.timeBased ? '30 s' : '10';
    var amountText = current ?? '';
    if (setsBased && current != null && current.contains('×')) {
      final parts = current.split('×');
      setsText = parts.first.trim();
      repsText = parts.sublist(1).join('×').trim();
    }
    final weightMatch =
        RegExp(r'(\d+(?:\.\d+)?)\s*(?:lb|kg)?$').firstMatch(
            (currentWeight ?? '').trim());
    final sets = TextEditingController(text: setsText);
    final reps = TextEditingController(text: repsText);
    final amount = TextEditingController(text: amountText);
    final weight = TextEditingController(text: weightMatch?.group(1) ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (setsBased) ...[
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: sets,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sets',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('×'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: reps,
                      decoration: InputDecoration(
                        labelText: e.timeBased ? 'Time' : 'Reps',
                        hintText: e.timeBased ? '30 s' : '12',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (e.kind == ExerciseKind.strength) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: weight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Dumbbell weight (optional)',
                    suffixText: unit,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ] else
              TextField(
                controller: amount,
                decoration: const InputDecoration(
                  labelText: 'How long',
                  hintText: 'e.g. 15 min or Hold 45 s',
                  border: OutlineInputBorder(),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return null;

    final String prescription;
    if (setsBased) {
      final n = int.tryParse(sets.text.trim());
      final r = reps.text.trim();
      if (n == null || n <= 0 || r.isEmpty) {
        _snack('Please enter sets and reps.');
        return null;
      }
      prescription = '$n × $r';
    } else {
      if (amount.text.trim().isEmpty) return null;
      prescription = amount.text.trim();
    }
    final w = double.tryParse(weight.text.trim().replaceAll(',', '.'));
    return ExerciseOverride(
      prescription: prescription,
      weightLb: w == null || w <= 0
          ? null
          : (_units == Units.imperial ? w : kgToLb(w)),
    );
  }

  // ------------------------------------------------------- add an exercise

  Future<void> _addExercise() async {
    final session = _session;
    final p = _prefs.prefs;
    if (session == null || p == null) return;

    final picked = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AddExerciseSheet(prefs: p),
    );
    if (!mounted || picked == null) return;

    Exercise exercise;
    if (picked == 'create') {
      final def = await _createExercise();
      if (def == null) return;
      exercise = def.toExercise();
    } else {
      exercise = picked as Exercise;
    }
    if (!mounted) return;

    final defaults = switch (exercise.kind) {
      ExerciseKind.cardio => '10 min',
      ExerciseKind.stretch => 'Hold 30 s${exercise.perSide ? ' each side' : ''}',
      ExerciseKind.warmup => '2 min',
      _ => exercise.timeBased ? '3 × 30 s' : '3 × 10',
    };
    final o = await _askNumbers(exercise, current: defaults);
    if (o == null) return;
    await _prefs.addExtra(
      session,
      ExtraExercise(
        exerciseId: exercise.id,
        prescription: o.prescription,
        weightLb: o.weightLb,
      ),
    );
    _snack('Added ${exercise.name}');
    _refresh();
  }

  Future<CustomExerciseDef?> _createExercise() async {
    final name = TextEditingController();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('My own exercise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Donkey kicks',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'How to do it (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Next'),
          ),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return null;
    return _prefs.createExercise(name.text.trim(), notes.text);
  }

  Future<void> _resetWorkout() async {
    final session = _session;
    if (session == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset this workout?'),
        content: const Text(
            'Your swaps, numbers, removed and added exercises for this '
            'workout go back to the original plan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _prefs.resetWorkout(session);
    _refresh();
  }

  Future<void> _finish() async {
    final log = WorkoutLogRepository.instance;
    await log.markDone(widget.day, _workout.title, _workout.minutes);
    if (!mounted) return;
    _snack('Workout done! 💪');
    Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final w = _workout;
    final alreadyDone = WorkoutLogRepository.instance.doneOn(widget.day);
    final editable = _session != null && _prefs.prefs != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(w.title),
        actions: [
          if (editable) ...[
            IconButton(
              tooltip: 'Add an exercise',
              icon: const Icon(Icons.add),
              onPressed: _addExercise,
            ),
            PopupMenuButton<String>(
              onSelected: (_) => _resetWorkout(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'reset',
                  child: Text('Reset this workout'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Text(
                '${friendlyDay(widget.day)} · ${w.subtitle}',
                style: text.bodyMedium?.copyWith(color: colors.outline),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('About ${w.breakdown.total} minutes',
                        style: text.titleMedium),
                    const SizedBox(height: 10),
                    TimeBreakdown(breakdown: w.breakdown),
                  ],
                ),
              ),
            ),
            if (_total > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _ticked.length / _total,
                    minHeight: 8,
                  ),
                ),
              ),
            for (var s = 0; s < w.sections.length; s++) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 20, 8, 4),
                child: Text(w.sections[s].title, style: text.titleMedium),
              ),
              if (w.sections[s].note != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: Text(w.sections[s].note!, style: text.bodySmall),
                ),
              for (var i = 0; i < w.sections[s].exercises.length; i++)
                _ExerciseTile(
                  planned: w.sections[s].exercises[i],
                  done: _ticked.contains(_key(s, i)),
                  onToggle: () => setState(() {
                    final k = _key(s, i);
                    _ticked.contains(k) ? _ticked.remove(k) : _ticked.add(k);
                  }),
                  onOpen: () => _showExercise(w.sections[s].exercises[i]),
                ),
            ],
            if (editable)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('Add an exercise'),
                ),
              ),
            const SizedBox(height: 16),
            if (alreadyDone)
              OutlinedButton.icon(
                onPressed: () async {
                  await WorkoutLogRepository.instance.undo(widget.day);
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.undo),
                label: const Text('Done ✓ — tap to undo'),
              )
            else
              FilledButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.check),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Finish workout'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.planned,
    required this.done,
    required this.onToggle,
    required this.onOpen,
  });

  final PlannedExercise planned;
  final bool done;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final e = planned.exercise;
    final colors = Theme.of(context).colorScheme;
    final details = [
      planned.prescription,
      if (planned.weight != null) planned.weight!,
    ].join('  ·  ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onOpen,
        leading: Checkbox(value: done, onChanged: (_) => onToggle()),
        title: Text(
          e.name,
          style: done
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: Text(details),
        trailing: planned.custom
            ? Icon(Icons.edit, size: 18, color: colors.primary)
            : const Icon(Icons.info_outline),
      ),
    );
  }
}

/// How-to for one exercise, plus swap / edit / remove.
/// Pops with (action, exercise-to-swap-in).
class _ExerciseSheet extends StatelessWidget {
  const _ExerciseSheet({
    required this.planned,
    required this.canSwap,
    required this.canEdit,
  });

  final PlannedExercise planned;
  final bool canSwap;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final e = planned.exercise;
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(e.name, style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              [
                planned.prescription,
                if (planned.weight != null) planned.weight!,
                if (planned.rest != null) planned.rest!,
              ].join('  ·  '),
              style: text.titleSmall?.copyWith(color: colors.primary),
            ),
            if (planned.custom)
              Text('Your numbers', style: text.labelSmall),
            const SizedBox(height: 4),
            Text(e.equipment, style: text.bodySmall),
            const SizedBox(height: 16),
            for (var i = 0; i < e.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: colors.primaryContainer,
                      child: Text('${i + 1}',
                          style: text.labelSmall?.copyWith(
                              color: colors.onPrimaryContainer)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(e.steps[i], style: text.bodyLarge)),
                  ],
                ),
              ),
            if (e.tip != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: colors.onSecondaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(e.tip!,
                          style:
                              TextStyle(color: colors.onSecondaryContainer)),
                    ),
                  ],
                ),
              ),
            if (canEdit) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.pop(context, ('edit', null)),
                      icon: const Icon(Icons.tune),
                      label: Text(e.kind == ExerciseKind.strength
                          ? 'Edit sets & weight'
                          : 'Edit amount'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, ('remove', null)),
                      icon: const Icon(Icons.remove_circle_outline),
                      label: const Text('Remove'),
                    ),
                  ),
                ],
              ),
              if (planned.custom && planned.extraIndex == null)
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, ('reset', null)),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Use the plan\'s numbers again'),
                ),
            ],
            if (canSwap && planned.alternatives.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Swap for', style: text.titleSmall),
              const SizedBox(height: 4),
              for (final alt in planned.alternatives)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.swap_horiz),
                  title: Text(alt.name),
                  subtitle: Text(alt.equipment),
                  onTap: () => Navigator.pop(context, ('swap', alt)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pick any exercise from the library (or her own), or make a new one.
/// Pops with an [Exercise], or the string 'create'.
class _AddExerciseSheet extends StatefulWidget {
  const _AddExerciseSheet({required this.prefs});
  final WorkoutPrefs prefs;

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  String _query = '';

  static const _groups = [
    (ExerciseKind.strength, 'Strength'),
    (ExerciseKind.core, 'Core'),
    (ExerciseKind.cardio, 'Treadmill'),
    (ExerciseKind.stretch, 'Stretches'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final p = widget.prefs;
    final q = _query.toLowerCase();
    final all = [
      ...p.customExercises.map((c) => c.toExercise()),
      ...ExerciseLibrary.all.values
          .where((e) => e.kind != ExerciseKind.warmup),
    ].where((e) => q.isEmpty || e.name.toLowerCase().contains(q)).toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search exercises',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: Icon(Icons.edit_note, color: colors.primary),
                    title: const Text('Make up my own exercise'),
                    onTap: () => Navigator.pop(context, 'create'),
                  ),
                  if (p.customExercises.isNotEmpty) ...[
                    _header('My exercises', text),
                    for (final e in all.where((e) => e.id.startsWith('mine_')))
                      _tile(e, p),
                  ],
                  for (final (kind, label) in _groups) ...[
                    if (all.any((e) =>
                        e.kind == kind && !e.id.startsWith('mine_')))
                      _header(label, text),
                    for (final e in all.where((e) =>
                        e.kind == kind && !e.id.startsWith('mine_')))
                      _tile(e, p),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String label, TextTheme text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(label, style: text.titleSmall),
      );

  Widget _tile(Exercise e, WorkoutPrefs p) {
    final colors = Theme.of(context).colorScheme;
    final loads = e.stresses.intersection(p.avoid);
    return ListTile(
      title: Text(e.name),
      subtitle: Text(
        loads.isEmpty
            ? e.equipment
            : '${e.equipment} · ⚠ loads your '
                '${loads.map((a) => a.label.toLowerCase()).join(', ')}',
        style: loads.isEmpty ? null : TextStyle(color: colors.error),
      ),
      trailing: const Icon(Icons.add),
      onTap: () => Navigator.pop(context, e),
    );
  }
}
