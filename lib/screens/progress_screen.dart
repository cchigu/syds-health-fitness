import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../models/weigh_in.dart';
import '../services/profile_repository.dart';
import '../services/weight_repository.dart';
import '../utils/dates.dart';
import '../utils/units.dart';
import '../widgets/weight_chart.dart';

enum _Range { month, threeMonths, sixMonths, year, all }

extension on _Range {
  String get label => switch (this) {
        _Range.month => '1M',
        _Range.threeMonths => '3M',
        _Range.sixMonths => '6M',
        _Range.year => '1Y',
        _Range.all => 'All',
      };
  int? get days => switch (this) {
        _Range.month => 30,
        _Range.threeMonths => 91,
        _Range.sixMonths => 182,
        _Range.year => 365,
        _Range.all => null,
      };
}

/// Progress tab: current weight, trend, chart, goal and weigh-in history.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  _Range _range = _Range.month;

  WeightRepository get _weights => WeightRepository.instance;
  ProfileRepository get _profile => ProfileRepository.instance;

  Units get _units => _profile.profile.units;
  String get _unit => _units == Units.imperial ? 'lbs' : 'kg';
  double _show(double kg) => _units == Units.imperial ? kgToLb(kg) : kg;
  double _toKg(double v) => _units == Units.imperial ? lbToKg(v) : v;

  // ------------------------------------------------------------- dialogs

  Future<void> _logWeight({WeighIn? existing}) async {
    final start = existing?.kg ??
        _weights.latest?.kg ??
        _profile.profile.weightKg;
    final controller = TextEditingController(
        text: start == null ? '' : trimNumber(_show(start)));
    var day = existing?.day ?? dayOnly(DateTime.now());

    final result = await showDialog<(DateTime, double)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Log weight' : 'Edit weigh-in'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  suffixText: _unit,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(friendlyDay(day)),
                onPressed: existing != null
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: day,
                          firstDate: DateTime(2020),
                          lastDate: dayOnly(DateTime.now()),
                        );
                        if (picked != null) setLocal(() => day = picked);
                      },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(
                    controller.text.trim().replaceAll(',', '.'));
                if (v == null) return;
                Navigator.pop(ctx, (day, _toKg(v)));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final (d, kg) = result;
    if (kg < 30 || kg > 300) {
      _snack('That weight doesn\'t look right.');
      return;
    }
    await _weights.log(d, kg);
  }

  Future<void> _setGoalWeight() async {
    final current = _profile.profile.goalWeightKg;
    final controller = TextEditingController(
        text: current == null ? '' : trimNumber(_show(current)));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Goal weight'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: _unit,
            border: const OutlineInputBorder(),
            helperText: 'Shown as a dashed line on the chart',
          ),
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'clear'),
              child: const Text('Remove goal'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (result == 'clear') {
      await _profile.update(_profile.profile.copyWith(goalWeightKg: null));
      return;
    }
    final v = double.tryParse(result.trim().replaceAll(',', '.'));
    if (v == null) return;
    final kg = _toKg(v);
    if (kg < 30 || kg > 300) {
      _snack('That weight doesn\'t look right.');
      return;
    }
    await _profile.update(_profile.profile.copyWith(goalWeightKg: kg));
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _fmtChange(double kg) {
    final v = _show(kg);
    if (v.abs() < 0.05) return '±0 $_unit';
    return '${v > 0 ? '+' : '−'}${trimNumber(v.abs())} $_unit';
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_weights, _profile]),
      builder: (context, _) {
        final entries = _weights.entries;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Progress'),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Goal weight',
                icon: const Icon(Icons.flag_outlined),
                onPressed: _setGoalWeight,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _logWeight,
            icon: const Icon(Icons.monitor_weight_outlined),
            label: const Text('Log weight'),
          ),
          body: entries.isEmpty ? _empty() : _content(entries),
        );
      },
    );
  }

  Widget _empty() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 72, color: colors.primary),
            const SizedBox(height: 16),
            const Text(
              'Log your first weigh-in to start your progress chart.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tip: weigh in first thing in the morning for the most '
              'consistent numbers.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(List<WeighIn> entries) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final trend = _weights.trend;
    final latest = entries.last;
    final trendNow = trend.last.kg;
    final week = _weights.trendChange(7);
    final month = _weights.trendChange(30);
    final total = trendNow - trend.first.kg;
    final goal = _profile.profile.goalWeightKg;

    final today = dayOnly(DateTime.now());
    final days = _range.days;
    final start = days == null
        ? entries.first.day
        : today.subtract(Duration(days: days));

    Widget stat(String label, String value) => Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: text.titleMedium),
              ),
              Text(label, style: text.bodySmall),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
      children: [
        // Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '${trimNumber(_show(latest.kg))} $_unit',
                  style: text.displaySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text('Current weight · ${friendlyDay(latest.day)}',
                    style: text.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  'Trend ${trimNumber(_show(trendNow))} $_unit',
                  style: text.bodySmall?.copyWith(color: colors.outline),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    stat('7 days', week == null ? '—' : _fmtChange(week)),
                    stat('30 days', month == null ? '—' : _fmtChange(month)),
                    stat('Total', _fmtChange(total)),
                    if (goal != null)
                      stat('To goal', _fmtChange(goal - trendNow)),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: SegmentedButton<_Range>(
                    showSelectedIcon: false,
                    segments: [
                      for (final r in _Range.values)
                        ButtonSegment(value: r, label: Text(r.label)),
                    ],
                    selected: {_range},
                    onSelectionChanged: (s) =>
                        setState(() => _range = s.first),
                  ),
                ),
                const SizedBox(height: 8),
                WeightChart(
                  weighIns: entries,
                  trend: trend,
                  start: start,
                  end: today,
                  units: _units,
                  goalKg: goal,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Text(
                    'Dots are weigh-ins; the line is your trend, which '
                    'smooths out day-to-day water changes.',
                    style: text.bodySmall?.copyWith(color: colors.outline),
                  ),
                ),
              ],
            ),
          ),
        ),

        // History
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Text('Weigh-ins', style: text.titleMedium),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = entries.length - 1; i >= 0; i--)
                Dismissible(
                  key: ValueKey(entries[i].id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: colors.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete_outline,
                        color: colors.onErrorContainer),
                  ),
                  onDismissed: (_) {
                    final w = entries[i];
                    _weights.remove(w);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: const Text('Weigh-in removed'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () => _weights.log(w.day, w.kg),
                        ),
                      ));
                  },
                  child: ListTile(
                    onTap: () => _logWeight(existing: entries[i]),
                    title: Text('${trimNumber(_show(entries[i].kg))} $_unit'),
                    subtitle: Text(friendlyDay(entries[i].day)),
                    trailing: i == 0
                        ? null
                        : Text(
                            _fmtChange(entries[i].kg - entries[i - 1].kg),
                            style: text.bodySmall,
                          ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
