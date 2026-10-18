import 'package:flutter_test/flutter_test.dart';

import 'package:syds_health_fitness/data/exercise_library.dart';
import 'package:syds_health_fitness/data/exercise_photos.dart';

void main() {
  test('photos point at the free-exercise-db start and end images', () {
    expect(
      ExercisePhotos.url('goblet_squat', 1),
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/'
      'exercises/Goblet_Squat/1.jpg',
    );
    expect(ExercisePhotos.url('not_a_real_exercise'), isNull);
  });

  test('most exercises have a photo', () {
    final withPhoto =
        ExerciseLibrary.all.keys.where(ExercisePhotos.has).length;
    expect(withPhoto / ExerciseLibrary.all.length, greaterThan(0.85));
  });
}
