import 'package:flutter/material.dart';

import '../models/exercise_session.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';
import '../services/exercise_log_repository.dart';
import '../services/profile_repository.dart';
import '../utils/dates.dart';
import '../utils/units.dart';
import '../widgets/exercise_stats.dart';

/// Log the sets she actually did for one exercise on one day: weight and
/// reps per set (or seconds for holds). Pre-filled from that day's log, her
/// last session, or the plan. Pops with true when saved.
class LogSetsSheet extends StatefulWidget {
  const LogSetsSheet({
    super.key,
    required this.exercise,
    required this.day,
    this.planned,
  });

  final Exercise exercise;
  final DateTime day;
  final PlannedExercise? planned;

  @override
  State<LogSetsSheet> createState() => _LogSetsSheetState();
}

class _Row {
  _Row({String weight = '', String amount = ''})
      : weight = TextEditingController(text: weight),
        amount = TextEditingController(text: amount);

  final TextEditingController weight;

  /// Reps, or seconds for timed exercises.
  final TextEditingController amount;

  void dispose() {
    weight.dispose();
    amount.dispose();
  }
}

class _LogSetsSheetState extends State<LogSetsSheet> {
  final List<_Row> _rows = [];
  ExerciseSession? _existing;
  ExerciseSession? _last;

  ExerciseLogRepository get _repo => ExerciseLogRepository.instance;
  Units get _units => ProfileRepository.instance.profile.units;
  String get _unit => _units == Units.imperial ? 'lb' : 'kg';
  Exercise get _e => widget.exercise;
  bool get _timed => _e.timeBased;
  bool get _showWeight =>
      !_timed &&
      (_e.weightLb != null ||
          _e.equipment.toLowerCase().contains('dumbbell') ||
          _e.id.startsWith('mine_'));

  String _shownWeight(double? lb) => lb == null
      ? ''
      : trimNumber(_units == Units.imperial ? lb : lbToKg(lb));

  @override
  void initState() {
    super.initState();
    _existing = _repo.onDay(_e.id, widget.day);
    _last = _repo.lastBefore(_e.id, widget.day);
    final source = _existing ?? _last;

    if (source != null && source.sets.isNotEmpty) {
      for (final s in source.sets) {
        _rows.add(_Row(
          weight: _shownWeight(s.weightLb),
          amount: '${_timed ? (s.seconds ?? '') : (s.reps ?? '')}',
        ));
      }
      return;
    }

    // Nothing logged before: start from the plan ("3 × 10–12", "10–15 lb").
    final p = widget.planned;
    final prescription = p?.prescription ?? '';
    final sets = int.tryParse(
            RegExp(r'^\s*(\d+)\s*×').firstMatch(prescription)?.group(1) ??
                '') ??
        3;
    final afterX = prescription.contains('×')
        ? prescription.split('×').sublist(1).join('×')
        : prescription;
    final amount = RegExp(r'(\d+)').firstMatch(afterX)?.group(1) ?? '';
    final weight =
        RegExp(r'(\d+(?:\.\d+)?)').firstMatch(p?.weight ?? '')?.group(1) ?? '';
    for (var i = 0; i < sets.clamp(1, 8); i++) {
      _rows.add(_Row(weight: _showWeight ? weight : '', amount: amount));
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addSet() => setState(() {
        final prev = _rows.isEmpty ? null : _rows.last;
        _rows.add(_Row(
          weight: prev?.weight.text ?? '',
          amount: prev?.amount.text ?? '',
        ));
      });

  Future<void> _save() async {
    final sets = <ExerciseSet>[];
    for (final r in _rows) {
      final amount = int.tryParse(r.amount.text.trim());
      if (amount == null || amount <= 0) continue;
      final w = double.tryParse(r.weight.text.trim().replaceAll(',', '.'));
      final lb = (w == null || w <= 0)
          ? null
          : (_units == Units.imperial ? w : kgToLb(w));
      sets.add(_timed
          ? ExerciseSet(seconds: amount)
          : ExerciseSet(weightLb: lb, reps: amount));
    }
    if (sets.isEmpty && _existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter at least one set.'),
      ));
      return;
    }
    await _repo.save(widget.day, _e.id, sets);
    if (mounted) Navigator.of(context).pop(sets.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              Text(_e.name, style: text.titleLarge),
              Text(
                '${friendlyDay(widget.day)} · log what you actually did',
                style: text.bodySmall,
              ),
              if (_last != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Last time (${friendlyDay(_last!.day)}): '
                    '${sessionSummary(_last!, _units)}',
                    style: text.bodyMedium?.copyWith(color: colors.primary),
                  ),
                ),
              const SizedBox(height: 12),
              for (var i = 0; i < _rows.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text('Set ${i + 1}', style: text.labelLarge),
                      ),
                      if (_showWeight) ...[
                        Expanded(
                          child: TextField(
                            controller: _rows[i].weight,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'body',
                              suffixText: _unit,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('×'),
                        ),
                      ],
                      Expanded(
                        child: TextField(
                          controller: _rows[i].amount,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: _timed ? 's' : 'reps',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove set',
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _rows.length <= 1
                            ? null
                            : () => setState(() {
                                  _rows.removeAt(i).dispose();
                                }),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addSet,
                  icon: const Icon(Icons.add),
                  label: const Text('Add a set'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Save sets'),
                ),
              ),
              if (_existing != null)
                TextButton(
                  onPressed: () async {
                    await _repo.save(widget.day, _e.id, const []);
                    if (mounted) Navigator.of(context).pop(false);
                  },
                  child: Text('Delete ${friendlyDay(widget.day).toLowerCase()}\'s log'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
