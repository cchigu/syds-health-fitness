import '../models/workout.dart';

/// Every exercise the planner can use. Equipment is limited to what Syd has
/// at home: dumbbells up to 25 lb, a treadmill, and the floor.
///
/// [Exercise.stresses] lists the areas an exercise puts real load on; if she
/// asks to go easy on one, those exercises are left out.
class ExerciseLibrary {
  ExerciseLibrary._();

  static Exercise byId(String id) => all[id]!;

  static const Map<String, Exercise> all = {
    // ------------------------------------------------------------ warm-up
    'warmup_walk': Exercise(
      id: 'warmup_walk',
      name: 'Treadmill warm-up walk',
      kind: ExerciseKind.warmup,
      equipment: 'Treadmill',
      steps: [
        'Walk at an easy pace, about 2.5–3.0 mph, flat.',
        'For the last minute, pick it up to a brisk walk.',
      ],
      tip: 'You should be able to talk easily.',
    ),
    'arm_circles_leg_swings': Exercise(
      id: 'arm_circles_leg_swings',
      name: 'Arm circles & leg swings',
      kind: ExerciseKind.warmup,
      steps: [
        'Make 10 small arm circles forward, then 10 backward, slowly '
            'getting bigger.',
        'Holding a wall for balance, swing one leg forward and back 10 '
            'times, then side to side 10 times. Switch legs.',
      ],
    ),

    // ----------------------------------------------------------- lower body
    'goblet_squat': Exercise(
      id: 'goblet_squat',
      name: 'Goblet squat',
      kind: ExerciseKind.strength,
      equipment: '1 dumbbell',
      stresses: {BodyArea.knees},
      weightLb: (10, 25),
      steps: [
        'Hold one dumbbell upright against your chest with both hands.',
        'Feet a little wider than hips, toes slightly out.',
        'Sit your hips back and down until your thighs are about parallel, '
            'chest tall.',
        'Push through your whole foot to stand back up.',
      ],
      tip: 'Knees follow the direction of your toes.',
    ),
    'sumo_squat': Exercise(
      id: 'sumo_squat',
      name: 'Sumo squat',
      kind: ExerciseKind.strength,
      equipment: '1 dumbbell',
      stresses: {BodyArea.knees, BodyArea.hips},
      weightLb: (15, 25),
      steps: [
        'Stand with feet wide and toes turned out, holding one dumbbell by '
            'the end so it hangs between your legs.',
        'Bend your knees and lower straight down, keeping your back tall.',
        'Squeeze your glutes to stand up.',
      ],
    ),
    'reverse_lunge': Exercise(
      id: 'reverse_lunge',
      name: 'Reverse lunge',
      kind: ExerciseKind.strength,
      equipment: '2 dumbbells',
      stresses: {BodyArea.knees, BodyArea.hips, BodyArea.ankles},
      weightLb: (5, 20),
      perSide: true,
      steps: [
        'Stand holding a dumbbell in each hand at your sides.',
        'Step one foot back and lower until both knees are bent about 90°.',
        'Push through the front heel to return. Do all reps, then switch.',
      ],
      tip: 'Stepping back is easier on the knees than stepping forward.',
    ),
    'db_rdl': Exercise(
      id: 'db_rdl',
      name: 'Romanian deadlift',
      kind: ExerciseKind.strength,
      equipment: '2 dumbbells',
      stresses: {BodyArea.lowerBack},
      weightLb: (10, 25),
      steps: [
        'Stand holding a dumbbell in each hand in front of your thighs.',
        'With a slight bend in your knees, push your hips back and slide the '
            'weights down your legs.',
        'Stop when you feel a stretch in your hamstrings (around mid-shin), '
            'back flat.',
        'Squeeze your glutes to stand back up.',
      ],
      tip: 'Think "hips back", not "bend over".',
    ),
    'glute_bridge': Exercise(
      id: 'glute_bridge',
      name: 'Dumbbell glute bridge',
      stresses: {BodyArea.tailbone},
      kind: ExerciseKind.strength,
      equipment: '1 dumbbell',
      weightLb: (10, 25),
      steps: [
        'Lie on your back, knees bent, feet flat. Rest a dumbbell across your '
            'hips and hold it in place.',
        'Squeeze your glutes and lift your hips until your body makes a '
            'straight line from shoulders to knees.',
        'Pause for a second, then lower slowly.',
      ],
    ),
    'single_leg_bridge': Exercise(
      id: 'single_leg_bridge',
      name: 'Single-leg glute bridge',
      stresses: {BodyArea.tailbone},
      kind: ExerciseKind.strength,
      perSide: true,
      steps: [
        'Lie on your back, knees bent, feet flat. Lift one foot off the floor.',
        'Push through the planted heel to lift your hips.',
        'Lower slowly. Do all reps, then switch legs.',
      ],
    ),
    'side_leg_raise': Exercise(
      id: 'side_leg_raise',
      name: 'Side-lying leg raise',
      kind: ExerciseKind.strength,
      perSide: true,
      steps: [
        'Lie on your side with legs straight, head resting on your arm.',
        'Lift the top leg about 45°, toes pointing forward.',
        'Lower slowly. Do all reps, then switch sides.',
      ],
      tip: 'Hold a light dumbbell on your outer thigh to make it harder.',
    ),
    'calf_raise': Exercise(
      id: 'calf_raise',
      name: 'Calf raise',
      kind: ExerciseKind.strength,
      equipment: '2 dumbbells',
      stresses: {BodyArea.ankles},
      weightLb: (10, 25),
      steps: [
        'Stand holding dumbbells at your sides (hold a wall with one hand if '
            'needed).',
        'Rise up onto the balls of your feet as high as you can.',
        'Pause, then lower slowly.',
      ],
    ),

    // ------------------------------------------------------------ upper push
    'floor_press': Exercise(
      id: 'floor_press',
      name: 'Dumbbell floor press',
      kind: ExerciseKind.strength,
      equipment: '2 dumbbells',
      stresses: {BodyArea.shoulders, BodyArea.wrists, BodyArea.tailbone},
      weightLb: (10, 25),
      steps: [
        'Lie on your back, knees bent, a dumbbell in each hand, elbows on the '
            'floor at about 45° from your body.',
        'Press the weights straight up over your chest.',
        'Lower until your upper arms lightly touch the floor.',
      ],
      tip: 'The floor stops your elbows, which keeps shoulders safe.',
    ),
    'incline_pushup': Exercise(
      id: 'incline_pushup',
      name: 'Incline push-up',
      kind: ExerciseKind.strength,
      stresses: {BodyArea.wrists, BodyArea.shoulders},
      steps: [
        'Put your hands on the edge of a sturdy couch, table or counter, a '
            'little wider than your shoulders.',
        'Walk your feet back so your body is a straight line.',
        'Lower your chest toward the edge, then push back up.',
      ],
      tip: 'The higher the surface, the easier it is.',
    ),
    'shoulder_press': Exercise(
      id: 'shoulder_press',
      name: 'Seated shoulder press',
      kind: ExerciseKind.strength,
      equipment: '2 dumbbells',
      stresses: {BodyArea.shoulders, BodyArea.neck},
      weightLb: (5, 20),
      steps: [
        'Sit tall on a chair holding dumbbells at shoulder height, palms '
            'facing forward.',
        'Press the weights up until your arms are straight.',
        'Lower back to shoulder height.',
      ],
    ),
    'lateral_raise': Exercise(
      id: 'lateral_raise',
      name: 'Lateral raise',
      kind: ExerciseKind.strength,
      equipment: '2 dumbbells',
      stresses: {BodyArea.shoulders},
      weightLb: (5, 12),
      steps: [
        'Stand holding light dumbbells at your sides.',
        'With a slight bend in the elbows, raise your arms out to the sides '
            'to shoulder height.',
        'Lower slowly.',
      ],
      tip: 'Go light — this one is harder than it looks.',
    ),
    'tricep_kickback': Exercise(
      id: 'tricep_kickback',
      name: 'Triceps kickback',
      kind: ExerciseKind.strength,
      equipment: '1–2 dumbbells',
      weightLb: (5, 15),
      steps: [
        'Hinge forward slightly (or rest one hand on a chair), upper arms '
            'tight to your sides, elbows bent.',
        'Straighten your arms back behind you.',
        'Bend back to the start without moving your upper arms.',
      ],
    ),

    // ------------------------------------------------------------ upper pull
    'one_arm_row': Exercise(
      id: 'one_arm_row',
      name: 'One-arm dumbbell row',
      kind: ExerciseKind.strength,
      equipment: '1 dumbbell',
      weightLb: (10, 25),
      perSide: true,
      steps: [
        'Put one hand and knee on a sturdy chair or couch, back flat.',
        'Hold a dumbbell in the other hand, arm hanging straight down.',
        'Pull the weight toward your hip, elbow close to your body.',
        'Lower slowly. Do all reps, then switch.',
      ],
      tip: 'Supporting yourself on the chair protects your lower back.',
    ),
    'bent_over_row': Exercise(
      id: 'bent_over_row',
      name: 'Bent-over row',
      kind: ExerciseKind.strength,
      equipment: '2 dumbbells',
      stresses: {BodyArea.lowerBack},
      weightLb: (10, 25),
      steps: [
        'Hold a dumbbell in each hand and hinge forward about 45°, back flat.',
        'Pull both weights toward your ribs, squeezing your shoulder blades.',
        'Lower slowly.',
      ],
    ),
    'reverse_fly': Exercise(
      id: 'reverse_fly',
      name: 'Seated reverse fly',
      kind: ExerciseKind.strength,
      equipment: '2 dumbbells',
      weightLb: (5, 10),
      steps: [
        'Sit on the edge of a chair and lean forward, chest toward your knees, '
            'light dumbbells hanging by your feet.',
        'With soft elbows, raise your arms out to the sides.',
        'Squeeze your shoulder blades, then lower slowly.',
      ],
    ),
    'bicep_curl': Exercise(
      id: 'bicep_curl',
      name: 'Biceps curl',
      kind: ExerciseKind.strength,
      equipment: '2 dumbbells',
      weightLb: (8, 20),
      steps: [
        'Stand holding dumbbells at your sides, palms facing forward.',
        'Curl the weights up toward your shoulders, elbows still.',
        'Lower slowly.',
      ],
    ),
    'hammer_curl': Exercise(
      id: 'hammer_curl',
      name: 'Hammer curl',
      kind: ExerciseKind.strength,
      equipment: '2 dumbbells',
      weightLb: (8, 20),
      steps: [
        'Stand holding dumbbells at your sides, palms facing in.',
        'Curl the weights up, keeping palms facing each other.',
        'Lower slowly.',
      ],
    ),

    // ----------------------------------------------------------- full body
    'squat_press': Exercise(
      id: 'squat_press',
      name: 'Squat to press',
      kind: ExerciseKind.strength,
      equipment: '2 dumbbells',
      stresses: {BodyArea.knees, BodyArea.shoulders},
      weightLb: (5, 15),
      steps: [
        'Hold dumbbells at your shoulders.',
        'Squat down, then as you stand, press the weights overhead in one '
            'smooth motion.',
        'Lower to your shoulders and go straight into the next squat.',
      ],
      tip: 'Great for getting your heart rate up.',
    ),

    // ----------------------------------------------------------------- core
    'dead_bug': Exercise(
      id: 'dead_bug',
      name: 'Dead bug',
      stresses: {BodyArea.tailbone},
      kind: ExerciseKind.core,
      perSide: true,
      steps: [
        'Lie on your back, arms pointing up, knees bent at 90° over your hips.',
        'Press your lower back into the floor.',
        'Slowly lower one arm overhead and the opposite leg toward the floor.',
        'Return and switch sides.',
      ],
      tip: 'Back-friendly — keep your lower back flat the whole time.',
    ),
    'forearm_plank': Exercise(
      id: 'forearm_plank',
      name: 'Forearm plank',
      kind: ExerciseKind.core,
      timeBased: true,
      stresses: {BodyArea.shoulders},
      steps: [
        'Rest on your forearms and toes (or knees to make it easier), elbows '
            'under shoulders.',
        'Keep a straight line from head to heels; squeeze glutes and belly.',
        'Breathe and hold.',
      ],
    ),
    'bird_dog': Exercise(
      id: 'bird_dog',
      name: 'Bird dog',
      kind: ExerciseKind.core,
      perSide: true,
      stresses: {BodyArea.wrists, BodyArea.knees},
      steps: [
        'Start on hands and knees.',
        'Reach one arm forward and the opposite leg back until both are level '
            'with your body.',
        'Pause, return, and switch sides.',
      ],
    ),
    'russian_twist': Exercise(
      id: 'russian_twist',
      name: 'Russian twist',
      kind: ExerciseKind.core,
      equipment: '1 dumbbell',
      stresses: {BodyArea.lowerBack, BodyArea.tailbone},
      weightLb: (5, 15),
      steps: [
        'Sit with knees bent and lean back slightly, holding a dumbbell at '
            'your chest.',
        'Rotate your chest to one side, then the other. That\'s one rep.',
      ],
    ),
    'side_plank': Exercise(
      id: 'side_plank',
      name: 'Side plank',
      kind: ExerciseKind.core,
      timeBased: true,
      perSide: true,
      stresses: {BodyArea.shoulders},
      steps: [
        'Lie on your side and prop yourself on one forearm, elbow under '
            'shoulder.',
        'Lift your hips so your body is a straight line (knees down to make '
            'it easier).',
        'Hold, then switch sides.',
      ],
    ),
    'heel_taps': Exercise(
      id: 'heel_taps',
      name: 'Lying heel taps',
      stresses: {BodyArea.tailbone},
      kind: ExerciseKind.core,
      perSide: true,
      steps: [
        'Lie on your back, knees bent at 90° over your hips, lower back '
            'pressed down.',
        'Slowly lower one heel to tap the floor, then bring it back.',
        'Alternate sides.',
      ],
    ),
    'crunch': Exercise(
      id: 'crunch',
      name: 'Crunch',
      kind: ExerciseKind.core,
      stresses: {BodyArea.neck, BodyArea.tailbone},
      steps: [
        'Lie on your back, knees bent, fingertips lightly behind your ears.',
        'Curl your shoulders off the floor using your abs.',
        'Lower slowly.',
      ],
      tip: 'Don\'t pull on your head.',
    ),

    // ------------------------------------- tailbone-friendly alternatives
    // Standing, kneeling, couch or chair versions of floor exercises, so
    // nothing presses on the tailbone.
    'hip_thrust_couch': Exercise(
      id: 'hip_thrust_couch',
      name: 'Couch hip thrust',
      kind: ExerciseKind.strength,
      equipment: '1 dumbbell + couch',
      weightLb: (10, 25),
      steps: [
        'Sit on the front edge of the couch, feet flat and wide. Slide '
            'your hips forward off the seat until only your upper back '
            '(shoulder blades) rests on it — your bottom never touches '
            'the floor.',
        'Hold a dumbbell on your hips.',
        'Push through your heels and squeeze your glutes to lift your hips '
            'until your body is flat from shoulders to knees.',
        'Lower until your hips are just above the floor, then lift again.',
      ],
      tip: 'Same glute work as a bridge without lying on the floor.',
    ),
    'standing_kickback': Exercise(
      id: 'standing_kickback',
      name: 'Standing glute kickback',
      kind: ExerciseKind.strength,
      perSide: true,
      steps: [
        'Stand holding a counter or chair back, leaning forward slightly.',
        'Keeping your leg straight, push one heel back and up, squeezing '
            'the glute.',
        'Lower with control. Do all reps, then switch legs.',
      ],
      tip: 'Hold a light dumbbell behind your knee to make it harder.',
    ),
    'single_leg_rdl': Exercise(
      id: 'single_leg_rdl',
      name: 'Single-leg Romanian deadlift',
      kind: ExerciseKind.strength,
      equipment: '1 dumbbell',
      stresses: {BodyArea.ankles},
      weightLb: (5, 20),
      perSide: true,
      steps: [
        'Stand on one leg holding a dumbbell in the opposite hand (touch a '
            'wall with your free hand for balance).',
        'Hinge at the hip, reaching the weight toward the floor as your free '
            'leg goes straight back.',
        'Stop at a hamstring stretch, then squeeze back up. Switch sides.',
      ],
    ),
    'standing_crunch': Exercise(
      id: 'standing_crunch',
      name: 'Standing knee-to-elbow crunch',
      kind: ExerciseKind.core,
      perSide: true,
      steps: [
        'Stand tall with fingertips behind your ears.',
        'Lift one knee across your body while bringing the opposite elbow '
            'down to meet it, crunching your abs.',
        'Return and switch sides.',
      ],
      tip: 'Go slow and really squeeze — speed makes it easier.',
    ),
    'db_side_bend': Exercise(
      id: 'db_side_bend',
      name: 'Standing side bend',
      kind: ExerciseKind.core,
      equipment: '1 dumbbell',
      perSide: true,
      weightLb: (10, 25),
      steps: [
        'Stand tall holding a dumbbell in one hand at your side.',
        'Slowly bend sideways toward the weight, then use your opposite '
            'side to pull yourself back up straight.',
        'Do all reps, then switch hands.',
      ],
    ),
    'db_woodchop': Exercise(
      id: 'db_woodchop',
      name: 'Standing dumbbell woodchop',
      kind: ExerciseKind.core,
      equipment: '1 dumbbell',
      stresses: {BodyArea.lowerBack},
      weightLb: (5, 12),
      perSide: true,
      steps: [
        'Hold one dumbbell with both hands by your outside hip, knees soft.',
        'Rotate and lift it diagonally across your body to above the '
            'opposite shoulder.',
        'Lower back along the same path. Do all reps, then switch sides.',
      ],
    ),
    'squeeze_press': Exercise(
      id: 'squeeze_press',
      name: 'Standing squeeze press',
      kind: ExerciseKind.strength,
      equipment: '1 dumbbell',
      stresses: {BodyArea.shoulders},
      weightLb: (5, 15),
      steps: [
        'Stand tall and squeeze one dumbbell between your palms at chest '
            'height.',
        'Keep squeezing hard as you press it straight out in front of you.',
        'Bring it back to your chest. Your chest does the work.',
      ],
    ),
    'standing_hamstring_stretch': Exercise(
      id: 'standing_hamstring_stretch',
      name: 'Standing hamstring stretch',
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      steps: [
        'Put one heel on a low step or the bottom stair, leg straight.',
        'Keep your back flat and hinge forward from your hips until you '
            'feel a stretch behind the leg.',
      ],
    ),
    'chair_figure_four': Exercise(
      id: 'chair_figure_four',
      name: 'Chair figure-four stretch',
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      stresses: {BodyArea.hips},
      steps: [
        'Sit tall on a cushioned chair and cross one ankle over the opposite '
            'knee.',
        'Keeping your back straight, lean forward gently until you feel it '
            'in the crossed hip.',
      ],
    ),
    'standing_knee_hug': Exercise(
      id: 'standing_knee_hug',
      name: 'Standing knee hug',
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      steps: [
        'Stand near a wall for balance.',
        'Lift one knee and hug it gently toward your chest, standing tall.',
      ],
    ),
    'chair_twist': Exercise(
      id: 'chair_twist',
      name: 'Seated chair twist',
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      steps: [
        'Sit tall on a cushioned chair, feet flat.',
        'Turn your chest to one side, holding the chair back gently, and '
            'breathe. Switch sides.',
      ],
    ),

    // --------------------------------------------------------------- cardio
    'run_intervals': Exercise(
      id: 'run_intervals',
      name: 'Jog intervals',
      kind: ExerciseKind.cardio,
      equipment: 'Treadmill',
      stresses: {BodyArea.knees, BodyArea.ankles, BodyArea.hips},
      steps: [
        'Alternate 1 minute of jogging (about 4.5–5.5 mph) with 2 minutes of '
            'brisk walking (about 3.3 mph).',
        'Finish with 1 minute of easy walking.',
      ],
      tip: 'Jog at a pace where you could still say a short sentence.',
    ),
    'incline_intervals': Exercise(
      id: 'incline_intervals',
      name: 'Incline walk intervals',
      kind: ExerciseKind.cardio,
      equipment: 'Treadmill',
      stresses: {BodyArea.ankles},
      steps: [
        'Walk at about 3.0–3.5 mph.',
        'Alternate 2 minutes at a steep incline (8–12%) with 1 minute flat.',
      ],
      tip: 'Don\'t hold the handrails — let your legs do the work.',
    ),
    'incline_walk': Exercise(
      id: 'incline_walk',
      name: 'Incline walk',
      kind: ExerciseKind.cardio,
      equipment: 'Treadmill',
      stresses: {BodyArea.ankles},
      steps: [
        'Walk at about 2.8–3.5 mph.',
        'Raise the incline to 4–8% (higher as it gets easier) and keep a '
            'steady pace.',
      ],
      tip: 'Burns a lot without the pounding of running.',
    ),
    'walk_intervals': Exercise(
      id: 'walk_intervals',
      name: 'Brisk walk intervals',
      kind: ExerciseKind.cardio,
      equipment: 'Treadmill',
      steps: [
        'Alternate 1 minute fast walking (about 3.5–4.0 mph) with 1 minute '
            'easy walking (about 2.8 mph), flat.',
      ],
    ),
    'steady_walk': Exercise(
      id: 'steady_walk',
      name: 'Steady walk',
      kind: ExerciseKind.cardio,
      equipment: 'Treadmill',
      steps: ['Walk at a comfortable, brisk pace (about 3.0–3.5 mph), flat.'],
    ),

    // -------------------------------------------------------------- stretch
    'hamstring_stretch': Exercise(
      id: 'hamstring_stretch',
      name: 'Hamstring stretch',
      stresses: {BodyArea.tailbone},
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      steps: [
        'Lie on your back and lift one leg, holding behind the thigh (or use '
            'a towel around your foot).',
        'Gently straighten the leg until you feel a stretch behind it.',
      ],
    ),
    'quad_stretch': Exercise(
      id: 'quad_stretch',
      name: 'Standing quad stretch',
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      stresses: {BodyArea.knees},
      steps: [
        'Holding a wall, bend one knee and hold that ankle behind you.',
        'Keep knees together and gently push your hip forward.',
      ],
    ),
    'hip_flexor_stretch': Exercise(
      id: 'hip_flexor_stretch',
      name: 'Kneeling hip flexor stretch',
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      stresses: {BodyArea.knees},
      steps: [
        'Kneel on one knee (on a pillow), other foot in front.',
        'Tuck your hips under and shift forward until you feel a stretch at '
            'the front of the back hip.',
      ],
    ),
    'figure_four': Exercise(
      id: 'figure_four',
      name: 'Figure-four glute stretch',
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      stresses: {BodyArea.hips, BodyArea.tailbone},
      steps: [
        'Lie on your back, knees bent. Cross one ankle over the opposite knee.',
        'Pull the bottom leg toward your chest until you feel it in the '
            'crossed hip.',
      ],
    ),
    'knees_to_chest': Exercise(
      id: 'knees_to_chest',
      name: 'Knees to chest',
      stresses: {BodyArea.tailbone},
      kind: ExerciseKind.stretch,
      timeBased: true,
      steps: [
        'Lie on your back and hug both knees gently toward your chest.',
        'Relax your shoulders and breathe.',
      ],
    ),
    'calf_stretch': Exercise(
      id: 'calf_stretch',
      name: 'Wall calf stretch',
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      stresses: {BodyArea.ankles},
      steps: [
        'Hands on a wall, step one foot back with the heel down.',
        'Lean forward until you feel a stretch in the back calf.',
      ],
    ),
    'childs_pose': Exercise(
      id: 'childs_pose',
      name: 'Child\'s pose',
      kind: ExerciseKind.stretch,
      timeBased: true,
      stresses: {BodyArea.knees},
      steps: [
        'Kneel and sit back on your heels, then walk your hands forward and '
            'rest your forehead down.',
        'Breathe into your back.',
      ],
    ),
    'doorway_chest': Exercise(
      id: 'doorway_chest',
      name: 'Doorway chest stretch',
      kind: ExerciseKind.stretch,
      timeBased: true,
      stresses: {BodyArea.shoulders},
      steps: [
        'Put your forearms on either side of a doorway, elbows at shoulder '
            'height.',
        'Step gently through until you feel a stretch across your chest.',
      ],
    ),
    'cross_body_shoulder': Exercise(
      id: 'cross_body_shoulder',
      name: 'Cross-body shoulder stretch',
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      stresses: {BodyArea.shoulders},
      steps: [
        'Bring one arm across your chest and hold it with the other arm just '
            'above the elbow.',
      ],
    ),
    'triceps_stretch': Exercise(
      id: 'triceps_stretch',
      name: 'Overhead triceps stretch',
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      stresses: {BodyArea.shoulders},
      steps: [
        'Reach one hand down behind your head, and gently press that elbow '
            'with the other hand.',
      ],
    ),
    'seated_side_bend': Exercise(
      id: 'seated_side_bend',
      name: 'Seated side bend',
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      steps: [
        'Sit tall on a chair. Reach one arm overhead and lean gently to the '
            'opposite side.',
      ],
    ),
    'cat_cow': Exercise(
      id: 'cat_cow',
      name: 'Cat-cow',
      kind: ExerciseKind.stretch,
      timeBased: true,
      stresses: {BodyArea.wrists, BodyArea.knees},
      steps: [
        'On hands and knees, slowly round your back up (cat), then let your '
            'belly drop and look up (cow).',
        'Move with your breath.',
      ],
    ),
    'spinal_twist': Exercise(
      id: 'spinal_twist',
      name: 'Lying spinal twist',
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      stresses: {BodyArea.lowerBack, BodyArea.tailbone},
      steps: [
        'Lie on your back, arms out wide. Drop both bent knees gently to one '
            'side and look the other way.',
      ],
    ),
    'neck_stretch': Exercise(
      id: 'neck_stretch',
      name: 'Neck side stretch',
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      stresses: {BodyArea.neck},
      steps: [
        'Sit tall and gently tip your ear toward your shoulder.',
        'Keep the other shoulder relaxed and down.',
      ],
    ),
    'wrist_stretch': Exercise(
      id: 'wrist_stretch',
      name: 'Wrist & forearm stretch',
      kind: ExerciseKind.stretch,
      timeBased: true,
      perSide: true,
      stresses: {BodyArea.wrists},
      steps: [
        'Hold one arm straight out, palm up, and gently pull the fingers down '
            'with the other hand. Then flip the palm down and repeat.',
      ],
    ),
  };
}
