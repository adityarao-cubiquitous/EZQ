import '../../tables/domain/restaurant_table.dart';
import '../../tables/domain/table_status.dart';

class MultiTableRecommendationSet {
  const MultiTableRecommendationSet({
    this.bestFits = const [],
    this.nextBestFits = const [],
  });

  final List<TableCombinationRecommendation> bestFits;
  final List<TableCombinationRecommendation> nextBestFits;

  bool get isEmpty => bestFits.isEmpty && nextBestFits.isEmpty;
}

class RecommendedTableSlot {
  const RecommendedTableSlot({required this.table, required this.openSeats});

  final RestaurantTable table;
  final int openSeats;

  bool get isPartiallyOccupied => table.status == TableStatus.occupied;
}

class TableCombinationRecommendation {
  const TableCombinationRecommendation({
    required this.floorId,
    required this.slots,
  });

  final String floorId;
  final List<RecommendedTableSlot> slots;

  List<RestaurantTable> get tables => [for (final slot in slots) slot.table];
  int get totalCapacity => slots.fold(0, (sum, slot) => sum + slot.openSeats);
  bool get includesPartiallyOccupiedTable =>
      slots.any((slot) => slot.isPartiallyOccupied);
}

MultiTableRecommendationSet recommendMultiTableCombination({
  required int partySize,
  required List<RestaurantTable> tables,
  int Function(RestaurantTable table)? openSeatsFor,
}) {
  if (partySize <= 0) return const MultiTableRecommendationSet();

  final eligibleSlots = <RecommendedTableSlot>[];
  for (final table in tables) {
    if (table.status != TableStatus.available) continue;
    final openSeats =
        openSeatsFor?.call(table) ??
        (table.status == TableStatus.available ? table.capacity : 0);
    if (openSeats <= 0) continue;
    eligibleSlots.add(RecommendedTableSlot(table: table, openSeats: openSeats));
  }
  if (eligibleSlots.isEmpty) return const MultiTableRecommendationSet();

  final maximumSingleCapacity = eligibleSlots
      .map((slot) => slot.openSeats)
      .reduce((a, b) => a > b ? a : b);
  if (partySize <= maximumSingleCapacity) {
    return const MultiTableRecommendationSet();
  }

  final slotsByFloor = <String, List<RecommendedTableSlot>>{};
  for (final slot in eligibleSlots) {
    slotsByFloor.putIfAbsent(slot.table.floorId, () => []).add(slot);
  }

  final bestFits = <TableCombinationRecommendation>[];
  final nextBestFits = <TableCombinationRecommendation>[];
  final sortedFloors = slotsByFloor.keys.toList()..sort();
  for (final floorId in sortedFloors) {
    final floorSlots = slotsByFloor[floorId]!..sort(_compareSlots);
    bestFits.addAll(
      _twoTableCombinations(
        floorId: floorId,
        slots: floorSlots,
        matches: (total) => total == partySize,
      ),
    );
    nextBestFits.addAll(
      _twoTableCombinations(
        floorId: floorId,
        slots: floorSlots,
        matches: (total) => total > partySize,
      ),
    );
  }

  return MultiTableRecommendationSet(
    bestFits: bestFits,
    nextBestFits: nextBestFits,
  );
}

List<TableCombinationRecommendation> _twoTableCombinations({
  required String floorId,
  required List<RecommendedTableSlot> slots,
  required bool Function(int total) matches,
}) {
  if (slots.length < 2) return const [];
  final matchesForPair = <TableCombinationRecommendation>[];
  _visitCombinations(
    slots: slots,
    targetCount: 2,
    startIndex: 0,
    selected: [],
    total: 0,
    onCombination: (selected, total) {
      if (!matches(total)) return;
      matchesForPair.add(
        TableCombinationRecommendation(
          floorId: floorId,
          slots: List.unmodifiable(selected),
        ),
      );
    },
  );
  return matchesForPair;
}

void _visitCombinations({
  required List<RecommendedTableSlot> slots,
  required int targetCount,
  required int startIndex,
  required List<RecommendedTableSlot> selected,
  required int total,
  required void Function(List<RecommendedTableSlot> selected, int total)
  onCombination,
}) {
  if (selected.length == targetCount) {
    onCombination(selected, total);
    return;
  }
  final remainingNeeded = targetCount - selected.length;
  final lastStart = slots.length - remainingNeeded;
  for (var index = startIndex; index <= lastStart; index++) {
    final slot = slots[index];
    selected.add(slot);
    _visitCombinations(
      slots: slots,
      targetCount: targetCount,
      startIndex: index + 1,
      selected: selected,
      total: total + slot.openSeats,
      onCombination: onCombination,
    );
    selected.removeLast();
  }
}

int _compareSlots(RecommendedTableSlot a, RecommendedTableSlot b) {
  final sortOrder = a.table.sortOrder.compareTo(b.table.sortOrder);
  if (sortOrder != 0) return sortOrder;
  final number = a.table.tableNumber.compareTo(b.table.tableNumber);
  if (number != 0) return number;
  return a.table.id.compareTo(b.table.id);
}
