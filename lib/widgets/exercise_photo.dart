import 'package:flutter/material.dart';

import '../data/exercise_photos.dart';

/// Start and end photos of an exercise side by side, or nothing if there's
/// no photo for it. Shows a spinner while loading and a quiet placeholder if
/// a photo can't be loaded (e.g. offline).
class ExercisePhotoPair extends StatelessWidget {
  const ExercisePhotoPair({
    super.key,
    required this.exerciseId,
    this.height = 160,
  });

  final String exerciseId;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!ExercisePhotos.has(exerciseId)) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (i, label) in const [(0, 'Start'), (1, 'End')]) ...[
              if (i == 1) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    _Photo(
                      url: ExercisePhotos.url(exerciseId, i)!,
                      height: height,
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: text.labelSmall),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// A small square thumbnail (the start position) for lists.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({super.key, required this.exerciseId, this.size = 44});

  final String exerciseId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = ExercisePhotos.url(exerciseId);
    if (url == null) return SizedBox(width: size, height: size);
    return _Photo(url: url, height: size, width: size, radius: 8);
  }
}

class _Photo extends StatelessWidget {
  const _Photo({
    required this.url,
    required this.height,
    this.width,
    this.radius = 12,
  });

  final String url;
  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: height,
        width: width ?? double.infinity,
        color: Colors.white,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
          errorBuilder: (context, error, stack) => Container(
            color: colors.surfaceContainerHighest,
            child: Icon(Icons.image_not_supported_outlined,
                color: colors.outline, size: height > 60 ? 28 : 18),
          ),
        ),
      ),
    );
  }
}
