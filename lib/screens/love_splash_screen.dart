import 'dart:async';

import 'package:flutter/material.dart';

/// A little love note shown for 5 seconds every time the app opens.
class LoveSplashScreen extends StatefulWidget {
  const LoveSplashScreen({super.key, required this.next});

  /// The screen to show after the note.
  final Widget next;

  static const Duration showFor = Duration(seconds: 5);

  @override
  State<LoveSplashScreen> createState() => _LoveSplashScreenState();
}

class _LoveSplashScreenState extends State<LoveSplashScreen>
    with TickerProviderStateMixin {
  // Heartbeat: a quick double-pulse, then a rest.
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  late final Animation<double> _heartScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 12),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 12),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 10),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 14),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 52),
  ]).animate(CurvedAnimation(parent: _beat, curve: Curves.easeInOut));

  // The words fade and float in one line after the other.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(LoveSplashScreen.showFor, _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, __, ___) => widget.next,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _beat.dispose();
    _intro.dispose();
    super.dispose();
  }

  Widget _line(String text, TextStyle? style, double start, double end) {
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.4), end: Offset.zero)
            .animate(anim),
        child: Text(text, textAlign: TextAlign.center, style: style),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB3CC), Color(0xFFE85D8E), Color(0xFFB83B6B)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _heartScale,
                  child: const Icon(
                    Icons.favorite,
                    size: 110,
                    color: Colors.white,
                    shadows: [
                      Shadow(blurRadius: 24, color: Color(0x66000000)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                _line(
                  'My babydoll.',
                  text.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  0.0,
                  0.55,
                ),
                const SizedBox(height: 12),
                _line(
                  'My eternal chem queen <3',
                  text.titleLarge?.copyWith(
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                  0.35,
                  1.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
