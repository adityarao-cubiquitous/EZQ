import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../domain/restaurant_table.dart';
import '../domain/table_status.dart';

class TableGrid extends StatelessWidget {
  const TableGrid({
    super.key,
    required this.tables,
    this.completedPartySizeFor,
    this.onMarkSeated,
    this.onMealFinished,
  });

  final List<RestaurantTable> tables;
  final int Function(RestaurantTable table)? completedPartySizeFor;
  final void Function(RestaurantTable table)? onMarkSeated;
  final void Function(RestaurantTable table, int initialPartySize)?
  onMealFinished;

  @override
  Widget build(BuildContext context) {
    final capacityGroups = _groupTablesByCapacity(tables);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1ABDC8D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tables by Capacity',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          for (final group in capacityGroups) ...[
            _CapacityHeader(
              capacity: group.capacity,
              count: group.tables.length,
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: group.tables.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final table = group.tables[index];
                return _TableCard(
                  table: table,
                  initialPartySize: completedPartySizeFor?.call(table),
                  onMarkSeated: onMarkSeated == null
                      ? null
                      : () => onMarkSeated!(table),
                  onMealFinished: onMealFinished == null
                      ? null
                      : () => onMealFinished!(
                          table,
                          completedPartySizeFor?.call(table) ?? table.capacity,
                        ),
                );
              },
            ),
            if (group != capacityGroups.last) const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  List<_CapacityGroup> _groupTablesByCapacity(List<RestaurantTable> tables) {
    final sortedTables = [...tables]
      ..sort((a, b) {
        final capacity = a.capacity.compareTo(b.capacity);
        if (capacity != 0) return capacity;
        final sortOrder = a.sortOrder.compareTo(b.sortOrder);
        if (sortOrder != 0) return sortOrder;
        return a.tableNumber.compareTo(b.tableNumber);
      });
    final groups = <_CapacityGroup>[];
    for (final table in sortedTables) {
      if (groups.isEmpty || groups.last.capacity != table.capacity) {
        groups.add(_CapacityGroup(capacity: table.capacity, tables: [table]));
      } else {
        groups.last.tables.add(table);
      }
    }
    return groups;
  }
}

class _CapacityGroup {
  _CapacityGroup({required this.capacity, required this.tables});

  final int capacity;
  final List<RestaurantTable> tables;
}

class _CapacityHeader extends StatelessWidget {
  const _CapacityHeader({required this.capacity, required this.count});

  final int capacity;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6FF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x1A006687)),
          ),
          child: Text(
            '$capacity-top',
            style: const TextStyle(
              color: AppColors.deepTeal,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count ${count == 1 ? 'table' : 'tables'}',
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: 10),
            child: Divider(color: Color(0x1ABDC8D0)),
          ),
        ),
      ],
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.initialPartySize,
    required this.onMarkSeated,
    required this.onMealFinished,
  });

  final RestaurantTable table;
  final int? initialPartySize;
  final VoidCallback? onMarkSeated;
  final VoidCallback? onMealFinished;

  @override
  Widget build(BuildContext context) {
    final color = switch (table.status) {
      TableStatus.available => AppColors.primaryTeal,
      TableStatus.reserved => AppColors.accentPurple,
      TableStatus.occupied => AppColors.errorRed,
      TableStatus.blocked => Colors.grey,
    };
    final canFinishMeal =
        table.status == TableStatus.occupied &&
        table.currentQueueEntryId != null &&
        onMealFinished != null;
    final canMarkSeated =
        table.status == TableStatus.reserved &&
        table.currentQueueEntryId != null &&
        onMarkSeated != null;
    final occupiedCount = table.currentQueueEntryId == null
        ? 0
        : initialPartySize ?? table.capacity;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                table.tableNumber,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TableMetricPill(
                    label: 'Cap',
                    value: table.capacity,
                    color: color,
                  ),
                  const SizedBox(height: 5),
                  _TableMetricPill(
                    label: 'Occ',
                    value: occupiedCount,
                    color: color,
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  table.status.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (table.currentTokenCode != null) ...[
                const SizedBox(width: 8),
                Text(
                  table.currentTokenCode!,
                  style: const TextStyle(
                    color: AppColors.navyText,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          if (canFinishMeal)
            SizedBox(
              width: double.infinity,
              height: 32,
              child: FilledButton.icon(
                onPressed: onMealFinished,
                icon: const Icon(Icons.done_all, size: 15),
                label: Text(
                  'Meal finished${initialPartySize == null ? '' : ' ($initialPartySize)'}',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.deepTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (canMarkSeated)
            SizedBox(
              width: double.infinity,
              height: 32,
              child: FilledButton.icon(
                onPressed: onMarkSeated,
                icon: const Icon(Icons.event_seat, size: 15),
                label: const Text('Mark seated'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.deepTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableMetricPill extends StatelessWidget {
  const _TableMetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: AppColors.navyText,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
