import 'package:flutter/material.dart';

import '../models/treadmill_session.dart';
import '../models/user_profile.dart';
import '../services/profile_repository.dart';
import '../services/treadmill_repository.dart';
import '../utils/dates.dart';
import '../utils/units.dart';

const double _kmPerMile = 1.609344;

/// "2.1 mi" or "3.4 km".
String distanceText(double miles, Units units) => units == Units.imperial
    ? '${trimNumber(miles, decimals: 2)} mi'
    : '${trimNumber(miles * _kmPerMile, decimals: 2)} km';

/// "3.2 mph" or "5.1 km/h".
String speedText(double mph, Units units) => units == Units.imperial
    ? '${trimNumber(mph)} mph'
    : '${trimNumber(mph * _kmPerMile)} km/h';

/// "30 min · 3.2 mph · 6% incline".
String treadmillSummary(TreadmillSession s, Units units) =>
    '${trimNumber(s.minutes)} min · ${speedText(s.speedMph, units)} · '
    '${trimNumber(s.inclinePct)}% incline';

/// Log (or edit) a treadmill session: date, time, speed and incline, with a
/// live distance and calorie estimate. Pops with true when saved.
class TreadmillLogSheet extends StatefulWidget {
  const TreadmillLogSheet({super.key, this.day, this.existing});

  /// Day to log for (defaults to today).
  final DateTime? day;
  final TreadmillSession? existing;

  @override
  State<TreadmillLogSheet> createState() => _TreadmillLogSheetState();
}

class _TreadmillLogSheetState extends State<TreadmillLogSheet> {
  late DateTime _day;
  late final TextEditingController _minutes;
  late final TextEditingController _speed;
  late final TextEditingController _incline;
  late final TextEditingController _note;

  Units get _units => ProfileRepository.instance.profile.units;
  bool get _metric => _units == Units.metric;

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final last = TreadmillRepository.instance.latest;
    _day = e?.day ?? dayOnly(widget.day ?? DateTime.now());
    final mph = e?.speedMph ?? last?.speedMph ?? 3.0;
    _minutes = TextEditingController(
        text: trimNumber(e?.minutes ?? last?.minutes ?? 30));
    _speed = TextEditingController(
        text: trimNumber(_metric ? mph * _kmPerMile : mph));
    _incline = TextEditingController(
        text: trimNumber(e?.inclinePct ?? last?.inclinePct ?? 0));
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    for (final c in [_minutes, _speed, _incline, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _mph {
    final v = _num(_speed);
    if (v == null) return null;
    return _metric ? v / _kmPerMile : v;
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: dayOnly(DateTime.now()),
    );
    if (picked != null) setState(() => _day = dayOnly(picked));
  }

  Future<void> _save() async {
    final minutes = _num(_minutes);
    final mph = _mph;
    final incline = _num(_incline) ?? 0;
    String? problem;
    if (minutes == null || minutes <= 0 || minutes > 300) {
      problem = 'Please enter how many minutes.';
    } else if (mph == null || mph <= 0 || mph > 15) {
      problem = 'Please enter your speed.';
    } else if (incline < 0 || incline > 30) {
      problem = 'Incline should be between 0 and 30%.';
    }
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final repo = TreadmillRepository.instance;
    final base = widget.existing ??
        TreadmillSession(
          id: TreadmillSession.newId(),
          day: _day,
          minutes: minutes!,
          speedMph: mph!,
          inclinePct: incline,
          updatedAt: DateTime.now(),
        );
    await repo.save(base.copyWith(
      day: _day,
      minutes: minutes,
      speedMph: mph,
      inclinePct: incline,
      note: _note.text.trim(),
    ));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final weightKg = ProfileRepository.instance.profile.weightKg ?? 65;
    final minutes = _num(_minutes) ?? 0;
    final mph = _mph ?? 0;
    final incline = _num(_incline) ?? 0;
    final kcal = estimateCalories(mph, incline, minutes, weightKg);
    final miles = mph * minutes / 60;

    InputDecoration box(String label, String suffix) => InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        );

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null
                    ? 'Log a treadmill session'
                    : 'Edit treadmill session',
                style: text.titleLarge,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _pickDay,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(friendlyDay(_day)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _minutes,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: box('Time', 'min'),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in const [15, 20, 30, 45, 60])
                    ActionChip(
                      label: Text('$m'),
                      onPressed: () => setState(() => _minutes.text = '$m'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _speed,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration:
                          box('Average speed', _metric ? 'km/h' : 'mph'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _incline,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: box('Incline', '%'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. 1 min jog / 2 min walk',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(distanceText(miles, _units),
                              style: text.titleLarge?.copyWith(
                                  color: colors.onPrimaryContainer)),
                          Text('distance',
                              style: text.bodySmall?.copyWith(
                                  color: colors.onPrimaryContainer)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('≈ ${kcal.round()}',
                              style: text.titleLarge?.copyWith(
                                  color: colors.onPrimaryContainer)),
                          Text('calories burned',
                              style: text.bodySmall?.copyWith(
                                  color: colors.onPrimaryContainer)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Calories are an estimate from your weight, speed and '
                'incline (holding the handrails lowers it).',
                style: text.bodySmall?.copyWith(color: colors.outline),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Save session'),
                ),
              ),
              if (widget.existing != null)
                TextButton(
                  onPressed: () async {
                    await TreadmillRepository.instance
                        .delete(widget.existing!);
                    if (mounted) Navigator.of(context).pop(true);
                  },
                  child: const Text('Delete session'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the sheet; returns true when something was saved or deleted.
Future<bool> showTreadmillLog(BuildContext context,
    {DateTime? day, TreadmillSession? existing}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => TreadmillLogSheet(day: day, existing: existing),
  );
  return r == true;
}
