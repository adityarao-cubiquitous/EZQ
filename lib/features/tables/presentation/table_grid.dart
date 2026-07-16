import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../domain/floor_table_map.dart';
import '../domain/restaurant_floor.dart';
import '../domain/restaurant_table.dart';
import '../domain/table_status.dart';
import 'responsive_floor_layout.dart';

final Set<String> _warnedTableCardDisplayNameFallbacks = <String>{};

class TableGrid extends StatefulWidget {
  const TableGrid({
    super.key,
    required this.floorTableMap,
    this.completedPartySizeFor,
    this.occupiedSinceFor,
    this.onTableRecommendationTap,
    this.onEmptySpaceTap,
    this.onMealFinished,
    this.onUndoReservation,
    this.matchingTableIds = const {},
    this.tableHighlightTones = const {},
    this.highlightScrollKey,
  });

  final RestaurantFloorTableMap floorTableMap;
  final int Function(RestaurantTable table)? completedPartySizeFor;
  final DateTime? Function(RestaurantTable table)? occupiedSinceFor;
  final void Function(RestaurantTable table)? onTableRecommendationTap;
  final VoidCallback? onEmptySpaceTap;
  final void Function(RestaurantTable table, int initialPartySize)?
  onMealFinished;
  final void Function(RestaurantTable table)? onUndoReservation;
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
    final capacitySections = widget.floorTableMap.capacityFloorSections;
    final compact = Responsive.isCompact(context);
    final capacityGap = compact ? 28.0 : 32.0;
    final floorGap = compact ? 14.0 : 18.0;
    final headerToGridGap = compact ? 14.0 : 16.0;
    final minFloorWidth = compact ? 180.0 : 220.0;
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
            const SizedBox(height: 4),
            Text(
              'Grouped by seating capacity and floor',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: compact ? 16 : 18),
            for (final section in capacitySections) ...[
              ResponsiveCapacitySection(
                header: _CapacityHeader(
                  capacityLabel: section.capacityLabel,
                  count: section.tableCount,
                ),
                floorCount: section.floors.length,
                minFloorWidth: minFloorWidth,
                headerToGridGap: headerToGridGap,
                floorGap: floorGap,
                floorBuilder: (context, index, width) {
                  final floorSection = section.floors[index];
                  return _FloorTablesContainer(
                    floor: floorSection.floor,
                    tables: floorSection.tables,
                    compact: compact,
                    now: _now,
                    tableKeyFor: _keyForTable,
                    completedPartySizeFor: widget.completedPartySizeFor,
                    occupiedSinceFor: widget.occupiedSinceFor,
                    onTableRecommendationTap: widget.onTableRecommendationTap,
                    onMealFinished: widget.onMealFinished,
                    onUndoReservation: widget.onUndoReservation,
                    matchingTableIds: widget.matchingTableIds,
                    tableHighlightTones: widget.tableHighlightTones,
                  );
                },
              ),
              if (section != capacitySections.last)
                SizedBox(height: capacityGap),
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
}

enum TableHighlightTone { best, nextBest, free, occupied }

class _FloorTablesContainer extends StatelessWidget {
  const _FloorTablesContainer({
    required this.floor,
    required this.tables,
    required this.compact,
    required this.now,
    required this.tableKeyFor,
    required this.completedPartySizeFor,
    required this.occupiedSinceFor,
    required this.onTableRecommendationTap,
    required this.onMealFinished,
    required this.onUndoReservation,
    required this.matchingTableIds,
    required this.tableHighlightTones,
  });

  final RestaurantFloor floor;
  final List<RestaurantTable> tables;
  final bool compact;
  final DateTime now;
  final GlobalKey Function(String tableId) tableKeyFor;
  final int Function(RestaurantTable table)? completedPartySizeFor;
  final DateTime? Function(RestaurantTable table)? occupiedSinceFor;
  final void Function(RestaurantTable table)? onTableRecommendationTap;
  final void Function(RestaurantTable table, int initialPartySize)?
  onMealFinished;
  final void Function(RestaurantTable table)? onUndoReservation;
  final Set<String> matchingTableIds;
  final Map<String, TableHighlightTone> tableHighlightTones;

  @override
  Widget build(BuildContext context) {
    return FloorContainer(
      floorLabel: _floorLabel,
      compact: compact,
      child: tables.isEmpty
          ? _EmptyFloorPlaceholder(compact: compact)
          : _FloorTableWrap(
              tables: tables,
              compact: compact,
              tableKeyFor: tableKeyFor,
              tableBuilder: _buildTableCard,
            ),
    );
  }

  String get _floorLabel =>
      '${floor.floorName} (${tables.length} ${tables.length == 1 ? 'Table' : 'Tables'})';

  Widget _buildTableCard(RestaurantTable table) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: _TableCard(
        table: table,
        now: now,
        initialPartySize: completedPartySizeFor?.call(table),
        occupiedSince: occupiedSinceFor?.call(table),
        onTableRecommendationTap: onTableRecommendationTap == null
            ? null
            : () => onTableRecommendationTap!(table),
        highlightTone:
            tableHighlightTones[table.id] ??
            (matchingTableIds.contains(table.id)
                ? TableHighlightTone.best
                : null),
        onMealFinished: onMealFinished == null
            ? null
            : () => onMealFinished!(
                table,
                completedPartySizeFor?.call(table) ?? table.capacity,
              ),
        onUndoReservation: onUndoReservation == null
            ? null
            : () => onUndoReservation!(table),
      ),
    );
  }
}

class FloorContainer extends StatelessWidget {
  const FloorContainer({
    super.key,
    required this.floorLabel,
    required this.compact,
    required this.child,
  });

  final String floorLabel;
  final bool compact;
  final Widget child;

  static double horizontalPadding(bool compact) => compact ? 10.0 : 12.0;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.all(horizontalPadding(compact));
    return CustomPaint(
      painter: _DottedBorderPainter(
        color: const Color(0xFF8A9AA5).withValues(alpha: 0.9),
        radius: 8,
      ),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: compact ? 216 : 242),
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.softerSurface.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FloorHeader(label: floorLabel),
            SizedBox(height: compact ? 12 : 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  const _DottedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dashLength = 4.0;
  static const _gapLength = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashLength;
        canvas.drawPath(
          metric.extractPath(
            distance,
            next > metric.length ? metric.length : next,
          ),
          paint,
        );
        distance = next + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter oldDelegate) {
    return color != oldDelegate.color || radius != oldDelegate.radius;
  }
}

class _FloorTableWrap extends StatelessWidget {
  const _FloorTableWrap({
    required this.tables,
    required this.compact,
    required this.tableKeyFor,
    required this.tableBuilder,
  });

  final List<RestaurantTable> tables;
  final bool compact;
  final GlobalKey Function(String tableId) tableKeyFor;
  final Widget Function(RestaurantTable table) tableBuilder;

  @override
  Widget build(BuildContext context) {
    final tileWidth = compact ? 160.0 : 196.0;
    final aspectRatio = compact ? 0.9 : 1.0;
    final gap = compact ? 8.0 : 12.0;

    final tileHeight = tileWidth / aspectRatio;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final table in tables)
          SizedBox(
            key: tableKeyFor(table.id),
            width: tileWidth,
            height: tileHeight,
            child: tableBuilder(table),
          ),
      ],
    );
  }
}

class _FloorHeader extends StatelessWidget {
  const _FloorHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0x4D8A9AA5))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label.replaceFirst(' (', ' • ').replaceFirst(')', ''),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.inkBlue,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0x4D8A9AA5))),
      ],
    );
  }
}

class _EmptyFloorPlaceholder extends StatelessWidget {
  const _EmptyFloorPlaceholder({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tileWidth = compact ? 160.0 : 196.0;
    final aspectRatio = compact ? 0.9 : 1.0;
    return SizedBox(
      width: double.infinity,
      height: tileWidth / aspectRatio,
      child: const Center(
        child: Text(
          'No tables on this floor.',
          style: TextStyle(
            color: AppColors.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CapacityHeader extends StatelessWidget {
  const _CapacityHeader({required this.capacityLabel, required this.count});

  final String capacityLabel;
  final int count;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final countLabel = '$count ${count == 1 ? 'Table' : 'Tables'}';
    return Row(
      children: [
        Container(
          height: compact ? 44 : 46,
          padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF3AA9F4).withValues(alpha: 0.18),
                const Color(0xFF6D5CF5).withValues(alpha: 0.16),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.primaryTeal.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.table_restaurant_rounded,
                size: 17,
                color: AppColors.deepTeal,
              ),
              const SizedBox(width: 9),
              Text(
                capacityLabel,
                style: TextStyle(
                  color: AppColors.inkBlue,
                  fontSize: compact ? 15 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 18),
              Container(
                width: 1,
                height: 16,
                color: AppColors.primaryTeal.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 14),
              Text(
                countLabel,
                style: TextStyle(
                  color: AppColors.deepTeal.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
    required this.onUndoReservation,
    this.highlightTone,
  });

  static const _undoWindow = Duration(minutes: 5);

  final RestaurantTable table;
  final DateTime now;
  final int? initialPartySize;
  final DateTime? occupiedSince;
  final VoidCallback? onTableRecommendationTap;
  final VoidCallback? onMealFinished;
  final VoidCallback? onUndoReservation;
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
    final undoMinutesLeft = _undoMinutesLeft();
    final canUndoReservation =
        table.status == TableStatus.occupied &&
        table.currentQueueEntryId != null &&
        onUndoReservation != null &&
        undoMinutesLeft != null;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _displayTableName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 22 : 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: compact ? 6 : 8),
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
                if (canUndoReservation) ...[
                  _TableTileIconButton(
                    message: 'Undo seating (${undoMinutesLeft}m left)',
                    icon: Icons.undo_rounded,
                    backgroundColor: const Color(0xFFFFF7E8),
                    foregroundColor: AppColors.warningOrange,
                    borderColor: AppColors.warningOrange.withValues(
                      alpha: 0.32,
                    ),
                    onPressed: onUndoReservation,
                  ),
                  const SizedBox(width: 6),
                ],
                _TableTileIconButton(
                  message: 'Finish meal',
                  icon: Icons.done_all,
                  backgroundColor: AppColors.deepTeal,
                  foregroundColor: Colors.white,
                  borderColor: AppColors.deepTeal,
                  onPressed: onMealFinished,
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

  String get _displayTableName {
    final displayTableName = table.displayTableName.trim();
    if (displayTableName.isNotEmpty) return displayTableName;
    final floorId = table.floorId.trim();
    final tableNumber = table.tableNumber.trim();
    if (floorId.isNotEmpty && tableNumber.isNotEmpty) {
      _warnMissingDisplayTableName(table, fallback: '$floorId-$tableNumber');
      return '$floorId-$tableNumber';
    }
    _warnMissingDisplayTableName(table, fallback: tableNumber);
    return tableNumber;
  }

  void _warnMissingDisplayTableName(
    RestaurantTable table, {
    required String fallback,
  }) {
    if (!_warnedTableCardDisplayNameFallbacks.add(table.id)) return;
    debugPrint(
      '[TABLE_GRID] Missing displayTableName; using fallback="$fallback" '
      'tableId=${table.id} tableNumber=${table.tableNumber} '
      'floorId=${table.floorId}',
    );
  }

  Color _tableColor(int occupiedCount) {
    return switch (table.status) {
      TableStatus.available => AppColors.primaryTeal,
      TableStatus.reserved => AppColors.accentPurple,
      TableStatus.occupied =>
        occupiedCount >= table.capacity
            ? AppColors.errorRed
            : AppColors.partialLavender,
      TableStatus.blocked => Colors.grey,
    };
  }

  Color? _highlightColor() {
    return switch (highlightTone) {
      TableHighlightTone.best => AppColors.successGreen,
      TableHighlightTone.nextBest => AppColors.recommendationYellow,
      TableHighlightTone.free => AppColors.primaryTeal,
      TableHighlightTone.occupied => AppColors.errorRed,
      null => null,
    };
  }

  String? _highlightLabel() {
    return switch (highlightTone) {
      TableHighlightTone.best => 'Best',
      TableHighlightTone.nextBest => 'Next',
      TableHighlightTone.free => 'Free',
      TableHighlightTone.occupied => 'Occupied',
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

  int? _undoMinutesLeft() {
    final startedAt = _undoWindowStartedAt();
    if (startedAt == null) return null;
    final elapsed = now.difference(startedAt);
    if (elapsed.isNegative || elapsed > _undoWindow) return null;
    final remaining = _undoWindow - elapsed;
    return remaining.inMinutes.clamp(1, _undoWindow.inMinutes);
  }

  DateTime? _undoWindowStartedAt() {
    return table.reservedAt ?? table.occupiedAt ?? table.updatedAt;
  }
}

class _TableTileIconButton extends StatelessWidget {
  const _TableTileIconButton({
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.onPressed,
  });

  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      child: SizedBox.square(
        dimension: 32,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(color: borderColor),
            ),
          ),
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }
}

class _TableHighlightPill extends StatelessWidget {
  const _TableHighlightPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final foreground = color.computeLuminance() > 0.56
        ? AppColors.navyText
        : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.36),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
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
