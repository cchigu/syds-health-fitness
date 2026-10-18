import 'package:flutter/material.dart';

/// − [ 40 min ] +   in 5-minute steps (10 to 90 by default).
class MinutesStepper extends StatelessWidget {
  const MinutesStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 10,
    this.max = 90,
    this.step = 5,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: '$step minutes less',
          onPressed: value - step < min ? null : () => onChanged(value - step),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 84,
          child: Text(
            '$value min',
            textAlign: TextAlign.center,
            style: text.titleMedium,
          ),
        ),
        IconButton.filledTonal(
          tooltip: '$step minutes more',
          onPressed: value + step > max ? null : () => onChanged(value + step),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
