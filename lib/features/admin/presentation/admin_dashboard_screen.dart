import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../queue/data/queue_repository.dart';
import '../../queue/domain/queue_entry.dart';
import '../../tables/data/table_repository.dart';
import '../../tables/domain/restaurant_table.dart';
import '../../tables/domain/table_status.dart';
import '../../tables/presentation/table_grid.dart';
import '../../queue/presentation/queue_panel.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({
    super.key,
    required this.restaurantId,
    required this.branchId,
  });

  final String restaurantId;
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesStream = ref
        .watch(tableRepositoryProvider)
        .watchTables(restaurantId: restaurantId, branchId: branchId);
    final queueStream = ref
        .watch(queueRepositoryProvider)
        .watchTodayQueue(restaurantId: restaurantId, branchId: branchId);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
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
              final free = tables
                  .where((table) => table.status == TableStatus.available)
                  .length;
              final availableTables = tables
                  .where((table) => table.status == TableStatus.available)
                  .toList();
              final occupied = tables
                  .where((table) => table.status == TableStatus.occupied)
                  .length;

              return Column(
                children: [
                  _AdminTopBar(
                    branchName: 'Indiranagar',
                    freeTables: free,
                    occupiedTables: occupied,
                    waitingCount: liveQueue.length,
                    onReports: () =>
                        context.go('/admin/$restaurantId/$branchId/reports'),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 900;
                          if (compact) {
                            return ListView(
                              children: [
                                TableGrid(
                                  tables: tables,
                                  completedPartySizeFor: (table) =>
                                      queueById[table.currentQueueEntryId]
                                          ?.partySize ??
                                      table.capacity,
                                  onMealFinished: (table, initialPartySize) =>
                                      _completeMeal(
                                        context: context,
                                        ref: ref,
                                        table: table,
                                        queueEntry:
                                            queueById[table
                                                .currentQueueEntryId],
                                        initialPartySize: initialPartySize,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                QueuePanel(
                                  queue: liveQueue,
                                  availableTables: availableTables,
                                  onReserve: (entry) => _reserveQueueEntry(
                                    context: context,
                                    ref: ref,
                                    entry: entry,
                                    availableTables: availableTables,
                                  ),
                                  onSkip: (entry) => _skipQueueEntry(
                                    context: context,
                                    ref: ref,
                                    entry: entry,
                                  ),
                                ),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: TableGrid(
                                  tables: tables,
                                  completedPartySizeFor: (table) =>
                                      queueById[table.currentQueueEntryId]
                                          ?.partySize ??
                                      table.capacity,
                                  onMealFinished: (table, initialPartySize) =>
                                      _completeMeal(
                                        context: context,
                                        ref: ref,
                                        table: table,
                                        queueEntry:
                                            queueById[table
                                                .currentQueueEntryId],
                                        initialPartySize: initialPartySize,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              SizedBox(
                                width: 390,
                                child: QueuePanel(
                                  queue: liveQueue,
                                  availableTables: availableTables,
                                  onReserve: (entry) => _reserveQueueEntry(
                                    context: context,
                                    ref: ref,
                                    entry: entry,
                                    availableTables: availableTables,
                                  ),
                                  onSkip: (entry) => _skipQueueEntry(
                                    context: context,
                                    ref: ref,
                                    entry: entry,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _reserveQueueEntry({
    required BuildContext context,
    required WidgetRef ref,
    required QueueEntry entry,
    required List<RestaurantTable> availableTables,
  }) async {
    final selectedTable = await showDialog<RestaurantTable>(
      context: context,
      builder: (context) =>
          _ReserveTableDialog(entry: entry, availableTables: availableTables),
    );
    if (selectedTable == null || !context.mounted) return;

    try {
      await ref
          .read(tableRepositoryProvider)
          .reserveTable(
            restaurantId: restaurantId,
            branchId: branchId,
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
    required WidgetRef ref,
    required QueueEntry entry,
  }) async {
    await ref
        .read(queueRepositoryProvider)
        .skipCustomer(
          restaurantId: restaurantId,
          branchId: branchId,
          queueEntryId: entry.id,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${entry.tokenCode} skipped')));
  }

  Future<void> _completeMeal({
    required BuildContext context,
    required WidgetRef ref,
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
        tokenCode: table.currentTokenCode ?? queueEntry?.tokenCode ?? 'Token',
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
          restaurantId: restaurantId,
          branchId: branchId,
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
  });

  final QueueEntry entry;
  final List<RestaurantTable> availableTables;

  @override
  State<_ReserveTableDialog> createState() => _ReserveTableDialogState();
}

class _ReserveTableDialogState extends State<_ReserveTableDialog> {
  late final List<RestaurantTable> _sortedAvailableTables =
      _sortedTablesForParty();
  late RestaurantTable? _selectedTable = _bestInitialTable();

  List<RestaurantTable> _sortedTablesForParty() {
    final partySize = widget.entry.partySize;
    final tables = widget.availableTables
        .where((table) => table.capacity >= partySize)
        .toList();
    tables.sort((a, b) {
      final capacity = a.capacity.compareTo(b.capacity);
      if (capacity != 0) return capacity;
      final sortOrder = a.sortOrder.compareTo(b.sortOrder);
      if (sortOrder != 0) return sortOrder;
      return a.tableNumber.compareTo(b.tableNumber);
    });
    return tables;
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
    return AlertDialog(
      title: Text('Seat ${widget.entry.tokenCode}'),
      content: SizedBox(
        width: 360,
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
                    borderSide: const BorderSide(color: AppColors.primaryTeal),
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
    final fitLabel = table.capacity == widget.entry.partySize
        ? 'exact fit'
        : 'fits';
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
  late int _completedPartySize = widget.initialPartySize
      .clamp(1, widget.maxPartySize)
      .toInt();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Meal finished'),
      content: SizedBox(
        width: 360,
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
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.primaryTeal, width: 4),
          bottom: BorderSide(color: Color(0x1ABDC8D0)),
        ),
      ),
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
    );
  }
}

class _WalkInDialog extends StatelessWidget {
  const _WalkInDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add walk-in'),
      content: const SizedBox(
        width: 420,
        child: Column(
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

class _TopMetric extends StatelessWidget {
  const _TopMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.mutedText)),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
