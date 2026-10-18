import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/workout_repository.dart';
import '../utils/dates.dart';

/// One workout: warm-up, exercises, treadmill and stretches. Tap an
/// exercise for how-to steps (and to swap it); tick them off as you go.
class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({
    super.key,
    required this.workout,
    required this.day,
    this.canSwap = true,
    this.rebuild,
  });

  final PlannedWorkout workout;

  /// Rebuilds the workout after a swap (so the new exercise shows).
  final PlannedWorkout? Function()? rebuild;
  final DateTime day;
  final bool canSwap;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final Set<String> _ticked = {};
  late PlannedWorkout _workout = widget.workout;

  String _key(int s, int i) => '$s:$i';

  int get _total =>
      _workout.sections.fold(0, (n, s) => n + s.exercises.length);

  Future<void> _showExercise(PlannedExercise pe) async {
    final swapTo = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ExerciseSheet(
        planned: pe,
        canSwap: widget.canSwap && pe.slotKey != null,
      ),
    );
    if (swapTo == null || pe.slotKey == null) return;
    await WorkoutPrefsRepository.instance.swap(pe.slotKey!, swapTo.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Swapped for ${swapTo.name}')),
    );
    final fresh = widget.rebuild?.call();
    if (fresh != null) setState(() => _workout = fresh);
  }

  Future<void> _finish() async {
    final log = WorkoutLogRepository.instance;
    await log.markDone(widget.day, _workout.title, _workout.minutes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout done! 💪')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final w = _workout;
    final alreadyDone = WorkoutLogRepository.instance.doneOn(widget.day);

    return Scaffold(
      appBar: AppBar(title: Text(w.title)),
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
            if (_total > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
            const SizedBox(height: 24),
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
        trailing: const Icon(Icons.info_outline),
      ),
    );
  }
}

/// How-to for one exercise, with alternatives to swap in.
class _ExerciseSheet extends StatelessWidget {
  const _ExerciseSheet({required this.planned, required this.canSwap});

  final PlannedExercise planned;
  final bool canSwap;

  @override
  Widget build(BuildContext context) {
    final e = planned.exercise;
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8),
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
                  onTap: () => Navigator.pop(context, alt),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
