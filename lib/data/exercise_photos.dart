/// Photos for each exercise from the free-exercise-db (public domain,
/// Unlicense) — the same library Beast Reincarnator uses:
/// https://github.com/yuhonas/free-exercise-db
///
/// Each entry has two photos: the start (0) and end (1) position.
/// Exercises without a close match (standing or chair variations made for
/// Syd) simply show no photo.
class ExercisePhotos {
  ExercisePhotos._();

  static const Map<String, String> _libraryId = {
    'warmup_walk': 'Walking_Treadmill',
    'arm_circles_leg_swings': 'Arm_Circles',
    'goblet_squat': 'Goblet_Squat',
    'sumo_squat': 'Plie_Dumbbell_Squat',
    'reverse_lunge': 'Dumbbell_Rear_Lunge',
    'db_rdl': 'Stiff-Legged_Dumbbell_Deadlift',
    'glute_bridge': 'Butt_Lift_Bridge',
    'single_leg_bridge': 'Single_Leg_Glute_Bridge',
    'side_leg_raise': 'Side_Leg_Raises',
    'calf_raise': 'Standing_Dumbbell_Calf_Raise',
    'floor_press': 'Dumbbell_Floor_Press',
    'incline_pushup': 'Incline_Push-Up',
    'shoulder_press': 'Seated_Dumbbell_Press',
    'lateral_raise': 'Side_Lateral_Raise',
    'tricep_kickback': 'Tricep_Dumbbell_Kickback',
    'one_arm_row': 'One-Arm_Dumbbell_Row',
    'bent_over_row': 'Bent_Over_Two-Dumbbell_Row',
    'reverse_fly': 'Reverse_Flyes',
    'bicep_curl': 'Dumbbell_Bicep_Curl',
    'hammer_curl': 'Hammer_Curls',
    'squat_press': 'Kettlebell_Thruster',
    'dead_bug': 'Dead_Bug',
    'forearm_plank': 'Plank',
    'russian_twist': 'Russian_Twist',
    'side_plank': 'Side_Bridge',
    'crunch': 'Crunches',
    'run_intervals': 'Jogging_Treadmill',
    'incline_intervals': 'Walking_Treadmill',
    'incline_walk': 'Walking_Treadmill',
    'walk_intervals': 'Walking_Treadmill',
    'steady_walk': 'Walking_Treadmill',
    'hamstring_stretch': 'Hamstring_Stretch',
    'quad_stretch': 'Standing_Elevated_Quad_Stretch',
    'hip_flexor_stretch': 'Kneeling_Hip_Flexor',
    'figure_four': 'Ankle_On_The_Knee',
    'knees_to_chest': 'Hug_Knees_To_Chest',
    'calf_stretch': 'Calf_Stretch_Hands_Against_Wall',
    'childs_pose': 'Childs_Pose',
    'cross_body_shoulder': 'Shoulder_Stretch',
    'triceps_stretch': 'Triceps_Stretch',
    'seated_side_bend': 'Standing_Lateral_Stretch',
    'cat_cow': 'Cat_Stretch',
    'spinal_twist': 'Knee_Across_The_Body',
    'neck_stretch': 'Side_Neck_Stretch',
    'hip_thrust_couch': 'Barbell_Hip_Thrust',
    'single_leg_rdl': 'Kettlebell_One-Legged_Deadlift',
    'db_side_bend': 'Dumbbell_Side_Bend',
    'db_woodchop': 'Standing_Cable_Wood_Chop',
    'squeeze_press': 'Svend_Press',
    'standing_hamstring_stretch': 'Standing_Hamstring_and_Calf_Stretch',
    'chair_figure_four': 'Seated_Glute',
    'chair_twist': 'Spinal_Stretch',
    'heel_taps': 'Alternate_Heel_Touchers',
    'standing_kickback': 'Glute_Kickback',
    'doorway_chest': 'Dynamic_Chest_Stretch',
    'wrist_stretch': 'Kneeling_Forearm_Stretch',
  };

  static bool has(String exerciseId) => _libraryId.containsKey(exerciseId);

  /// [position] 0 = start, 1 = end.
  static String? url(String exerciseId, [int position = 0]) {
    final id = _libraryId[exerciseId];
    if (id == null) return null;
    return 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/'
        'exercises/$id/$position.jpg';
  }
}
