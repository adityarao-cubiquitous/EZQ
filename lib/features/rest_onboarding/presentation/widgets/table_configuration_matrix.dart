import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class TableConfigurationMatrix extends StatefulWidget {
  const TableConfigurationMatrix({
    super.key,
    required this.selectedCapacities,
    required this.tableCountsByFloor,
    required this.title,
    this.emptyText = 'No configured table counts yet.',
    this.showGrandTotal = true,
  });

  final List<int> selectedCapacities;
  final List<List<int>> tableCountsByFloor;
  final String title;
  final String emptyText;
  final bool showGrandTotal;

  @override
  State<TableConfigurationMatrix> createState() =>
      _TableConfigurationMatrixState();
}

class _TableConfigurationMatrixState extends State<TableConfigurationMatrix> {
  final _horizontalController = ScrollController();

  bool _debugAssertMatrixInvariant() {
    assert(() {
      assert(
        widget.tableCountsByFloor.every(
          (row) => row.length == widget.selectedCapacities.length,
        ),
        'Matrix rows must match selected capacity count. '
        'Capacities: ${widget.selectedCapacities.length}, '
        'row lengths: ${widget.tableCountsByFloor.map((row) => row.length).toList()}.',
      );
      return true;
    }());
    return true;
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  int get _grandTotalTables {
    return widget.tableCountsByFloor.fold<int>(
      0,
      (total, floorCounts) =>
          total + floorCounts.fold<int>(0, (sum, count) => sum + count),
    );
  }

  int get _grandTotalSeats {
    var seats = 0;
    for (final floorCounts in widget.tableCountsByFloor) {
      for (var index = 0; index < widget.selectedCapacities.length; index++) {
        final count = index < floorCounts.length ? floorCounts[index] : 0;
        seats += count * widget.selectedCapacities[index];
      }
    }
    return seats;
  }

  @override
  Widget build(BuildContext context) {
    assert(_debugAssertMatrixInvariant());
    final selectedCapacities = List<int>.from(widget.selectedCapacities);
    final tableCountsByFloor = widget.tableCountsByFloor
        .map((floorCounts) => List<int>.from(floorCounts))
        .toList();

    if (selectedCapacities.isEmpty) {
      return _MatrixPanel(
        title: widget.title,
        child: Text(
          widget.emptyText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.mutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return _MatrixPanel(
      title: widget.title,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const floorColumnWidth = 132.0;
          const capacityColumnWidth = 126.0;
          const grandTotalWidth = 150.0;
          const rowHeight = 72.0;
          const headerHeight = 48.0;
          const rowGap = 10.0;
          final visibleCapacityCount = selectedCapacities.length;
          final capacityWidth =
              (visibleCapacityCount * capacityColumnWidth) +
              (widget.showGrandTotal ? grandTotalWidth : 0);
          final availableCapacityWidth =
              constraints.maxWidth - floorColumnWidth;
          final showScroll = capacityWidth > availableCapacityWidth;

          final capacityColumns = SizedBox(
            width: capacityWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CapacityHeaderRow(
                  capacities: selectedCapacities,
                  columnWidth: capacityColumnWidth,
                  grandTotalWidth: grandTotalWidth,
                  height: headerHeight,
                  showGrandTotal: widget.showGrandTotal,
                ),
                const SizedBox(height: rowGap),
                for (
                  var floorIndex = 0;
                  floorIndex < tableCountsByFloor.length;
                  floorIndex++
                ) ...[
                  _FloorCapacityRow(
                    floorNumber: floorIndex + 1,
                    counts: tableCountsByFloor[floorIndex],
                    capacities: selectedCapacities,
                    columnWidth: capacityColumnWidth,
                    grandTotalWidth: grandTotalWidth,
                    height: rowHeight,
                    showGrandTotal: widget.showGrandTotal,
                  ),
                  if (floorIndex != tableCountsByFloor.length - 1)
                    const SizedBox(height: rowGap),
                ],
                const SizedBox(height: rowGap),
                _TotalsRow(
                  capacities: selectedCapacities,
                  tableCountsByFloor: tableCountsByFloor,
                  grandTotalTables: _grandTotalTables,
                  grandTotalSeats: _grandTotalSeats,
                  columnWidth: capacityColumnWidth,
                  grandTotalWidth: grandTotalWidth,
                  height: rowHeight,
                  showGrandTotal: widget.showGrandTotal,
                ),
              ],
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FloorHeaderColumn(
                    floorCount: tableCountsByFloor.length,
                    width: floorColumnWidth,
                    headerHeight: headerHeight,
                    rowHeight: rowHeight,
                    rowGap: rowGap,
                  ),
                  Expanded(
                    child: showScroll
                        ? Scrollbar(
                            controller: _horizontalController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _horizontalController,
                              scrollDirection: Axis.horizontal,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: capacityColumns,
                              ),
                            ),
                          )
                        : capacityColumns,
                  ),
                ],
              ),
              if (showScroll) ...[
                const SizedBox(height: 9),
                const _HorizontalScrollHint(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MatrixPanel extends StatelessWidget {
  const _MatrixPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.navyText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _FloorHeaderColumn extends StatelessWidget {
  const _FloorHeaderColumn({
    required this.floorCount,
    required this.width,
    required this.headerHeight,
    required this.rowHeight,
    required this.rowGap,
  });

  final int floorCount;
  final double width;
  final double headerHeight;
  final double rowHeight;
  final double rowGap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCell(label: 'Floor', height: headerHeight, alignLeft: true),
          SizedBox(height: rowGap),
          for (var floorIndex = 0; floorIndex < floorCount; floorIndex++) ...[
            _FloorLabelCell(
              label: 'Floor ${floorIndex + 1}',
              height: rowHeight,
            ),
            if (floorIndex != floorCount - 1) SizedBox(height: rowGap),
          ],
          SizedBox(height: rowGap),
          _FloorLabelCell(label: 'Totals', height: rowHeight, isTotal: true),
        ],
      ),
    );
  }
}

class _CapacityHeaderRow extends StatelessWidget {
  const _CapacityHeaderRow({
    required this.capacities,
    required this.columnWidth,
    required this.grandTotalWidth,
    required this.height,
    required this.showGrandTotal,
  });

  final List<int> capacities;
  final double columnWidth;
  final double grandTotalWidth;
  final double height;
  final bool showGrandTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final capacity in capacities)
          SizedBox(
            width: columnWidth,
            child: _HeaderCell(label: '$capacity Top', height: height),
          ),
        if (showGrandTotal)
          SizedBox(
            width: grandTotalWidth,
            child: _HeaderCell(label: 'Grand Total', height: height),
          ),
      ],
    );
  }
}

class _FloorCapacityRow extends StatelessWidget {
  const _FloorCapacityRow({
    required this.floorNumber,
    required this.counts,
    required this.capacities,
    required this.columnWidth,
    required this.grandTotalWidth,
    required this.height,
    required this.showGrandTotal,
  });

  final int floorNumber;
  final List<int> counts;
  final List<int> capacities;
  final double columnWidth;
  final double grandTotalWidth;
  final double height;
  final bool showGrandTotal;

  int get _rowTotalTables =>
      counts.fold<int>(0, (total, count) => total + count);

  int get _rowTotalSeats {
    var seats = 0;
    for (var index = 0; index < capacities.length; index++) {
      seats += (index < counts.length ? counts[index] : 0) * capacities[index];
    }
    return seats;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < capacities.length; index++)
          SizedBox(
            width: columnWidth,
            child: _MatrixValueCell(
              floorNumber: floorNumber,
              capacity: capacities[index],
              value: index < counts.length ? counts[index] : 0,
              height: height,
            ),
          ),
        if (showGrandTotal)
          SizedBox(
            width: grandTotalWidth,
            child: _TotalValueCell(
              tableCount: _rowTotalTables,
              seatCount: _rowTotalSeats,
              height: height,
              semanticLabel:
                  'Floor $floorNumber total, $_rowTotalTables tables, '
                  '$_rowTotalSeats seats',
            ),
          ),
      ],
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.capacities,
    required this.tableCountsByFloor,
    required this.grandTotalTables,
    required this.grandTotalSeats,
    required this.columnWidth,
    required this.grandTotalWidth,
    required this.height,
    required this.showGrandTotal,
  });

  final List<int> capacities;
  final List<List<int>> tableCountsByFloor;
  final int grandTotalTables;
  final int grandTotalSeats;
  final double columnWidth;
  final double grandTotalWidth;
  final double height;
  final bool showGrandTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < capacities.length; index++)
          SizedBox(
            width: columnWidth,
            child: _TotalValueCell(
              tableCount: _capacityTotal(index),
              seatCount: _capacityTotal(index) * capacities[index],
              height: height,
              semanticLabel:
                  'Total ${capacities[index]} Top, '
                  '${_capacityTotal(index)} tables, '
                  '${_capacityTotal(index) * capacities[index]} seats',
            ),
          ),
        if (showGrandTotal)
          SizedBox(
            width: grandTotalWidth,
            child: _TotalValueCell(
              tableCount: grandTotalTables,
              seatCount: grandTotalSeats,
              height: height,
              semanticLabel:
                  'Grand total, $grandTotalTables tables, '
                  '$grandTotalSeats seats',
            ),
          ),
      ],
    );
  }

  int _capacityTotal(int capacityIndex) {
    return tableCountsByFloor.fold<int>(
      0,
      (total, floorCounts) =>
          total +
          (capacityIndex < floorCounts.length ? floorCounts[capacityIndex] : 0),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.height,
    this.alignLeft = false,
  });

  final String label;
  final double height;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: alignLeft ? TextAlign.left : TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.navyText,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FloorLabelCell extends StatelessWidget {
  const _FloorLabelCell({
    required this.label,
    required this.height,
    this.isTotal = false,
  });

  final String label;
  final double height;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isTotal ? AppColors.softSurface : AppColors.background,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.navyText,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MatrixValueCell extends StatefulWidget {
  const _MatrixValueCell({
    required this.floorNumber,
    required this.capacity,
    required this.value,
    required this.height,
  });

  final int floorNumber;
  final int capacity;
  final int value;
  final double height;

  @override
  State<_MatrixValueCell> createState() => _MatrixValueCellState();
}

class _MatrixValueCellState extends State<_MatrixValueCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isConfigured = widget.value > 0;
    final semanticLabel = isConfigured
        ? 'Floor ${widget.floorNumber}, ${widget.capacity} Top, '
              '${widget.value} tables, ${widget.value * widget.capacity} seats'
        : 'Floor ${widget.floorNumber}, ${widget.capacity} Top, Not configured';

    return Semantics(
      label: semanticLabel,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: widget.height,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isConfigured
                ? (_isHovered ? AppColors.softSurface : AppColors.background)
                : AppColors.softerSurface,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: isConfigured
              ? _TableSeatValue(
                  tableCount: widget.value,
                  seatCount: widget.value * widget.capacity,
                )
              : Text(
                  '—',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

class _TotalValueCell extends StatelessWidget {
  const _TotalValueCell({
    required this.tableCount,
    required this.seatCount,
    required this.height,
    this.semanticLabel,
  });

  final int tableCount;
  final int seatCount;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.softSurface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: _TableSeatValue(
          tableCount: tableCount,
          seatCount: seatCount,
          isTotal: true,
        ),
      ),
    );
  }
}

class _TableSeatValue extends StatelessWidget {
  const _TableSeatValue({
    required this.tableCount,
    required this.seatCount,
    this.isTotal = false,
  });

  final int tableCount;
  final int seatCount;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.navyText,
      fontWeight: isTotal ? FontWeight.w900 : FontWeight.w800,
      height: 1.25,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Tables: $tableCount', textAlign: TextAlign.center, style: style),
        const SizedBox(height: 3),
        Text('Seats: $seatCount', textAlign: TextAlign.center, style: style),
      ],
    );
  }
}

class _HorizontalScrollHint extends StatelessWidget {
  const _HorizontalScrollHint();

  @override
  Widget build(BuildContext context) {
    return Text(
      '← Scroll horizontally to view additional table capacities →',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.mutedText,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
