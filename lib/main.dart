import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/custom_food_repository.dart';
import 'services/exercise_log_repository.dart';
import 'services/food_log_repository.dart';
import 'services/profile_repository.dart';
import 'services/saved_meals.dart';
import 'services/weight_repository.dart';
import 'services/workout_repository.dart';
import 'screens/love_splash_screen.dart';
import 'screens/today_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/workouts_screen.dart';
import 'screens/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ProfileRepository.instance.init();
  await FoodLogRepository.instance.init();
  await CustomFoodRepository.instance.init();
  await FavoritesRepository.instance.init();
  await RecipeRepository.instance.init();
  await WeightRepository.instance.init();
  await WorkoutPrefsRepository.instance.init();
  await WorkoutLogRepository.instance.init();
  await WorkoutScheduleRepository.instance.init();
  await ExerciseLogRepository.instance.init();
  runApp(const SydsHealthApp());
}

class SydsHealthApp extends StatelessWidget {
  const SydsHealthApp({super.key});

  static const Color brandPink = Color(0xFFE85D8E);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Syd's Health & Fitness <3",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: brandPink),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandPink,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const LoveSplashScreen(next: HomeShell()),
    );
  }
}

/// Holds the bottom tab bar and swaps between the four main pages.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  // IndexedStack keeps each tab's state when switching between tabs.
  final List<Widget> _pages = const [
    TodayScreen(),
    ProgressScreen(),
    WorkoutsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Workouts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
