import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../queue/data/queue_repository.dart';
import '../../queue/domain/queue_entry.dart';
import '../../tables/data/table_repository.dart';
import '../../tables/domain/restaurant_table.dart';
import '../../tables/domain/table_status.dart';
import '../../tables/presentation/table_grid.dart';
import '../../queue/presentation/queue_panel.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.restaurantId,
    required this.branchId,
  });

  final String restaurantId;
  final String branchId;

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  QueueEntry? _selectedQueueEntry;

  void _handleQueueEntryTap(
    QueueEntry entry,
    List<RestaurantTable> availableTables,
    int Function(RestaurantTable) occupiedCountFor,
  ) {
    final isDeselecting = _selectedQueueEntry?.id == entry.id;

    setState(() {
      _selectedQueueEntry = isDeselecting ? null : entry;
    });

    ScaffoldMessenger.of(context).clearSnackBars();

    if (!isDeselecting) {
      final matching = _tablesForParty(
        tables: availableTables,
        partySize: entry.partySize,
        occupiedCountFor: occupiedCountFor,
      );
      if (matching.isNotEmpty) {
        final tableNumbers = matching.map((t) => t.tableNumber).join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Best fit tables for ${entry.tokenCode}: $tableNumbers',
            ),
          ),
        );
      }
    }
  }

  Set<String> _matchingTableIds(
    List<RestaurantTable> availableTables,
    int Function(RestaurantTable) occupiedCountFor,
  ) {
    final selected = _selectedQueueEntry;
    if (selected == null) return const {};
    return _tablesForParty(
      tables: availableTables,
      partySize: selected.partySize,
      occupiedCountFor: occupiedCountFor,
    ).map((t) => t.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final tablesStream = ref
        .watch(tableRepositoryProvider)
        .watchTables(
          restaurantId: widget.restaurantId,
          branchId: widget.branchId,
        );
    final queueStream = ref
        .watch(queueRepositoryProvider)
        .watchTodayQueue(
          restaurantId: widget.restaurantId,
          branchId: widget.branchId,
        );

    return Scaffold(
      backgroundColor: AppColors.softerSurface,
      body: StreamBuilder(
        stream: tablesStream,
        builder: (context, tablesSnapshot) {
          return StreamBuilder(
            stream: queueStream,
            builder: (context, queueSnapshot) {
              final tables = tablesSnapshot.data ?? const [];
              final queue = queueSnapshot.data ?? const [];
              final liveQueue = queue
                  .where((entry) => entry.status.isLiveQueueVisible)
                  .toList();
              final queueById = {for (final entry in queue) entry.id: entry};
              int occupiedFor(RestaurantTable t) =>
                  t.currentQueueEntryId == null
                      ? 0
                      : queueById[t.currentQueueEntryId]?.partySize ??
                          t.capacity;
              final free = tables
                  .where((table) => table.status == TableStatus.available)
                  .length;
              final availableTables = tables
                  .where((table) => table.status == TableStatus.available)
                  .toList();
              final occupied = tables
                  .where((table) => table.status == TableStatus.occupied)
                  .length;
              final matchingIds = _matchingTableIds(availableTables, occupiedFor);

              return SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _AdminTopBar(
                      branchName: 'Indiranagar',
                      freeTables: free,
                      occupiedTables: occupied,
                      waitingCount: liveQueue.length,
                      onReports: () => context.go(
                        '/admin/${widget.restaurantId}/${widget.branchId}/reports',
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 960;
                          final phone = Responsive.isCompact(context);
                          final pagePadding = phone ? 12.0 : 24.0;
                          final gap = phone ? 12.0 : 16.0;
                          if (compact) {
                            return ListView(
                              padding: EdgeInsets.all(pagePadding),
                              children: [
                                TableGrid(
                                  tables: tables,
                                  matchingTableIds: matchingIds,
                                  completedPartySizeFor: (table) =>
                                      queueById[table.currentQueueEntryId]
                                          ?.partySize ??
                                      table.capacity,
                                  onMealFinished: (table, initialPartySize) =>
                                      _completeMeal(
                                        context: context,
                                        table: table,
                                        queueEntry:
                                            queueById[table
                                                .currentQueueEntryId],
                                        initialPartySize: initialPartySize,
                                      ),
                                ),
                                SizedBox(height: gap),
                                QueuePanel(
                                  queue: liveQueue,
                                  availableTables: availableTables,
                                  onReserve: (entry) => _reserveQueueEntry(
                                    context: context,
                                    entry: entry,
                                    availableTables: availableTables,
                                    occupiedCountFor: occupiedFor,
                                  ),
                                  onSkip: (entry) => _skipQueueEntry(
                                    context: context,
                                    entry: entry,
                                  ),
                                  onEntryTapped: (entry) =>
                                      _handleQueueEntryTap(
                                        entry,
                                        availableTables,
                                        occupiedFor,
                                      ),
                                ),
                              ],
                            );
                          }
                          return Padding(
                            padding: EdgeInsets.all(pagePadding),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: SingleChildScrollView(
                                    child: TableGrid(
                                      tables: tables,
                                      matchingTableIds: matchingIds,
                                      completedPartySizeFor: (table) =>
                                          queueById[table.currentQueueEntryId]
                                              ?.partySize ??
                                          table.capacity,
                                      onMealFinished:
                                          (table, initialPartySize) =>
                                              _completeMeal(
                                                context: context,
                                                table: table,
                                                queueEntry:
                                                    queueById[table
                                                        .currentQueueEntryId],
                                                initialPartySize: initialPartySize,
                                              ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: pagePadding),
                                SizedBox(
                                  width: 390,
                                  child: SingleChildScrollView(
                                    child: QueuePanel(
                                      queue: liveQueue,
                                      availableTables: availableTables,
                                      onReserve: (entry) => _reserveQueueEntry(
                                        context: context,
                                        entry: entry,
                                        availableTables: availableTables,
                                        occupiedCountFor: occupiedFor,
                                      ),
                                      onSkip: (entry) => _skipQueueEntry(
                                        context: context,
                                        entry: entry,
                                      ),
                                      onEntryTapped: (entry) =>
                                          _handleQueueEntryTap(
                                            entry,
                                            availableTables,
                                            occupiedFor,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _reserveQueueEntry({
    required BuildContext context,
    required QueueEntry entry,
    required List<RestaurantTable> availableTables,
    required int Function(RestaurantTable) occupiedCountFor,
  }) async {
    final selectedTable = await showDialog<RestaurantTable>(
      context: context,
      builder: (context) => _ReserveTableDialog(
        entry: entry,
        availableTables: availableTables,
        occupiedCountFor: occupiedCountFor,
      ),
    );
    if (selectedTable == null || !context.mounted) return;

    try {
      await ref
          .read(tableRepositoryProvider)
          .reserveTable(
            restaurantId: widget.restaurantId,
            branchId: widget.branchId,
            queueEntryId: entry.id,
            tableId: selectedTable.id,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${entry.tokenCode} seated at ${selectedTable.tableNumber}. Table is now occupied.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reserve table: $error')),
      );
    }
  }

  Future<void> _skipQueueEntry({
    required BuildContext context,
    required QueueEntry entry,
  }) async {
    await ref
        .read(queueRepositoryProvider)
        .skipCustomer(
          restaurantId: widget.restaurantId,
          branchId: widget.branchId,
          queueEntryId: entry.id,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${entry.tokenCode} skipped')));
  }

  Future<void> _completeMeal({
    required BuildContext context,
    required RestaurantTable table,
    required QueueEntry? queueEntry,
    required int initialPartySize,
  }) async {
    final queueEntryId = table.currentQueueEntryId;
    if (queueEntryId == null) return;

    final completedPartySize = await showDialog<int>(
      context: context,
      builder: (context) => _MealFinishedDialog(
        tableNumber: table.tableNumber,
        tokenCode:
            table.currentTokenCode ?? queueEntry?.tokenCode ?? 'Token',
        initialPartySize: initialPartySize,
        maxPartySize: [
          table.capacity,
          queueEntry?.partySize ?? 0,
          initialPartySize,
        ].reduce((value, element) => value > element ? value : element),
      ),
    );
    if (completedPartySize == null || !context.mounted) return;

    await ref
        .read(tableRepositoryProvider)
        .completeMeal(
          restaurantId: widget.restaurantId,
          branchId: widget.branchId,
          tableId: table.id,
          queueEntryId: queueEntryId,
          completedPartySize: completedPartySize,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${table.tableNumber} marked available. $completedPartySize guests finished.',
        ),
      ),
    );
  }
}

class _ReserveTableDialog extends StatefulWidget {
  const _ReserveTableDialog({
    required this.entry,
    required this.availableTables,
    required this.occupiedCountFor,
  });

  final QueueEntry entry;
  final List<RestaurantTable> availableTables;
  final int Function(RestaurantTable) occupiedCountFor;

  @override
  State<_ReserveTableDialog> createState() => _ReserveTableDialogState();
}

class _ReserveTableDialogState extends State<_ReserveTableDialog> {
  late final List<RestaurantTable> _sortedAvailableTables =
      _sortedTablesForParty();
  late RestaurantTable? _selectedTable = _bestInitialTable();

  List<RestaurantTable> _sortedTablesForParty() {
    return _tablesForParty(
      tables: widget.availableTables,
      partySize: widget.entry.partySize,
      occupiedCountFor: widget.occupiedCountFor,
    );
  }

  RestaurantTable? _bestInitialTable() {
    if (_sortedAvailableTables.isEmpty) return null;
    return _sortedAvailableTables.first;
  }

  void _submit() {
    final selectedTable = _selectedTable;
    if (selectedTable == null) return;
    Navigator.of(context).pop(selectedTable);
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = _dialogWidth(context, 360);
    return AlertDialog(
      title: Text('Seat ${widget.entry.tokenCode}'),
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.entry.customerName} · Party ${widget.entry.partySize}',
              style: const TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose table',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_sortedAvailableTables.isEmpty)
              _NoAvailableTablesNotice(partySize: widget.entry.partySize)
            else
              DropdownButtonFormField<RestaurantTable>(
                initialValue: _selectedTable,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.event_seat),
                  helperText: 'Only available tables that fit are shown.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.primaryTeal),
                  ),
                ),
                items: [
                  for (final table in _sortedAvailableTables)
                    DropdownMenuItem<RestaurantTable>(
                      value: table,
                      child: Text(_tableOptionLabel(table)),
                    ),
                ],
                onChanged: (table) {
                  if (table != null) setState(() => _selectedTable = table);
                },
              ),
            const SizedBox(height: 12),
            const Text(
              'When confirmed, the table becomes occupied and the customer sees their assigned table.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _selectedTable == null ? null : _submit,
          icon: const Icon(Icons.event_seat),
          label: const Text('Seat now'),
        ),
      ],
    );
  }

  String _tableOptionLabel(RestaurantTable table) {
    final fitLabel =
        table.capacity == widget.entry.partySize ? 'exact fit' : 'fits';
    return '${table.tableNumber} · ${table.capacity} seats · $fitLabel';
  }
}

class _NoAvailableTablesNotice extends StatelessWidget {
  const _NoAvailableTablesNotice({required this.partySize});

  final int partySize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33F59E0B)),
      ),
      child: const Text(
        'No available table can fit this party right now.',
        style: TextStyle(
          color: AppColors.navyText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MealFinishedDialog extends StatefulWidget {
  const _MealFinishedDialog({
    required this.tableNumber,
    required this.tokenCode,
    required this.initialPartySize,
    required this.maxPartySize,
  });

  final String tableNumber;
  final String tokenCode;
  final int initialPartySize;
  final int maxPartySize;

  @override
  State<_MealFinishedDialog> createState() => _MealFinishedDialogState();
}

class _MealFinishedDialogState extends State<_MealFinishedDialog> {
  late int _completedPartySize =
      widget.initialPartySize.clamp(1, widget.maxPartySize).toInt();

  @override
  Widget build(BuildContext context) {
    final dialogWidth = _dialogWidth(context, 360);
    return AlertDialog(
      title: const Text('Meal finished'),
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.tableNumber} · ${widget.tokenCode}'),
            const SizedBox(height: 20),
            const Text(
              'Guests who finished',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Decrease guests',
                  onPressed: _completedPartySize == 1
                      ? null
                      : () => setState(() => _completedPartySize--),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_completedPartySize',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Increase guests',
                  onPressed: _completedPartySize == widget.maxPartySize
                      ? null
                      : () => setState(() => _completedPartySize++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_completedPartySize),
          icon: const Icon(Icons.check),
          label: const Text('Mark finished'),
        ),
      ],
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.branchName,
    required this.freeTables,
    required this.occupiedTables,
    required this.waitingCount,
    required this.onReports,
  });

  final String branchName;
  final int freeTables;
  final int occupiedTables;
  final int waitingCount;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);
    final tablet = Responsive.isTablet(context);
    final horizontalPadding = compact ? 14.0 : 32.0;
    return Container(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        compact ? 12 : 0,
        horizontalPadding,
        compact ? 12 : 0,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.primaryTeal, width: 4),
          bottom: BorderSide(color: Color(0x1ABDC8D0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x12006687),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const BrandMark(size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'EZQ',
                      style: TextStyle(
                        color: AppColors.deepTeal,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        branchName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Daily summary',
                      onPressed: onReports,
                      icon: const Icon(Icons.bar_chart),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TopMetric(
                        label: 'Free',
                        value: freeTables,
                        color: AppColors.primaryTeal,
                        compact: true,
                      ),
                    ),
                    Expanded(
                      child: _TopMetric(
                        label: 'Occupied',
                        value: occupiedTables,
                        color: AppColors.errorRed,
                        compact: true,
                      ),
                    ),
                    Expanded(
                      child: _TopMetric(
                        label: 'Waiting',
                        value: waitingCount,
                        color: AppColors.accentPurple,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 112,
                      child: EzqButton(
                        label: 'Walk-in',
                        icon: Icons.add,
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => const _WalkInDialog(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : SizedBox(
              height: tablet ? 72 : 76,
              child: Row(
                children: [
                  const BrandMark(size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'EZQ',
                    style: TextStyle(
                      color: AppColors.deepTeal,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    branchName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _TopMetric(
                    label: 'Free',
                    value: freeTables,
                    color: AppColors.primaryTeal,
                  ),
                  _TopMetric(
                    label: 'Occupied',
                    value: occupiedTables,
                    color: AppColors.errorRed,
                  ),
                  _TopMetric(
                    label: 'Waiting',
                    value: waitingCount,
                    color: AppColors.accentPurple,
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 150,
                    child: EzqButton(
                      label: 'Walk-in',
                      icon: Icons.add,
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => const _WalkInDialog(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Daily summary',
                    onPressed: onReports,
                    icon: const Icon(Icons.bar_chart),
                  ),
                ],
              ),
            ),
    );
  }
}

class _WalkInDialog extends StatelessWidget {
  const _WalkInDialog();

  @override
  Widget build(BuildContext context) {
    final dialogWidth = _dialogWidth(context, 420);
    return AlertDialog(
      title: const Text('Add walk-in'),
      content: SizedBox(
        width: dialogWidth,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'Name')),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'Phone')),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'Party size')),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'Notes')),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Walk-in added to queue')),
            );
          },
          child: const Text('Add to queue'),
        ),
      ],
    );
  }
}

double _dialogWidth(BuildContext context, double maxWidth) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final availableWidth = screenWidth - 48;
  if (availableWidth < 280) return availableWidth;
  return availableWidth < maxWidth ? availableWidth : maxWidth;
}

List<RestaurantTable> _tablesForParty({
  required List<RestaurantTable> tables,
  required int partySize,
  required int Function(RestaurantTable) occupiedCountFor,
}) {
  return tables
      .where((t) {
        final remaining = t.capacity - occupiedCountFor(t);
        return remaining >= partySize;
      })
      .toList()
    ..sort((a, b) {
      final ra = a.capacity - occupiedCountFor(a);
      final rb = b.capacity - occupiedCountFor(b);
      final c = ra.compareTo(rb);
      if (c != 0) return c;
      final s = a.sortOrder.compareTo(b.sortOrder);
      if (s != 0) return s;
      return a.tableNumber.compareTo(b.tableNumber);
    });
}

class _TopMetric extends StatelessWidget {
  const _TopMetric({
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
  });

  final String label;
  final int value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: compact ? 11 : 14,
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
