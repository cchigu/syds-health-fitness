import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

/// Confetti and a "You the real goat 🐐" card, shown when a weigh-in
/// reaches her goal weight.
Future<void> showGoatCelebration(BuildContext context) => showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const _GoatCelebration(),
      transitionBuilder: (_, animation, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );

class _GoatCelebration extends StatefulWidget {
  const _GoatCelebration();

  @override
  State<_GoatCelebration> createState() => _GoatCelebrationState();
}

class _GoatCelebrationState extends State<_GoatCelebration> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    const confettiColors = [
      Color(0xFFE85D8E),
      Color(0xFFFFB3CC),
      Color(0xFFF2A541),
      Color(0xFF7B6CF6),
      Color(0xFF3FB58A),
      Colors.white,
    ];

    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: Material(
            color: colors.surface,
            elevation: 12,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🐐', style: TextStyle(fontSize: 88)),
                  const SizedBox(height: 8),
                  Text(
                    'You the real goat',
                    textAlign: TextAlign.center,
                    style: text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('You hit your goal weight!', style: text.bodyLarge),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Heck yes'),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Two cannons from the top corners plus a burst from the middle.
        Align(
          alignment: Alignment.topLeft,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirection: pi / 4,
            emissionFrequency: 0.08,
            numberOfParticles: 18,
            maxBlastForce: 40,
            minBlastForce: 15,
            gravity: 0.25,
            colors: confettiColors,
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirection: 3 * pi / 4,
            emissionFrequency: 0.08,
            numberOfParticles: 18,
            maxBlastForce: 40,
            minBlastForce: 15,
            gravity: 0.25,
            colors: confettiColors,
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            gravity: 0.3,
            colors: confettiColors,
          ),
        ),
      ],
    );
  }
}
