import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../queue/data/queue_repository.dart';
import '../../queue/domain/queue_entry.dart';
import '../../queue/domain/queue_status.dart';
import '../../recommendation/domain/recommendation_types.dart';
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
  String? _spotlightQueueEntryId;
  String? _spotlightLabel;
  String? _secondarySpotlightQueueEntryId;
  String? _secondarySpotlightLabel;
  int _spotlightGeneration = 0;
  QueueEntry? _selectedQueueEntry;
  String? _queueSliceEndEntryId;

  void _handleQueueEntryTap(
    QueueEntry entry,
    List<RestaurantTable> tables,
    int Function(RestaurantTable) occupiedCountFor,
  ) {
    final isDeselecting = _selectedQueueEntry?.id == entry.id;

    setState(() {
      _selectedQueueEntry = isDeselecting ? null : entry;
      _spotlightQueueEntryId = null;
      _spotlightLabel = null;
      _secondarySpotlightQueueEntryId = null;
      _secondarySpotlightLabel = null;
      _queueSliceEndEntryId = null;
      _spotlightGeneration++;
    });

    ScaffoldMessenger.of(context).clearSnackBars();

    if (!isDeselecting) {
      final highlights = _tableHighlightsForQueueEntry(
        tables: tables,
        entry: entry,
        occupiedCountFor: occupiedCountFor,
      );
      if (highlights.isNotEmpty) {
        final highlightedById = {for (final table in tables) table.id: table};
        final tableNumbers = highlights.keys
            .map((id) => highlightedById[id]?.tableNumber)
            .whereType<String>()
            .join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_preferenceLabel(entry)} tables for ${entry.tokenCode}: $tableNumbers',
            ),
          ),
        );
      }
    }
  }

  Map<String, TableHighlightTone> _matchingTableHighlights(
    List<RestaurantTable> tables,
    int Function(RestaurantTable) occupiedCountFor,
  ) {
    final selected = _selectedQueueEntry;
    if (selected == null) return const {};
    return _tableHighlightsForQueueEntry(
      tables: tables,
      entry: selected,
      occupiedCountFor: occupiedCountFor,
    );
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
              final now = DateTime.now();
              final liveQueue =
                  queue
                      .where(
                        (entry) =>
                            entry.status.isLiveQueueVisible &&
                            !entry.hasExceededAutoExpiryAt(now),
                      )
                      .toList()
                    ..sort(compareQueueEntriesByFifo);
              final visibleQueue = _queueVisibleThroughSuggestion(liveQueue);
              final queueById = {for (final entry in queue) entry.id: entry};
              int occupiedFor(RestaurantTable t) =>
                  t.currentQueueEntryId == null
                  ? 0
                  : queueById[t.currentQueueEntryId]?.partySize ?? t.capacity;
              final free = tables
                  .where((table) => table.status == TableStatus.available)
                  .length;
              final availableTables = tables
                  .where((table) => table.status == TableStatus.available)
                  .toList();
              final occupied = tables
                  .where((table) => table.status == TableStatus.occupied)
                  .length;
              final matchingHighlights = _matchingTableHighlights(
                tables,
                occupiedFor,
              );

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
                                  tableHighlightTones: matchingHighlights,
                                  completedPartySizeFor: (table) =>
                                      queueById[table.currentQueueEntryId]
                                          ?.partySize ??
                                      table.capacity,
                                  occupiedSinceFor: (table) =>
                                      _occupiedSinceForTable(table, queueById),
                                  onEmptySpaceTap: _clearTableGridSelection,
                                  onTableRecommendationTap: (table) =>
                                      _spotlightBestPartyForTable(
                                        context: context,
                                        table: table,
                                        occupiedCount: occupiedFor(table),
                                        liveQueue: liveQueue,
                                      ),
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
                                  queue: visibleQueue,
                                  spotlightEntryId: _spotlightQueueEntryId,
                                  spotlightLabel: _spotlightLabel,
                                  secondarySpotlightEntryId:
                                      _secondarySpotlightQueueEntryId,
                                  secondarySpotlightLabel:
                                      _secondarySpotlightLabel,
                                  autoScrollSpotlight: true,
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
                                    nextEntry: _nextQueueEntry(
                                      liveQueue,
                                      entry,
                                    ),
                                  ),
                                  onEntryTapped: (entry) =>
                                      _handleQueueEntryTap(
                                        entry,
                                        tables,
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
                                      tableHighlightTones: matchingHighlights,
                                      completedPartySizeFor: (table) =>
                                          queueById[table.currentQueueEntryId]
                                              ?.partySize ??
                                          table.capacity,
                                      occupiedSinceFor: (table) =>
                                          _occupiedSinceForTable(
                                            table,
                                            queueById,
                                          ),
                                      onEmptySpaceTap: _clearTableGridSelection,
                                      onTableRecommendationTap: (table) =>
                                          _spotlightBestPartyForTable(
                                            context: context,
                                            table: table,
                                            occupiedCount: occupiedFor(table),
                                            liveQueue: liveQueue,
                                          ),
                                      onMealFinished:
                                          (table, initialPartySize) =>
                                              _completeMeal(
                                                context: context,
                                                table: table,
                                                queueEntry:
                                                    queueById[table
                                                        .currentQueueEntryId],
                                                initialPartySize:
                                                    initialPartySize,
                                              ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: pagePadding),
                                SizedBox(
                                  width: 390,
                                  child: SingleChildScrollView(
                                    child: QueuePanel(
                                      queue: visibleQueue,
                                      spotlightEntryId: _spotlightQueueEntryId,
                                      spotlightLabel: _spotlightLabel,
                                      secondarySpotlightEntryId:
                                          _secondarySpotlightQueueEntryId,
                                      secondarySpotlightLabel:
                                          _secondarySpotlightLabel,
                                      autoScrollSpotlight: false,
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
                                        nextEntry: _nextQueueEntry(
                                          liveQueue,
                                          entry,
                                        ),
                                      ),
                                      onEntryTapped: (entry) =>
                                          _handleQueueEntryTap(
                                            entry,
                                            tables,
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
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Seating confirmed',
        barrierColor: Colors.black.withValues(alpha: 0.18),
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _SeatingTransitionOverlay(
            tokenCode: entry.tokenCode,
            customerName: entry.customerName,
            tableNumber: selectedTable.tableNumber,
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: curved, child: child),
          );
        },
      );
      if (!context.mounted) return;
      _clearTableGridSelection();
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
    required QueueEntry? nextEntry,
  }) async {
    await ref
        .read(queueRepositoryProvider)
        .skipCustomer(
          restaurantId: widget.restaurantId,
          branchId: widget.branchId,
          queueEntryId: entry.id,
        );
    if (!context.mounted) return;
    _spotlightQueueEntry(nextEntry, label: _spotlightLabelForNext(nextEntry));
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Queue skipped',
      barrierColor: Colors.black.withValues(alpha: 0.14),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _SkipTransitionOverlay(
          tokenCode: entry.tokenCode,
          customerName: entry.customerName,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
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

  QueueEntry? _nextQueueEntry(List<QueueEntry> liveQueue, QueueEntry entry) {
    final index = liveQueue.indexWhere((candidate) => candidate.id == entry.id);
    if (index == -1) return null;
    if (index + 1 >= liveQueue.length) return null;
    return liveQueue[index + 1];
  }

  DateTime? _occupiedSinceForTable(
    RestaurantTable table,
    Map<String, QueueEntry> queueById,
  ) {
    final entry = queueById[table.currentQueueEntryId];
    return entry?.tableCycleStartAt ??
        entry?.seatedAt ??
        entry?.reservedAt ??
        entry?.joinedAt;
  }

  void _clearTableGridSelection() {
    if (_selectedQueueEntry == null &&
        _spotlightQueueEntryId == null &&
        _secondarySpotlightQueueEntryId == null) {
      return;
    }

    setState(() {
      _selectedQueueEntry = null;
      _spotlightQueueEntryId = null;
      _spotlightLabel = null;
      _secondarySpotlightQueueEntryId = null;
      _secondarySpotlightLabel = null;
      _queueSliceEndEntryId = null;
      _spotlightGeneration++;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  void _spotlightBestPartyForTable({
    required BuildContext context,
    required RestaurantTable table,
    required int occupiedCount,
    required List<QueueEntry> liveQueue,
  }) {
    final openSeats = _openSeatsForTable(table, occupiedCount);
    final recommendations = _bestQueueEntriesForTable(
      openSeats: openSeats,
      liveQueue: liveQueue,
    );
    if (recommendations.isEmpty) {
      _clearTableGridSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No waiting party fits the $openSeats open ${openSeats == 1 ? 'seat' : 'seats'} at ${table.tableNumber}.',
          ),
        ),
      );
      return;
    }

    final bestEntry = recommendations.first;
    final nextEntry = recommendations.length > 1 ? recommendations[1] : null;
    _spotlightQueueEntries(
      bestEntry: bestEntry,
      bestLabel: 'FIFO pick for ${table.tableNumber}',
      nextEntry: nextEntry,
      nextLabel: 'Next FIFO fit for ${table.tableNumber}',
      queueSliceEndEntryId: _queueSliceEndEntryIdFor(
        liveQueue: liveQueue,
        bestEntry: bestEntry,
        nextEntry: nextEntry,
      ),
    );
    final nextText = nextEntry == null ? '' : ' · Next: ${nextEntry.tokenCode}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'FIFO: ${bestEntry.tokenCode} for ${table.tableNumber} ($openSeats open ${openSeats == 1 ? 'seat' : 'seats'})$nextText',
        ),
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  int _openSeatsForTable(RestaurantTable table, int occupiedCount) {
    if (table.status == TableStatus.available) return table.capacity;
    if (table.status != TableStatus.occupied) return 0;
    final openSeats = table.capacity - occupiedCount;
    return openSeats < 0 ? 0 : openSeats;
  }

  List<QueueEntry> _bestQueueEntriesForTable({
    required int openSeats,
    required List<QueueEntry> liveQueue,
  }) {
    final candidates = liveQueue
        .where(
          (entry) =>
              entry.status == QueueStatus.waiting &&
              entry.partySize <= openSeats,
        )
        .toList();
    candidates.sort(compareQueueEntriesByFifo);
    return candidates.take(2).toList();
  }

  String? _queueSliceEndEntryIdFor({
    required List<QueueEntry> liveQueue,
    required QueueEntry bestEntry,
    required QueueEntry? nextEntry,
  }) {
    final bestIndex = liveQueue.indexWhere((entry) => entry.id == bestEntry.id);
    final nextIndex = nextEntry == null
        ? -1
        : liveQueue.indexWhere((entry) => entry.id == nextEntry.id);
    final endIndex = bestIndex > nextIndex ? bestIndex : nextIndex;
    if (endIndex < 0 || endIndex >= liveQueue.length) return null;
    return liveQueue[endIndex].id;
  }

  List<QueueEntry> _queueVisibleThroughSuggestion(List<QueueEntry> liveQueue) {
    final endEntryId = _queueSliceEndEntryId;
    if (endEntryId == null) return liveQueue;
    final endIndex = liveQueue.indexWhere((entry) => entry.id == endEntryId);
    if (endIndex < 0) return liveQueue;
    return liveQueue.take(endIndex + 1).toList();
  }

  String? _spotlightLabelForNext(QueueEntry? nextEntry) {
    if (nextEntry == null) return null;
    return '${nextEntry.tokenCode} is next';
  }

  void _spotlightQueueEntry(QueueEntry? entry, {required String? label}) {
    if (entry == null || !mounted) return;
    final generation = ++_spotlightGeneration;
    setState(() {
      _spotlightQueueEntryId = entry.id;
      _spotlightLabel = label;
      _secondarySpotlightQueueEntryId = null;
      _secondarySpotlightLabel = null;
    });
    Future<void>.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted || generation != _spotlightGeneration) return;
      setState(() {
        _spotlightQueueEntryId = null;
        _spotlightLabel = null;
        _secondarySpotlightQueueEntryId = null;
        _secondarySpotlightLabel = null;
      });
    });
  }

  void _spotlightQueueEntries({
    required QueueEntry bestEntry,
    required String bestLabel,
    required QueueEntry? nextEntry,
    required String? nextLabel,
    required String? queueSliceEndEntryId,
  }) {
    if (!mounted) return;
    _spotlightGeneration++;
    setState(() {
      _selectedQueueEntry = null;
      _spotlightQueueEntryId = bestEntry.id;
      _spotlightLabel = bestLabel;
      _secondarySpotlightQueueEntryId = nextEntry?.id;
      _secondarySpotlightLabel = nextEntry == null ? null : nextLabel;
      _queueSliceEndEntryId = queueSliceEndEntryId;
    });
  }
}

class _SkipTransitionOverlay extends StatefulWidget {
  const _SkipTransitionOverlay({
    required this.tokenCode,
    required this.customerName,
  });

  final String tokenCode;
  final String customerName;

  @override
  State<_SkipTransitionOverlay> createState() => _SkipTransitionOverlayState();
}

class _SkipTransitionOverlayState extends State<_SkipTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sweep;
  late final Animation<double> _badgeScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..forward();
    _sweep = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.72, curve: Curves.easeInOutCubic),
    );
    _badgeScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.48, 0.92, curve: Curves.elasticOut),
    );
    Future<void>.delayed(const Duration(milliseconds: 1450), () {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = _dialogWidth(context, 360);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogWidth,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.accentPurple.withValues(alpha: 0.18),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x246A40D7),
                blurRadius: 34,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 116,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _SkipSweepPainter(progress: _sweep.value),
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _SkipTokenChip(tokenCode: widget.tokenCode),
                          ),
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment(
                                -0.72 + (_sweep.value * 1.44),
                                -0.02,
                              ),
                              child: Transform.rotate(
                                angle: -0.16 + (_sweep.value * 0.32),
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.brandGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x246A40D7),
                                        blurRadius: 18,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.keyboard_double_arrow_right_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 2,
                            top: 28,
                            child: ScaleTransition(
                              scale: _badgeScale,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.softSurface,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: const Text(
                                  'Next up',
                                  style: TextStyle(
                                    color: AppColors.deepTeal,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
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
              const SizedBox(height: 8),
              const Text(
                'Skipped for now',
                style: TextStyle(
                  color: AppColors.navyText,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.customerName} moved out of the active queue',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                  height: 19 / 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkipTokenChip extends StatelessWidget {
  const _SkipTokenChip({required this.tokenCode});

  final String tokenCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 62,
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Center(
        child: Text(
          tokenCode,
          style: const TextStyle(
            color: AppColors.deepTeal,
            fontFamily: 'JetBrains Mono',
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SkipSweepPainter extends CustomPainter {
  const _SkipSweepPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * 0.5;
    final start = Offset(size.width * 0.22, centerY);
    final end = Offset(size.width * 0.74, centerY);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.2,
        size.width * 0.58,
        size.height * 0.8,
        end.dx,
        end.dy,
      );

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = AppColors.line.withValues(alpha: 0.5);
    canvas.drawPath(path, basePaint);

    final metric = path.computeMetrics().first;
    final activePath = metric.extractPath(0, metric.length * progress);
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = AppColors.progressGradient.createShader(Offset.zero & size);
    canvas.drawPath(activePath, activePaint);

    final sparklePaint = Paint()
      ..color = AppColors.accentPurple.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    for (final offset in const [
      Offset(0.42, 0.28),
      Offset(0.52, 0.68),
      Offset(0.64, 0.34),
    ]) {
      canvas.drawCircle(
        Offset(size.width * offset.dx, size.height * offset.dy),
        8 + (progress * 5),
        sparklePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkipSweepPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SeatingTransitionOverlay extends StatefulWidget {
  const _SeatingTransitionOverlay({
    required this.tokenCode,
    required this.customerName,
    required this.tableNumber,
  });

  final String tokenCode;
  final String customerName;
  final String tableNumber;

  @override
  State<_SeatingTransitionOverlay> createState() =>
      _SeatingTransitionOverlayState();
}

class _SeatingTransitionOverlayState extends State<_SeatingTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pathProgress;
  late final Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..forward();
    _pathProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.06, 0.66, curve: Curves.easeInOutCubic),
    );
    _checkScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.58, 0.9, curve: Curves.elasticOut),
    );
    Future<void>.delayed(const Duration(milliseconds: 1650), () {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = _dialogWidth(context, 380);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogWidth,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.55)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2A006687),
                blurRadius: 34,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 138,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _SeatingPathPainter(
                        progress: _pathProgress.value,
                        glow: _controller.value,
                      ),
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _SeatingNode(
                              label: widget.tokenCode,
                              icon: Icons.groups_rounded,
                              gradient: AppColors.primaryGradient,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _SeatingNode(
                              label: widget.tableNumber,
                              icon: Icons.event_seat_rounded,
                              gradient: AppColors.brandGradient,
                            ),
                          ),
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment(
                                -0.8 + (_pathProgress.value * 1.6),
                                -0.02,
                              ),
                              child: Transform.scale(
                                scale: 0.92 + (_controller.value * 0.12),
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryTeal.withValues(
                                          alpha: 0.28,
                                        ),
                                        blurRadius: 18,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: AppColors.deepTeal,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            left: 0,
                            right: 0,
                            child: ScaleTransition(
                              scale: _checkScale,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: AppColors.successGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 28,
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
              const SizedBox(height: 10),
              const Text(
                'Party seated',
                style: TextStyle(
                  color: AppColors.navyText,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.customerName} is heading to ${widget.tableNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                  height: 19 / 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatingNode extends StatelessWidget {
  const _SeatingNode({
    required this.label,
    required this.icon,
    required this.gradient,
  });

  final String label;
  final IconData icon;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x246A40D7),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'JetBrains Mono',
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatingPathPainter extends CustomPainter {
  const _SeatingPathPainter({required this.progress, required this.glow});

  final double progress;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width * 0.24, size.height * 0.46);
    final end = Offset(size.width * 0.76, size.height * 0.46);
    final control = Offset(size.width * 0.5, size.height * 0.04);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.line.withValues(alpha: 0.55);
    canvas.drawPath(path, basePaint);

    final metric = path.computeMetrics().first;
    final activePath = metric.extractPath(0, metric.length * progress);
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = AppColors.progressGradient.createShader(Offset.zero & size);
    canvas.drawPath(activePath, activePaint);

    final pulsePaint = Paint()
      ..color = AppColors.primaryTeal.withValues(alpha: 0.08 + glow * 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.46),
      42,
      pulsePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SeatingPathPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.glow != glow;
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

Map<String, TableHighlightTone> _tableHighlightsForQueueEntry({
  required List<RestaurantTable> tables,
  required QueueEntry entry,
  required int Function(RestaurantTable) occupiedCountFor,
}) {
  final highlights = <String, TableHighlightTone>{};
  if (_prefersEmptyTable(entry)) {
    for (final table in tables) {
      if (table.status != TableStatus.available) continue;
      final extraSeats = table.capacity - entry.partySize;
      if (extraSeats == 0 || extraSeats == 1) {
        highlights[table.id] = TableHighlightTone.best;
      } else if (extraSeats == 2) {
        highlights[table.id] = TableHighlightTone.nextBest;
      }
    }
    return highlights;
  }

  var hasPartialTables = false;
  for (final table in tables) {
    if (table.status != TableStatus.occupied) continue;
    final occupiedCount = occupiedCountFor(table);
    final remaining = table.capacity - occupiedCount;
    if (occupiedCount <= 0 || remaining <= 0) continue;
    hasPartialTables = true;
    if (remaining == entry.partySize) {
      highlights[table.id] = TableHighlightTone.best;
    } else if (remaining > entry.partySize) {
      highlights[table.id] = TableHighlightTone.nextBest;
    }
  }
  if (hasPartialTables) return highlights;

  for (final table in tables) {
    if (table.status != TableStatus.available) continue;
    final extraSeats = table.capacity - entry.partySize;
    if (extraSeats < 0) continue;
    if (extraSeats <= 2) {
      highlights[table.id] = TableHighlightTone.best;
    } else {
      highlights[table.id] = TableHighlightTone.nextBest;
    }
  }
  return highlights;
}

bool _prefersEmptyTable(QueueEntry entry) {
  return entry.customerPreferences?.seatingPreference ==
      SeatingPreference.emptyTableOnly;
}

String _preferenceLabel(QueueEntry entry) {
  return _prefersEmptyTable(entry) ? 'Empty table' : 'Shared seating';
}

List<RestaurantTable> _tablesForParty({
  required List<RestaurantTable> tables,
  required int partySize,
  required int Function(RestaurantTable) occupiedCountFor,
}) {
  return tables.where((t) {
    final remaining = t.capacity - occupiedCountFor(t);
    return remaining >= partySize;
  }).toList()..sort((a, b) {
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
