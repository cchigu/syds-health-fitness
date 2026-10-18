import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/profile_repository.dart';
import '../utils/units.dart';

/// Form for name, body stats, activity level, goal and units.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _feet = TextEditingController();
  final _inches = TextEditingController();
  final _cm = TextEditingController();
  final _weight = TextEditingController();

  late Sex _sex;
  DateTime? _birthDate;
  late ActivityLevel _activity;
  late Goal _goal;
  late Units _units;

  // The exact saved values, kept until the field is retyped. Switching units
  // reuses these instead of re-converting rounded numbers (174 cm -> 5' 9"
  // -> 175 cm, or 150 lbs -> 68 kg -> 149.9 lbs).
  double? _exactHeightCm;
  double? _exactWeightKg;

  @override
  void initState() {
    super.initState();
    final p = ProfileRepository.instance.profile;
    _name.text = p.name;
    _sex = p.sex;
    _birthDate = p.birthDate;
    _activity = p.activityLevel;
    _goal = p.goal;
    _units = p.units;
    _exactHeightCm = p.heightCm;
    _exactWeightKg = p.weightKg;
    _fillMeasurements(p.heightCm, p.weightKg);
  }

  @override
  void dispose() {
    for (final c in [_name, _feet, _inches, _cm, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- Measurement fields (shown in the chosen units, stored in metric) ----

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  double? _currentHeightCm() {
    if (_exactHeightCm != null) return _exactHeightCm;
    if (_units == Units.metric) return _parse(_cm);
    final ft = _parse(_feet);
    final inch = _parse(_inches);
    if (ft == null && inch == null) return null;
    return ftInToCm((ft ?? 0).round(), (inch ?? 0).round());
  }

  double? _currentWeightKg() {
    if (_exactWeightKg != null) return _exactWeightKg;
    final w = _parse(_weight);
    if (w == null) return null;
    return _units == Units.imperial ? lbToKg(w) : w;
  }

  void _fillMeasurements(double? heightCm, double? weightKg) {
    if (_units == Units.imperial) {
      if (heightCm != null) {
        final (ft, inch) = cmToFtIn(heightCm);
        _feet.text = '$ft';
        _inches.text = '$inch';
      } else {
        _feet.clear();
        _inches.clear();
      }
      _weight.text = weightKg == null ? '' : trimNumber(kgToLb(weightKg));
    } else {
      _cm.text = heightCm == null ? '' : '${heightCm.round()}';
      _weight.text = weightKg == null ? '' : trimNumber(weightKg);
    }
  }

  void _switchUnits(Units newUnits) {
    if (newUnits == _units) return;
    final h = _currentHeightCm();
    final w = _currentWeightKg();
    setState(() => _units = newUnits);
    _fillMeasurements(h, w);
  }

  // ---- Actions ----

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final latest = DateTime(now.year - 13, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30, 1, 1),
      firstDate: DateTime(1920),
      lastDate: latest,
      helpText: 'Birthday',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final heightCm = _currentHeightCm();
    final weightKg = _currentWeightKg();

    String? problem;
    if (name.isEmpty) {
      problem = 'Please enter a name.';
    } else if (_birthDate == null) {
      problem = 'Please pick a birthday.';
    } else if (heightCm == null || heightCm < 100 || heightCm > 250) {
      problem = 'Please enter a valid height.';
    } else if (weightKg == null || weightKg < 30 || weightKg > 300) {
      problem = 'Please enter a valid weight.';
    }
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    await ProfileRepository.instance.update(UserProfile(
      name: name,
      sex: _sex,
      birthDate: _birthDate,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: _activity,
      goal: _goal,
      units: _units,
      updatedAt: DateTime.now(),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  // ---- UI ----

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  InputDecoration _box(String label, {String? suffix}) => InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final imperial = _units == Units.imperial;
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _section('Name'),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: _box('Name'),
            ),

            _section('Units'),
            SegmentedButton<Units>(
              segments: [
                for (final u in Units.values)
                  ButtonSegment(value: u, label: Text(u.label)),
              ],
              selected: {_units},
              onSelectionChanged: (s) => _switchUnits(s.first),
            ),

            _section('About you'),
            SegmentedButton<Sex>(
              segments: [
                for (final s in Sex.values)
                  ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickBirthDate,
              icon: const Icon(Icons.cake_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  _birthDate == null
                      ? 'Pick birthday'
                      : 'Birthday: ${_birthDate!.month}/${_birthDate!.day}/${_birthDate!.year}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (imperial)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _feet,
                      onChanged: (_) => _exactHeightCm = null,
                      keyboardType: TextInputType.number,
                      decoration: _box('Height', suffix: 'ft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _inches,
                      onChanged: (_) => _exactHeightCm = null,
                      keyboardType: TextInputType.number,
                      decoration: _box('', suffix: 'in'),
                    ),
                  ),
                ],
              )
            else
              TextField(
                controller: _cm,
                onChanged: (_) => _exactHeightCm = null,
                keyboardType: numberKeyboard,
                decoration: _box('Height', suffix: 'cm'),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _weight,
              onChanged: (_) => _exactWeightKg = null,
              keyboardType: numberKeyboard,
              decoration:
                  _box('Current weight', suffix: imperial ? 'lbs' : 'kg'),
            ),

            _section('Activity level'),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final a in ActivityLevel.values)
                    ListTile(
                      title: Text(a.label),
                      subtitle: Text(a.description),
                      selected: a == _activity,
                      trailing: a == _activity
                          ? const Icon(Icons.check_circle)
                          : const Icon(Icons.circle_outlined),
                      onTap: () => setState(() => _activity = a),
                    ),
                ],
              ),
            ),

            _section('Goal'),
            SegmentedButton<Goal>(
              showSelectedIcon: false,
              segments: [
                for (final g in Goal.values)
                  ButtonSegment(value: g, label: Text(g.label)),
              ],
              selected: {_goal},
              onSelectionChanged: (s) => setState(() => _goal = s.first),
            ),

            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Save profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
