import '../utils/dates.dart';
import 'food.dart';
import 'meal.dart';
import 'nutrients.dart';

/// One food logged to one meal on one day.
class LogEntry {
  const LogEntry({
    required this.id,
    required this.day,
    required this.meal,
    required this.food,
    required this.serving,
    required this.quantity,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  final String id;

  /// The date it was eaten (midnight).
  final DateTime day;
  final Meal meal;

  /// A copy of the food at the time it was logged, so later database
  /// changes never alter past days.
  final FoodItem food;
  final Serving serving;
  final double quantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Deleted entries are kept (hidden) so deletes sync between devices.
  final bool deleted;

  Nutrients get nutrients => food.nutrientsFor(serving, quantity);

  String get amount => amountLabel(serving, quantity);

  LogEntry copyWith({
    DateTime? day,
    Meal? meal,
    FoodItem? food,
    Serving? serving,
    double? quantity,
    DateTime? updatedAt,
    bool? deleted,
  }) =>
      LogEntry(
        id: id,
        day: day ?? this.day,
        meal: meal ?? this.meal,
        food: food ?? this.food,
        serving: serving ?? this.serving,
        quantity: quantity ?? this.quantity,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'day': dayKey(day),
        'meal': meal.name,
        'food': food.toMap(),
        'serving': serving.toMap(),
        'quantity': quantity,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  static LogEntry? fromMap(Map<String, dynamic> m) {
    final day = parseDayKey(m['day'] as String?);
    final foodRaw = m['food'];
    final servingRaw = m['serving'];
    if (day == null || foodRaw is! Map || servingRaw is! Map) return null;
    DateTime time(Object? v) =>
        DateTime.fromMillisecondsSinceEpoch((v as num?)?.toInt() ?? 0);
    return LogEntry(
      id: (m['id'] as String?) ?? '',
      day: day,
      meal: Meal.values.firstWhere(
        (x) => x.name == m['meal'],
        orElse: () => Meal.snacks,
      ),
      food: FoodItem.fromMap(Map<String, dynamic>.from(foodRaw)),
      serving: Serving.fromMap(Map<String, dynamic>.from(servingRaw)),
      quantity: (m['quantity'] as num?)?.toDouble() ?? 1,
      createdAt: time(m['createdAt']),
      updatedAt: time(m['updatedAt']),
      deleted: m['deleted'] == true,
    );
  }
}
