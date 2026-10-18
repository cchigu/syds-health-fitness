/// The real-life data used to work out Syd's actual maintenance calories.
///
/// Empty for now: the food log (Milestone 4) fills in [caloriesByDay] and the
/// weight log (Milestone 7) fills in [weights].
class EnergyHistory {
  const EnergyHistory({
    this.caloriesByDay = const {},
    this.weights = const [],
  });

  static const EnergyHistory empty = EnergyHistory();

  /// Total calories logged per day. Keys are dates at midnight.
  final Map<DateTime, double> caloriesByDay;

  final List<WeightEntry> weights;
}

class WeightEntry {
  const WeightEntry(this.date, this.kg);
  final DateTime date;
  final double kg;
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
