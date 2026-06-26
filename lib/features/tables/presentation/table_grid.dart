import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../domain/restaurant_table.dart';
import '../domain/table_status.dart';

class TableGrid extends StatefulWidget {
  const TableGrid({
    super.key,
    required this.tables,
    this.completedPartySizeFor,
    this.occupiedSinceFor,
    this.onTableRecommendationTap,
    this.onEmptySpaceTap,
    this.onMealFinished,
    this.matchingTableIds = const {},
    this.tableHighlightTones = const {},
    this.highlightScrollKey,
  });

  final List<RestaurantTable> tables;
  final int Function(RestaurantTable table)? completedPartySizeFor;
  final DateTime? Function(RestaurantTable table)? occupiedSinceFor;
  final void Function(RestaurantTable table)? onTableRecommendationTap;
  final VoidCallback? onEmptySpaceTap;
  final void Function(RestaurantTable table, int initialPartySize)?
  onMealFinished;
  final Set<String> matchingTableIds;
  final Map<String, TableHighlightTone> tableHighlightTones;
  final Object? highlightScrollKey;

  @override
  State<TableGrid> createState() => _TableGridState();
}

class _TableGridState extends State<TableGrid> {
  late DateTime _now;
  Timer? _minuteTicker;
  final Map<String, GlobalKey> _tableKeys = {};
  String _highlightSignature = '';

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _highlightSignature = _currentHighlightSignature();
    _minuteTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void didUpdateWidget(covariant TableGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _currentHighlightSignature();
    final shouldScroll =
        nextSignature != _highlightSignature ||
        oldWidget.highlightScrollKey != widget.highlightScrollKey;
    _highlightSignature = nextSignature;
    if (!shouldScroll) return;
    _scrollToFirstHighlightedTable();
  }

  @override
  void dispose() {
    _minuteTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capacityGroups = _groupTablesByCapacity(widget.tables);
    final compact = Responsive.isCompact(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onEmptySpaceTap,
      child: Container(
        padding: EdgeInsets.all(compact ? 14 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1ABDC8D0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F006687),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tables by Capacity',
              style: TextStyle(
                fontSize: compact ? 20 : 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: compact ? 14 : 16),
            for (final group in capacityGroups) ...[
              _CapacityHeader(
                capacity: group.capacity,
                count: group.tables.length,
              ),
              SizedBox(height: compact ? 8 : 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: group.tables.length,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: compact ? 180 : 220,
                  childAspectRatio: compact ? 0.9 : 1,
                  crossAxisSpacing: compact ? 8 : 12,
                  mainAxisSpacing: compact ? 8 : 12,
                ),
                itemBuilder: (context, index) {
                  final table = group.tables[index];
                  return GestureDetector(
                    key: _keyForTable(table.id),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: _TableCard(
                      table: table,
                      now: _now,
                      initialPartySize: widget.completedPartySizeFor?.call(
                        table,
                      ),
                      occupiedSince: widget.occupiedSinceFor?.call(table),
                      onTableRecommendationTap:
                          widget.onTableRecommendationTap == null
                          ? null
                          : () => widget.onTableRecommendationTap!(table),
                      highlightTone:
                          widget.tableHighlightTones[table.id] ??
                          (widget.matchingTableIds.contains(table.id)
                              ? TableHighlightTone.best
                              : null),
                      onMealFinished: widget.onMealFinished == null
                          ? null
                          : () => widget.onMealFinished!(
                              table,
                              widget.completedPartySizeFor?.call(table) ??
                                  table.capacity,
                            ),
                    ),
                  );
                },
              ),
              if (group != capacityGroups.last)
                SizedBox(height: compact ? 14 : 18),
            ],
          ],
        ),
      ),
    );
  }

  GlobalKey _keyForTable(String tableId) {
    return _tableKeys.putIfAbsent(tableId, GlobalKey.new);
  }

  String _currentHighlightSignature() {
    final ids = {
      ...widget.matchingTableIds,
      ...widget.tableHighlightTones.keys,
    }.toList()..sort();
    return ids.join('|');
  }

  void _scrollToFirstHighlightedTable() {
    final tableId = _firstHighlightedTableId();
    if (tableId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _tableKeys[tableId]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
    });
  }

  String? _firstHighlightedTableId() {
    final best = _firstTableIdForTone(TableHighlightTone.best);
    if (best != null) return best;
    final nextBest = _firstTableIdForTone(TableHighlightTone.nextBest);
    if (nextBest != null) return nextBest;
    if (widget.matchingTableIds.isEmpty) return null;
    final ids = widget.matchingTableIds.toList()..sort();
    return ids.first;
  }

  String? _firstTableIdForTone(TableHighlightTone tone) {
    final ids =
        widget.tableHighlightTones.entries
            .where((entry) => entry.value == tone)
            .map((entry) => entry.key)
            .toList()
          ..sort();
    if (ids.isEmpty) return null;
    return ids.first;
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

enum TableHighlightTone { best, nextBest }

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
    required this.now,
    required this.initialPartySize,
    required this.occupiedSince,
    required this.onTableRecommendationTap,
    required this.onMealFinished,
    this.highlightTone,
  });

  final RestaurantTable table;
  final DateTime now;
  final int? initialPartySize;
  final DateTime? occupiedSince;
  final VoidCallback? onTableRecommendationTap;
  final VoidCallback? onMealFinished;
  final TableHighlightTone? highlightTone;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final occupiedCount = table.currentQueueEntryId == null
        ? 0
        : table.currentPartySize ?? initialPartySize ?? table.capacity;
    final color = _tableColor(occupiedCount);
    final highlightColor = _highlightColor();
    final highlightLabel = _highlightLabel();
    final isHighlighted = highlightColor != null;
    final statusLabel = _statusLabel(occupiedCount);
    final minutesSpent = _minutesSpent();
    final canFinishMeal =
        table.status == TableStatus.occupied &&
        table.currentQueueEntryId != null &&
        onMealFinished != null;
    final remainingSeats = table.capacity - occupiedCount;
    final canSuggestParty =
        onTableRecommendationTap != null &&
        remainingSeats > 0 &&
        (table.status == TableStatus.available ||
            table.status == TableStatus.occupied);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Color.alphaBlend(
                highlightColor.withValues(alpha: 0.08),
                color.withValues(alpha: 0.08),
              )
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlightColor ?? color.withValues(alpha: 0.35),
          width: isHighlighted ? 2.5 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: highlightColor.withValues(alpha: 0.34),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: highlightColor.withValues(alpha: 0.18),
                  blurRadius: 44,
                  spreadRadius: 4,
                ),
              ]
            : null,
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
                style: TextStyle(
                  fontSize: compact ? 22 : 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (highlightLabel != null) ...[
                    _TableHighlightPill(
                      label: highlightLabel,
                      color: highlightColor!,
                    ),
                    SizedBox(height: compact ? 3 : 4),
                  ],
                  _TableMetricPill(
                    label: 'Cap',
                    value: table.capacity,
                    color: color,
                  ),
                  SizedBox(height: compact ? 3 : 4),
                  _TableMetricPill(
                    label: 'Occ',
                    value: occupiedCount,
                    color: color,
                  ),
                  if (minutesSpent != null) ...[
                    SizedBox(height: compact ? 3 : 4),
                    _TableMetricPill(
                      label: 'Time',
                      value: minutesSpent,
                      suffix: 'm',
                      color: color,
                    ),
                  ],
                ],
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: compact ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 11 : 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (table.currentTokenCode != null) ...[
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          table.currentTokenCode!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navyText,
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canFinishMeal) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Finish meal',
                  child: SizedBox.square(
                    dimension: 32,
                    child: FilledButton(
                      onPressed: onMealFinished,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.deepTeal,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size.square(32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Icon(Icons.done_all, size: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (!canSuggestParty) return card;

    return Tooltip(
      message: 'Highlight best-fitting party',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTableRecommendationTap,
          borderRadius: BorderRadius.circular(14),
          child: card,
        ),
      ),
    );
  }

  Color _tableColor(int occupiedCount) {
    return switch (table.status) {
      TableStatus.available => AppColors.successGreen,
      TableStatus.reserved => AppColors.accentPurple,
      TableStatus.occupied =>
        occupiedCount >= table.capacity
            ? AppColors.errorRed
            : AppColors.warningOrange,
      TableStatus.blocked => Colors.grey,
    };
  }

  Color? _highlightColor() {
    return switch (highlightTone) {
      TableHighlightTone.best => AppColors.successGreen,
      TableHighlightTone.nextBest => AppColors.accentPurple,
      null => null,
    };
  }

  String? _highlightLabel() {
    return switch (highlightTone) {
      TableHighlightTone.best => 'Best',
      TableHighlightTone.nextBest => 'Next',
      null => null,
    };
  }

  String _statusLabel(int occupiedCount) {
    return switch (table.status) {
      TableStatus.available => 'available',
      TableStatus.reserved => 'reserved',
      TableStatus.occupied =>
        occupiedCount >= table.capacity ? 'full' : 'partial',
      TableStatus.blocked => 'blocked',
    };
  }

  int? _minutesSpent() {
    if (table.status != TableStatus.occupied) return null;
    final startedAt =
        table.currentCycleStartAt ??
        table.occupiedAt ??
        table.reservedAt ??
        occupiedSince;
    if (startedAt == null) return null;
    final minutes = now.difference(startedAt).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }
}

class _TableHighlightPill extends StatelessWidget {
  const _TableHighlightPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.62)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.32),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TableMetricPill extends StatelessWidget {
  const _TableMetricPill({
    required this.label,
    required this.value,
    this.suffix = '',
    required this.color,
  });

  final String label;
  final int value;
  final String suffix;
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
        '$label $value$suffix',
        style: const TextStyle(
          color: AppColors.navyText,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
