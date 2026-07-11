import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import 'table_configuration_matrix.dart';

class FloorsTablesStep extends StatefulWidget {
  const FloorsTablesStep({
    super.key,
    required this.floorCount,
    required this.selectedTableCapacities,
    required this.tableCountsByFloor,
    required this.showValidationError,
    required this.canContinue,
    required this.onFloorCountChanged,
    required this.onTableCapacityAdded,
    required this.onTableCapacityRemoved,
    required this.onTableCountChanged,
    required this.onBack,
    required this.onSaveDraft,
    required this.onContinue,
  });

  static const supportedCapacities = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
  ];

  final int floorCount;
  final List<int> selectedTableCapacities;
  final List<List<int>> tableCountsByFloor;
  final bool showValidationError;
  final bool canContinue;
  final ValueChanged<int> onFloorCountChanged;
  final ValueChanged<int> onTableCapacityAdded;
  final ValueChanged<int> onTableCapacityRemoved;
  final void Function(int floorIndex, int tableTypeIndex, int value)
  onTableCountChanged;
  final VoidCallback onBack;
  final VoidCallback onSaveDraft;
  final VoidCallback onContinue;

  @override
  State<FloorsTablesStep> createState() => _FloorsTablesStepState();
}

class _FloorsTablesStepState extends State<FloorsTablesStep> {
  int _capacityToAdd = 1;
  bool _isAddingCapacity = false;

  bool _debugAssertTableConfigurationInvariant() {
    assert(() {
      assert(
        widget.tableCountsByFloor.length == widget.floorCount,
        'Step 2 expected ${widget.floorCount} floor rows, '
        'found ${widget.tableCountsByFloor.length}.',
      );
      assert(
        widget.tableCountsByFloor.every(
          (row) => row.length == widget.selectedTableCapacities.length,
        ),
        'Step 2 floor rows must match selected capacity count. '
        'Capacities: ${widget.selectedTableCapacities.length}, '
        'row lengths: ${widget.tableCountsByFloor.map((row) => row.length).toList()}.',
      );
      return true;
    }());
    return true;
  }

  int get totalTables => widget.tableCountsByFloor.fold<int>(
    0,
    (total, floorCounts) =>
        total + floorCounts.fold<int>(0, (sum, count) => sum + count),
  );

  int get totalSeats {
    var seats = 0;
    for (final floorCounts in widget.tableCountsByFloor) {
      for (
        var index = 0;
        index < widget.selectedTableCapacities.length;
        index++
      ) {
        final tableCount = index < floorCounts.length ? floorCounts[index] : 0;
        seats += tableCount * widget.selectedTableCapacities[index];
      }
    }
    return seats;
  }

  List<int> get _availableCapacities {
    return FloorsTablesStep.supportedCapacities
        .where((capacity) => !widget.selectedTableCapacities.contains(capacity))
        .toList();
  }

  @override
  void didUpdateWidget(covariant FloorsTablesStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    final available = _availableCapacities;
    if (available.isNotEmpty && !available.contains(_capacityToAdd)) {
      _capacityToAdd = available.first;
    }
    if (available.isEmpty && _isAddingCapacity) {
      _isAddingCapacity = false;
    }
  }

  void _showCapacityPicker() {
    final available = _availableCapacities;
    if (available.isEmpty) return;
    setState(() {
      _capacityToAdd = available.contains(_capacityToAdd)
          ? _capacityToAdd
          : available.first;
      _isAddingCapacity = true;
    });
  }

  void _addSelectedCapacity() {
    final available = _availableCapacities;
    if (available.isEmpty) return;
    final capacity = available.contains(_capacityToAdd)
        ? _capacityToAdd
        : available.first;
    widget.onTableCapacityAdded(capacity);
    final remaining = available.where((item) => item != capacity).toList();
    setState(() {
      _isAddingCapacity = remaining.isNotEmpty;
      if (remaining.isNotEmpty) _capacityToAdd = remaining.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(_debugAssertTableConfigurationInvariant());
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 768;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StepHeader(
                  title: 'Configure Floors & Tables',
                  subtitle:
                      'Set up floors and seating capacity for your restaurant.',
                ),
                const SizedBox(height: 24),
                _SectionBlock(
                  number: '①',
                  title: 'Select number of floors',
                  child: _SectionPanel(
                    child: _FloorDropdown(
                      floorCount: widget.floorCount,
                      onChanged: widget.onFloorCountChanged,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionBlock(
                  number: '②',
                  title: 'Customise your Table Capacity',
                  child: _SectionPanel(
                    child: _CapacitySelector(
                      selectedCapacities: widget.selectedTableCapacities,
                      availableCapacities: _availableCapacities,
                      capacityToAdd: _capacityToAdd,
                      isAddingCapacity: _isAddingCapacity,
                      onStartAdding: _showCapacityPicker,
                      onCapacityToAddChanged: (value) {
                        if (value == null) return;
                        setState(() => _capacityToAdd = value);
                      },
                      onAddCapacity: _addSelectedCapacity,
                      onRemoveCapacity: widget.onTableCapacityRemoved,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionBlock(
                  number: '③',
                  title: 'Enter the Number of Tables',
                  child: _TableMatrix(
                    floorCount: widget.floorCount,
                    selectedCapacities: widget.selectedTableCapacities,
                    tableCountsByFloor: widget.tableCountsByFloor,
                    onTableCountChanged: widget.onTableCountChanged,
                  ),
                ),
                const SizedBox(height: 24),
                _SectionBlock(
                  title: 'Configuration Summary',
                  child: _ConfigurationSummary(
                    floorCount: widget.floorCount,
                    selectedCapacities: widget.selectedTableCapacities,
                    totalTables: totalTables,
                    totalSeats: totalSeats,
                    tableCountsByFloor: widget.tableCountsByFloor,
                  ),
                ),
                if (widget.showValidationError && !widget.canContinue) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.selectedTableCapacities.isEmpty
                        ? 'At least one table capacity is required'
                        : 'At least one table is required',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.errorRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                _FooterActions(
                  isMobile: isMobile,
                  onBack: widget.onBack,
                  onSaveDraft: widget.onSaveDraft,
                  canContinue: widget.canContinue,
                  onContinue: widget.onContinue,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.navyText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({this.number, required this.title, required this.child});

  final String? number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (number != null) ...[
              Text(
                number!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primaryTeal,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.navyText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.child, this.surface});

  final Widget child;
  final Color? surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface ?? AppColors.background,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _FloorDropdown extends StatelessWidget {
  const _FloorDropdown({required this.floorCount, required this.onChanged});

  final int floorCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<int>(
            key: ValueKey(floorCount),
            initialValue: floorCount,
            decoration: const InputDecoration(labelText: 'Number of Floors'),
            items: [
              for (var floor = 1; floor <= 15; floor++)
                DropdownMenuItem<int>(value: floor, child: Text('$floor')),
            ],
            onChanged: (value) {
              if (value == null) return;
              onChanged(value);
            },
          ),
        ),
        Text(
          'Floors selected: $floorCount of 15',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CapacitySelector extends StatelessWidget {
  const _CapacitySelector({
    required this.selectedCapacities,
    required this.availableCapacities,
    required this.capacityToAdd,
    required this.isAddingCapacity,
    required this.onStartAdding,
    required this.onCapacityToAddChanged,
    required this.onAddCapacity,
    required this.onRemoveCapacity,
  });

  final List<int> selectedCapacities;
  final List<int> availableCapacities;
  final int capacityToAdd;
  final bool isAddingCapacity;
  final VoidCallback onStartAdding;
  final ValueChanged<int?> onCapacityToAddChanged;
  final VoidCallback onAddCapacity;
  final ValueChanged<int> onRemoveCapacity;

  @override
  Widget build(BuildContext context) {
    final hasAvailableCapacity = availableCapacities.isNotEmpty;
    final dropdownValue = hasAvailableCapacity
        ? availableCapacities.contains(capacityToAdd)
              ? capacityToAdd
              : availableCapacities.first
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedCapacities.isEmpty)
          Text(
            '(No table capacities configured)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 104),
            child: SingleChildScrollView(
              primary: false,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final capacity in selectedCapacities)
                    _RemovableCapacityChip(
                      capacity: capacity,
                      onRemove: () => onRemoveCapacity(capacity),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 22),
        if (!isAddingCapacity)
          _SecondaryButton(
            label: '+ Add Table Capacity',
            enabled: hasAvailableCapacity,
            onPressed: onStartAdding,
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int>(
                  key: ValueKey(dropdownValue),
                  initialValue: dropdownValue,
                  decoration: const InputDecoration(labelText: 'Capacity'),
                  items: [
                    for (final capacity in availableCapacities)
                      DropdownMenuItem<int>(
                        value: capacity,
                        child: Text('$capacity Top'),
                      ),
                  ],
                  onChanged: hasAvailableCapacity
                      ? onCapacityToAddChanged
                      : null,
                ),
              ),
              _SecondaryButton(
                label: 'Add',
                enabled: hasAvailableCapacity,
                onPressed: onAddCapacity,
              ),
            ],
          ),
      ],
    );
  }
}

class _RemovableCapacityChip extends StatelessWidget {
  const _RemovableCapacityChip({
    required this.capacity,
    required this.onRemove,
  });

  final int capacity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text('$capacity Top'),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close_rounded, size: 18),
      backgroundColor: AppColors.softSurface,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppColors.navyText,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _TableMatrix extends StatefulWidget {
  const _TableMatrix({
    required this.floorCount,
    required this.selectedCapacities,
    required this.tableCountsByFloor,
    required this.onTableCountChanged,
  });

  final int floorCount;
  final List<int> selectedCapacities;
  final List<List<int>> tableCountsByFloor;
  final void Function(int floorIndex, int tableTypeIndex, int value)
  onTableCountChanged;

  @override
  State<_TableMatrix> createState() => _TableMatrixState();
}

class _TableMatrixState extends State<_TableMatrix> {
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedCapacities.isEmpty) {
      return const _SectionPanel(
        child: Text(
          'Add at least one table capacity to configure table counts.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return _SectionPanel(
          child: LayoutBuilder(
            builder: (context, panelConstraints) {
              const floorColumnWidth = 140.0;
              const capacityColumnWidth = 116.0;
              const rowHeight = 72.0;
              const headerHeight = 42.0;
              final capacityWidth =
                  widget.selectedCapacities.length * capacityColumnWidth;
              final availableCapacityWidth =
                  panelConstraints.maxWidth - floorColumnWidth - 12;
              final showScroll = capacityWidth > availableCapacityWidth;

              final capacityColumns = SizedBox(
                width: capacityWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CapacityHeaderRow(
                      capacities: widget.selectedCapacities,
                      columnWidth: capacityColumnWidth,
                      height: headerHeight,
                    ),
                    const Divider(height: 28, color: AppColors.line),
                    for (
                      var floorIndex = 0;
                      floorIndex < widget.floorCount;
                      floorIndex++
                    ) ...[
                      _CapacityCountRow(
                        counts: floorIndex < widget.tableCountsByFloor.length
                            ? widget.tableCountsByFloor[floorIndex]
                            : const [],
                        capacitiesLength: widget.selectedCapacities.length,
                        columnWidth: capacityColumnWidth,
                        height: rowHeight,
                        onChanged: (tableTypeIndex, value) =>
                            widget.onTableCountChanged(
                              floorIndex,
                              tableTypeIndex,
                              value,
                            ),
                      ),
                      if (floorIndex != widget.floorCount - 1)
                        const Divider(height: 28, color: AppColors.line),
                    ],
                  ],
                ),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FrozenFloorColumn(
                        floorCount: widget.floorCount,
                        width: floorColumnWidth,
                        headerHeight: headerHeight,
                        rowHeight: rowHeight,
                      ),
                      const SizedBox(width: 12),
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
      },
    );
  }
}

class _FrozenFloorColumn extends StatelessWidget {
  const _FrozenFloorColumn({
    required this.floorCount,
    required this.width,
    required this.headerHeight,
    required this.rowHeight,
  });

  final int floorCount;
  final double width;
  final double headerHeight;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: headerHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Floor',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const Divider(height: 28, color: AppColors.line),
          for (var floorIndex = 0; floorIndex < floorCount; floorIndex++) ...[
            SizedBox(
              height: rowHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Floor ${floorIndex + 1}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.navyText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (floorIndex != floorCount - 1)
              const Divider(height: 28, color: AppColors.line),
          ],
        ],
      ),
    );
  }
}

class _CapacityHeaderRow extends StatelessWidget {
  const _CapacityHeaderRow({
    required this.capacities,
    required this.columnWidth,
    required this.height,
  });

  final List<int> capacities;
  final double columnWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (final capacity in capacities)
            SizedBox(
              width: columnWidth,
              child: Center(
                child: Text(
                  '$capacity Top',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.mutedText,
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

class _CapacityCountRow extends StatelessWidget {
  const _CapacityCountRow({
    required this.counts,
    required this.capacitiesLength,
    required this.columnWidth,
    required this.height,
    required this.onChanged,
  });

  final List<int> counts;
  final int capacitiesLength;
  final double columnWidth;
  final double height;
  final void Function(int tableTypeIndex, int value) onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var index = 0; index < capacitiesLength; index++)
            SizedBox(
              width: columnWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  child: SizedBox(
                    height: 50,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey(
                        'cap-$index-${index < counts.length ? counts[index] : 0}',
                      ),
                      initialValue: index < counts.length ? counts[index] : 0,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 10,
                        ),
                      ),
                      items: [
                        for (var count = 0; count <= 50; count++)
                          DropdownMenuItem<int>(
                            value: count,
                            child: Text('$count'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        onChanged(index, value);
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConfigurationSummary extends StatelessWidget {
  const _ConfigurationSummary({
    required this.floorCount,
    required this.selectedCapacities,
    required this.totalTables,
    required this.totalSeats,
    required this.tableCountsByFloor,
  });

  final int floorCount;
  final List<int> selectedCapacities;
  final int totalTables;
  final int totalSeats;
  final List<List<int>> tableCountsByFloor;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      surface: AppColors.softSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.summarize_outlined,
                color: AppColors.primaryTeal,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Configuration Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.navyText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _CapacityTotals(
            selectedCapacities: selectedCapacities,
            tableCountsByFloor: tableCountsByFloor,
          ),
          const Divider(height: 36, color: AppColors.line),
          TableConfigurationMatrix(
            title: 'Table Configuration Matrix',
            selectedCapacities: selectedCapacities,
            tableCountsByFloor: tableCountsByFloor,
          ),
          const Divider(height: 36, color: AppColors.line),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = constraints.maxWidth >= 760
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth >= 520
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: tileWidth,
                    height: 102,
                    child: _SummaryTile(label: 'Floors', value: '$floorCount'),
                  ),
                  SizedBox(
                    width: tileWidth,
                    height: 102,
                    child: _SummaryTile(
                      label: 'Total Tables',
                      value: '$totalTables',
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    height: 102,
                    child: _SummaryTile(
                      label: 'Total Seats',
                      value: '$totalSeats',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.navyText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapacityTotals extends StatelessWidget {
  const _CapacityTotals({
    required this.selectedCapacities,
    required this.tableCountsByFloor,
  });

  final List<int> selectedCapacities;
  final List<List<int>> tableCountsByFloor;

  @override
  Widget build(BuildContext context) {
    final visibleItems = <Widget>[];
    for (var index = 0; index < selectedCapacities.length; index++) {
      final total = _capacityTotal(index);
      if (total == 0) continue;
      visibleItems.add(
        SizedBox(
          width: 180,
          height: 72,
          child: _SummaryLine(
            label: '${selectedCapacities[index]} Top',
            value: '$total tables',
          ),
        ),
      );
    }

    return _SummaryGroup(
      title: 'Capacity Totals',
      emptyText: 'No configured table counts yet.',
      children: visibleItems,
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

class _SummaryGroup extends StatelessWidget {
  const _SummaryGroup({
    required this.title,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;

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
        const SizedBox(height: 10),
        if (children.isEmpty)
          Text(
            emptyText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Wrap(spacing: 12, runSpacing: 12, children: children),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 152),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.mutedText,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(
              text: '$label\n',
              style: const TextStyle(
                color: AppColors.navyText,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
            TextSpan(text: value, style: const TextStyle(height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _HorizontalScrollHint extends StatelessWidget {
  const _HorizontalScrollHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        '← Scroll horizontally to view more capacities →',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.mutedText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.isMobile,
    required this.onBack,
    required this.onSaveDraft,
    required this.canContinue,
    required this.onContinue,
  });

  final bool isMobile;
  final VoidCallback onBack;
  final VoidCallback onSaveDraft;
  final bool canContinue;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SecondaryButton(label: 'Back', enabled: true, onPressed: onBack),
          const SizedBox(height: 12),
          _SaveDraftButton(onPressed: onSaveDraft),
          const SizedBox(height: 12),
          _GradientActionButton(
            label: 'Continue to Review',
            enabled: canContinue,
            onPressed: onContinue,
          ),
        ],
      );
    }

    return Row(
      children: [
        _SecondaryButton(label: 'Back', enabled: true, onPressed: onBack),
        const SizedBox(width: 16),
        Flexible(child: _SaveDraftButton(onPressed: onSaveDraft)),
        const Spacer(),
        Flexible(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
              child: _GradientActionButton(
                label: 'Continue to Review',
                enabled: canContinue,
                onPressed: onContinue,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SaveDraftButton extends StatelessWidget {
  const _SaveDraftButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.save_outlined, size: 18),
      label: const Text('Save Draft'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.deepTeal,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryTeal,
        disabledForegroundColor: AppColors.mutedText,
        side: const BorderSide(color: AppColors.primaryTeal),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: enabled ? AppColors.primaryTeal : AppColors.mutedText,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: enabled ? AppColors.progressGradient : null,
            color: enabled ? null : AppColors.softSurface,
            borderRadius: BorderRadius.circular(8),
            border: enabled ? null : Border.all(color: AppColors.line),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: enabled ? AppColors.background : AppColors.mutedText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
