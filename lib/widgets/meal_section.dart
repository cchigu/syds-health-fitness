import 'package:flutter/material.dart';

import '../models/log_entry.dart';
import '../models/meal.dart';
import '../services/food_log_repository.dart';

/// One meal on the Today tab: its foods, calories, and an "Add food" button.
class MealSection extends StatelessWidget {
  const MealSection({
    super.key,
    required this.meal,
    required this.entries,
    required this.onAdd,
    required this.onScan,
    required this.onOpen,
    required this.onSaveAsMeal,
  });

  final Meal meal;
  final List<LogEntry> entries;
  final VoidCallback onAdd;
  final VoidCallback onScan;
  final void Function(LogEntry entry) onOpen;
  final VoidCallback onSaveAsMeal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final total = entries.fold<double>(0, (s, e) => s + e.nutrients.calories);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(meal.icon, color: colors.primary),
                const SizedBox(width: 10),
                Text(meal.label, style: text.titleMedium),
                const Spacer(),
                Text('${total.round()} cal', style: text.titleSmall),
                if (entries.isNotEmpty)
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (_) => onSaveAsMeal(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'save',
                        child: ListTile(
                          leading: Icon(Icons.bookmark_add_outlined),
                          title: Text('Save as a meal'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          for (final e in entries)
            Dismissible(
              key: ValueKey(e.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: colors.errorContainer,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: Icon(Icons.delete_outline,
                    color: colors.onErrorContainer),
              ),
              onDismissed: (_) {
                final repo = FoodLogRepository.instance;
                repo.delete(e);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text('Removed ${e.food.name}'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () => repo.restore(e),
                    ),
                  ));
              },
              child: ListTile(
                dense: true,
                onTap: () => onOpen(e),
                title: Text(e.food.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [if (e.food.brand != null) e.food.brand!, e.amount]
                      .join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text('${e.nutrients.calories.round()}',
                    style: text.bodyMedium),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add food'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Scan barcode',
                  onPressed: onScan,
                  icon: const Icon(Icons.qr_code_scanner),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
