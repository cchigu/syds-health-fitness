import 'package:flutter/material.dart';

import '../services/exercise_log_repository.dart';
import '../services/profile_repository.dart';
import '../services/workout_planner.dart';
import '../services/workout_repository.dart';
import '../widgets/exercise_photo.dart';
import '../widgets/exercise_stats.dart';

/// Every exercise she has logged: last session, best session and records.
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ExerciseLogRepository.instance;
    final units = ProfileRepository.instance.profile.units;
    final prefs = WorkoutPrefsRepository.instance.prefs;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My records')),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final ids = repo.loggedExercises.toList();
          String nameOf(String id) {
            if (prefs == null) return id;
            return WorkoutPlanner.exerciseById(prefs, id)?.name ?? id;
          }

          ids.sort((a, b) => nameOf(a).compareTo(nameOf(b)));
          if (ids.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        size: 64, color: colors.primary),
                    const SizedBox(height: 12),
                    const Text(
                      'No records yet.\nIn a workout, tap an exercise and '
                      '"Log my sets" to start tracking.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              for (final id in ids)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ExerciseThumb(exerciseId: id, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(nameOf(id),
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ExerciseStatsCard(exerciseId: id, units: units),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

