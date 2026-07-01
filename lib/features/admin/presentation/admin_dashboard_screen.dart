import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../auth/data/auth_repository.dart';
import '../../queue/data/queue_repository.dart';
import '../../queue/domain/queue_entry.dart';
import '../../queue/domain/queue_status.dart';
import '../../recommendation/domain/customer_preferences.dart';
import '../../recommendation/domain/recommendation_types.dart';
import '../../tables/data/table_repository.dart';
import '../../tables/domain/restaurant_table.dart';
import '../../tables/domain/table_status.dart';
import '../../tables/presentation/table_grid.dart';
import '../../queue/presentation/queue_panel.dart';
import '../../customer/domain/seating_preference_service.dart';
import 'qr_management_panel.dart';

final _adminWalkInEtaProvider = StreamProvider.autoDispose
    .family<
      SeatingEta,
      ({String restaurantId, String branchId, int partySize})
    >((ref, args) {
      final queueRepository = ref.watch(queueRepositoryProvider);
      final tableRepository = ref.watch(tableRepositoryProvider);
      final controller = StreamController<SeatingEta>();
      List<QueueEntry>? latestQueue;
      List<RestaurantTable>? latestTables;

      void emitIfReady() {
        final queue = latestQueue;
        final tables = latestTables;
        if (queue == null || tables == null || controller.isClosed) return;
        controller.add(
          _adminComputeLiveEta(
            queue: queue,
            tables: tables,
            partySize: args.partySize,
          ),
        );
      }

      final queueSubscription = queueRepository
          .watchTodayQueue(
            restaurantId: args.restaurantId,
            branchId: args.branchId,
          )
          .listen((queue) {
            latestQueue = queue;
            emitIfReady();
          }, onError: controller.addError);

      final tableSubscription = tableRepository
          .watchTables(restaurantId: args.restaurantId, branchId: args.branchId)
          .listen((tables) {
            latestTables = tables;
            emitIfReady();
          }, onError: controller.addError);

      ref.onDispose(() {
        queueSubscription.cancel();
        tableSubscription.cancel();
        controller.close();
      });

      return controller.stream;
    });

SeatingEta _adminComputeLiveEta({
  required List<QueueEntry> queue,
  required List<RestaurantTable> tables,
  required int partySize,
}) {
  final waitingCount = queue
      .where((entry) => entry.status == QueueStatus.waiting)
      .length;
  final sharedReadySlots = tables
      .where(
        (table) => _adminTableCanFitParty(table, partySize, allowShared: true),
      )
      .length;
  final emptyReadySlots = tables
      .where(
        (table) => _adminTableCanFitParty(table, partySize, allowShared: false),
      )
      .length;

  final sharedPosition = (waitingCount + 1 - sharedReadySlots).clamp(0, 99);
  final emptyPosition = (waitingCount + 1 - emptyReadySlots).clamp(0, 99);
  final partySizePremium = partySize > 4 ? 6 : 0;
  final sharedMinutes = sharedPosition == 0
      ? 5
      : (8 + sharedPosition * 5 + partySizePremium).clamp(5, 75).toInt();
  final rawEmptyMinutes = emptyPosition == 0
      ? 6
      : (10 + emptyPosition * 6 + partySizePremium).clamp(6, 100).toInt();
  final emptyMinutes = rawEmptyMinutes <= sharedMinutes
      ? (sharedMinutes + 8).clamp(6, 100).toInt()
      : rawEmptyMinutes;

  return SeatingEta(
    sharedMinutes: sharedMinutes,
    emptyTableMinutes: emptyMinutes,
  );
}

bool _adminTableCanFitParty(
  RestaurantTable table,
  int partySize, {
  required bool allowShared,
}) {
  if (table.status == TableStatus.available) return table.capacity >= partySize;
  if (!allowShared || table.status != TableStatus.occupied) return false;
  final currentPartySize = table.currentPartySize ?? 0;
  if (currentPartySize <= 0) return false;
  return table.capacity - currentPartySize >= partySize;
}

void _showAdminPopup(
  BuildContext context, {
  required String message,
  _AdminPopupTone tone = _AdminPopupTone.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late final OverlayEntry entry;
  var removed = false;

  void removeEntry() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => _AdminPopupToast(
      message: message,
      tone: tone,
      actionLabel: actionLabel,
      onAction: onAction == null
          ? null
          : () {
              removeEntry();
              onAction();
            },
      onDismiss: removeEntry,
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(duration, removeEntry);
}

enum _AdminPopupTone { info, success, warning, error }

class _AdminPopupToast extends StatelessWidget {
  const _AdminPopupToast({
    required this.message,
    required this.tone,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final _AdminPopupTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _AdminPopupTone.info => AppColors.primaryTeal,
      _AdminPopupTone.success => AppColors.successGreen,
      _AdminPopupTone.warning => AppColors.warningOrange,
      _AdminPopupTone.error => AppColors.errorRed,
    };
    final icon = switch (tone) {
      _AdminPopupTone.info => Icons.info_outline_rounded,
      _AdminPopupTone.success => Icons.check_circle_rounded,
      _AdminPopupTone.warning => Icons.warning_amber_rounded,
      _AdminPopupTone.error => Icons.error_outline_rounded,
    };

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 84,
      left: 18,
      right: 18,
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.94, end: 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Opacity(opacity: scale.clamp(0.0, 1.0), child: child),
              );
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: 0.22)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                    const BoxShadow(
                      color: Color(0x1A001E2B),
                      blurRadius: 32,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: AppColors.navyText,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: onAction,
                          style: TextButton.styleFrom(
                            foregroundColor: color,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          child: Text(actionLabel!),
                        ),
                      ],
                      IconButton(
                        tooltip: 'Dismiss',
                        onPressed: onDismiss,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: AppColors.mutedText,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
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
  _TopMetricFilter? _selectedMetricFilter;

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
        _showAdminPopup(
          context,
          message:
              '${_preferenceLabel(entry)} tables for ${entry.tokenCode}: $tableNumbers',
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

  Map<String, TableHighlightTone> _metricTableHighlights({
    required List<RestaurantTable> tables,
    required List<QueueEntry> liveQueue,
    required int Function(RestaurantTable) occupiedCountFor,
  }) {
    return switch (_selectedMetricFilter) {
      _TopMetricFilter.free => {
        for (final table in tables)
          if (table.status == TableStatus.available)
            table.id: TableHighlightTone.free,
      },
      _TopMetricFilter.occupied => {
        for (final table in tables)
          if (table.status == TableStatus.occupied)
            table.id: TableHighlightTone.occupied,
      },
      _TopMetricFilter.waiting =>
        liveQueue.isEmpty
            ? const {}
            : _tableHighlightsForQueueEntry(
                tables: tables,
                entry: liveQueue.first,
                occupiedCountFor: occupiedCountFor,
              ),
      null => const {},
    };
  }

  void _handleMetricTap(_TopMetricFilter filter) {
    final isDeselecting = _selectedMetricFilter == filter;
    setState(() {
      _selectedMetricFilter = isDeselecting ? null : filter;
      _selectedQueueEntry = null;
      _spotlightQueueEntryId = null;
      _spotlightLabel = null;
      _secondarySpotlightQueueEntryId = null;
      _secondarySpotlightLabel = null;
      _spotlightGeneration++;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    if (!isDeselecting) {
      _showAdminPopup(context, message: filter.snackBarLabel);
    }
  }

  Future<void> _logoutAdmin() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (!mounted) return;
      context.go('/admin/login');
    } catch (error) {
      if (!mounted) return;
      _showAdminPopup(
        context,
        message: 'Could not logout: $error',
        tone: _AdminPopupTone.error,
      );
    }
  }

  Future<void> _showQrManagementDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('QR Management'),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          content: SizedBox(
            width: math.min(MediaQuery.sizeOf(context).width - 48, 560.0),
            child: QrManagementPanel(
              restaurantId: widget.restaurantId,
              branchId: widget.branchId,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
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
              final liveQueue =
                  queue
                      .where((entry) => entry.status.isLiveQueueVisible)
                      .toList()
                    ..sort(compareQueueEntriesByFifo);
              final queueById = {for (final entry in queue) entry.id: entry};
              int occupiedFor(RestaurantTable t) =>
                  t.currentQueueEntryId == null
                  ? 0
                  : t.currentPartySize ??
                        queueById[t.currentQueueEntryId]?.partySize ??
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
              final matchingHighlights = _matchingTableHighlights(
                tables,
                occupiedFor,
              );
              final metricHighlights = _metricTableHighlights(
                tables: tables,
                liveQueue: liveQueue,
                occupiedCountFor: occupiedFor,
              );
              final tableHighlights = _selectedMetricFilter == null
                  ? matchingHighlights
                  : metricHighlights;
              final queuePresentation = _queuePresentationForTables(
                liveQueue: liveQueue,
                tables: tables,
                occupiedCountFor: occupiedFor,
              );
              final queueTableRecommendations =
                  _queueTableRecommendationsForEntries(
                    liveQueue: liveQueue,
                    tables: tables,
                    occupiedCountFor: occupiedFor,
                  );

              return SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _AdminTopBar(
                      restaurantId: widget.restaurantId,
                      branchId: widget.branchId,
                      restaurantName: _restaurantDisplayName(
                        widget.restaurantId,
                      ),
                      branchName: 'Indiranagar',
                      freeTables: free,
                      occupiedTables: occupied,
                      waitingCount: liveQueue.length,
                      selectedMetric: _selectedMetricFilter,
                      onMetricTap: _handleMetricTap,
                      onLogout: _logoutAdmin,
                      onQrManagement: _showQrManagementDialog,
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
                                  tableHighlightTones: tableHighlights,
                                  highlightScrollKey:
                                      _selectedQueueEntry?.id ??
                                      _selectedMetricFilter,
                                  completedPartySizeFor: (table) =>
                                      table.currentPartySize ??
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
                                  onUndoReservation: (table) =>
                                      _undoSeatFromTableTile(
                                        context: context,
                                        table: table,
                                      ),
                                ),
                                SizedBox(height: gap),
                                QueuePanel(
                                  queue: queuePresentation.queue,
                                  tableRecommendations:
                                      queueTableRecommendations,
                                  initialVisibleCount:
                                      queuePresentation.initialVisibleCount,
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
                                  onNoAvailableTables: () => _showAdminPopup(
                                    context,
                                    message: 'No available tables right now.',
                                    tone: _AdminPopupTone.warning,
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
                                  onRecommendationSelected:
                                      (entry, recommendation) =>
                                          _assignRecommendedTable(
                                            context: context,
                                            entry: entry,
                                            recommendation: recommendation,
                                            tables: tables,
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
                                      tableHighlightTones: tableHighlights,
                                      highlightScrollKey:
                                          _selectedQueueEntry?.id ??
                                          _selectedMetricFilter,
                                      completedPartySizeFor: (table) =>
                                          table.currentPartySize ??
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
                                      onUndoReservation: (table) =>
                                          _undoSeatFromTableTile(
                                            context: context,
                                            table: table,
                                          ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: pagePadding),
                                SizedBox(
                                  width: 390,
                                  child: SingleChildScrollView(
                                    child: QueuePanel(
                                      queue: queuePresentation.queue,
                                      tableRecommendations:
                                          queueTableRecommendations,
                                      initialVisibleCount:
                                          queuePresentation.initialVisibleCount,
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
                                      onNoAvailableTables: () => _showAdminPopup(
                                        context,
                                        message:
                                            'No available tables right now.',
                                        tone: _AdminPopupTone.warning,
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
                                      onRecommendationSelected:
                                          (entry, recommendation) =>
                                              _assignRecommendedTable(
                                                context: context,
                                                entry: entry,
                                                recommendation: recommendation,
                                                tables: tables,
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

    await _seatQueueEntryAtTable(
      context: context,
      entry: entry,
      table: selectedTable,
    );
  }

  Future<void> _assignRecommendedTable({
    required BuildContext context,
    required QueueEntry entry,
    required QueueTableRecommendation recommendation,
    required List<RestaurantTable> tables,
  }) async {
    final table = _tableById(tables, recommendation.tableId);
    if (table == null) {
      _showAdminPopup(
        context,
        message:
            '${recommendation.tableNumber} is no longer available in this view.',
        tone: _AdminPopupTone.warning,
      );
      return;
    }

    if (recommendation.isShared) {
      _clearTableGridSelection();
      _showAdminPopup(
        context,
        message:
            'Shared seating for ${recommendation.tableNumber} needs multi-party table support. Pick an empty-table recommendation for now.',
        tone: _AdminPopupTone.warning,
      );
      return;
    }

    await _seatQueueEntryAtTable(context: context, entry: entry, table: table);
  }

  RestaurantTable? _tableById(List<RestaurantTable> tables, String tableId) {
    for (final table in tables) {
      if (table.id == tableId) return table;
    }
    return null;
  }

  Future<void> _seatQueueEntryAtTable({
    required BuildContext context,
    required QueueEntry entry,
    required RestaurantTable table,
  }) async {
    try {
      await ref
          .read(tableRepositoryProvider)
          .reserveTable(
            restaurantId: widget.restaurantId,
            branchId: widget.branchId,
            queueEntryId: entry.id,
            tableId: table.id,
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
            tableNumber: table.tableNumber,
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
      _showAdminPopup(
        context,
        message:
            '${entry.tokenCode} seated at ${table.tableNumber}. Table is now occupied.',
        tone: _AdminPopupTone.success,
        actionLabel: 'Undo',
        duration: const Duration(seconds: 7),
        onAction: () {
          unawaited(
            _undoSeatQueueEntryAtTable(
              context: context,
              entry: entry,
              table: table,
            ),
          );
        },
      );
    } catch (error) {
      if (!context.mounted) return;
      _showAdminPopup(
        context,
        message: 'Could not seat party: $error',
        tone: _AdminPopupTone.error,
      );
    }
  }

  Future<void> _undoSeatQueueEntryAtTable({
    required BuildContext context,
    required QueueEntry entry,
    required RestaurantTable table,
  }) async {
    try {
      await ref
          .read(tableRepositoryProvider)
          .undoReservation(
            restaurantId: widget.restaurantId,
            branchId: widget.branchId,
            queueEntryId: entry.id,
            tableId: table.id,
          );
      if (!context.mounted) return;
      _clearTableGridSelection();
      _showAdminPopup(
        context,
        message:
            '${entry.tokenCode} moved back to waiting. ${table.tableNumber} is available again.',
        tone: _AdminPopupTone.success,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showAdminPopup(
        context,
        message: 'Could not undo reservation: $error',
        tone: _AdminPopupTone.error,
      );
    }
  }

  Future<void> _undoSeatFromTableTile({
    required BuildContext context,
    required RestaurantTable table,
  }) async {
    final queueEntryId = table.currentQueueEntryId;
    if (queueEntryId == null) return;
    final tokenCode = table.currentTokenCode ?? 'Party';
    try {
      await ref
          .read(tableRepositoryProvider)
          .undoReservation(
            restaurantId: widget.restaurantId,
            branchId: widget.branchId,
            queueEntryId: queueEntryId,
            tableId: table.id,
          );
      if (!context.mounted) return;
      _clearTableGridSelection();
      _showAdminPopup(
        context,
        message:
            '$tokenCode moved back to waiting. ${table.tableNumber} is available again.',
        tone: _AdminPopupTone.success,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showAdminPopup(
        context,
        message: 'Could not undo reservation: $error',
        tone: _AdminPopupTone.error,
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
    _showAdminPopup(
      context,
      message: '${entry.tokenCode} skipped',
      tone: _AdminPopupTone.success,
    );
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
    _showAdminPopup(
      context,
      message:
          '${table.tableNumber} marked available. $completedPartySize guests finished.',
      tone: _AdminPopupTone.success,
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
        _selectedMetricFilter == null &&
        _spotlightQueueEntryId == null &&
        _secondarySpotlightQueueEntryId == null) {
      return;
    }

    setState(() {
      _selectedQueueEntry = null;
      _selectedMetricFilter = null;
      _spotlightQueueEntryId = null;
      _spotlightLabel = null;
      _secondarySpotlightQueueEntryId = null;
      _secondarySpotlightLabel = null;
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
      table: table,
      openSeats: openSeats,
      liveQueue: liveQueue,
    );
    if (recommendations.isEmpty) {
      _clearTableGridSelection();
      _showAdminPopup(
        context,
        message:
            'No waiting party fits the $openSeats open ${openSeats == 1 ? 'seat' : 'seats'} at ${table.tableNumber}.',
        tone: _AdminPopupTone.warning,
      );
      return;
    }

    final bestEntry = recommendations.first;
    final nextEntry = recommendations.length > 1 ? recommendations[1] : null;
    _spotlightQueueEntries(
      bestEntry: bestEntry,
      bestLabel: 'Best fit for ${table.tableNumber}',
      nextEntry: nextEntry,
      nextLabel: 'Next best fit for ${table.tableNumber}',
    );
    final nextText = nextEntry == null ? '' : ' · Next: ${nextEntry.tokenCode}';
    _showAdminPopup(
      context,
      message:
          'Best fit: ${bestEntry.tokenCode} for ${table.tableNumber} ($openSeats open ${openSeats == 1 ? 'seat' : 'seats'})$nextText',
      duration: const Duration(milliseconds: 2200),
    );
  }

  int _openSeatsForTable(RestaurantTable table, int occupiedCount) {
    if (table.status == TableStatus.available) return table.capacity;
    if (table.status != TableStatus.occupied) return 0;
    final openSeats = table.capacity - occupiedCount;
    return openSeats < 0 ? 0 : openSeats;
  }

  List<QueueEntry> _bestQueueEntriesForTable({
    required RestaurantTable table,
    required int openSeats,
    required List<QueueEntry> liveQueue,
  }) {
    final candidates = liveQueue
        .where(
          (entry) =>
              entry.status == QueueStatus.waiting &&
              entry.partySize <= openSeats &&
              (table.status == TableStatus.available ||
                  !_prefersEmptyTable(entry)),
        )
        .toList();
    candidates.sort((a, b) {
      final aWaste = openSeats - a.partySize;
      final bWaste = openSeats - b.partySize;
      final waste = aWaste.compareTo(bWaste);
      if (waste != 0) return waste;
      return compareQueueEntriesByFifo(a, b);
    });
    return candidates.take(2).toList();
  }

  ({List<QueueEntry> queue, int initialVisibleCount})
  _queuePresentationForTables({
    required List<QueueEntry> liveQueue,
    required List<RestaurantTable> tables,
    required int Function(RestaurantTable) occupiedCountFor,
  }) {
    final actionIds = <String>{};
    for (final table in tables) {
      final openSeats = _openSeatsForTable(table, occupiedCountFor(table));
      if (openSeats <= 0) continue;
      final recommendations = _bestQueueEntriesForTable(
        table: table,
        openSeats: openSeats,
        liveQueue: liveQueue,
      );
      for (final entry in recommendations) {
        actionIds.add(entry.id);
      }
    }

    final selectedId = _selectedQueueEntry?.id;
    if (selectedId != null) actionIds.add(selectedId);
    final spotlightId = _spotlightQueueEntryId;
    if (spotlightId != null) actionIds.add(spotlightId);
    final secondarySpotlightId = _secondarySpotlightQueueEntryId;
    if (secondarySpotlightId != null) actionIds.add(secondarySpotlightId);

    final actionQueue = liveQueue
        .where((entry) => actionIds.contains(entry.id))
        .toList();
    final overflowQueue = liveQueue
        .where((entry) => !actionIds.contains(entry.id))
        .toList();
    final queue = [...actionQueue, ...overflowQueue];
    final fallbackCount = liveQueue.length < 8 ? liveQueue.length : 8;

    return (
      queue: queue,
      initialVisibleCount: actionQueue.isEmpty
          ? fallbackCount
          : actionQueue.length,
    );
  }

  Map<String, List<QueueTableRecommendation>>
  _queueTableRecommendationsForEntries({
    required List<QueueEntry> liveQueue,
    required List<RestaurantTable> tables,
    required int Function(RestaurantTable) occupiedCountFor,
  }) {
    final recommendations = <String, List<QueueTableRecommendation>>{};
    for (final entry in liveQueue) {
      final entryRecommendations = _tableRecommendationsForQueueEntry(
        entry: entry,
        tables: tables,
        occupiedCountFor: occupiedCountFor,
      );
      if (entryRecommendations.isEmpty) continue;
      recommendations[entry.id] = entryRecommendations;
    }
    return recommendations;
  }

  List<QueueTableRecommendation> _tableRecommendationsForQueueEntry({
    required QueueEntry entry,
    required List<RestaurantTable> tables,
    required int Function(RestaurantTable) occupiedCountFor,
  }) {
    final candidates = _tableFitCandidatesForQueueEntry(
      entry: entry,
      tables: tables,
      occupiedCountFor: occupiedCountFor,
    );
    if (candidates.isEmpty) return const [];
    return [
      QueueTableRecommendation(
        tableId: candidates.first.table.id,
        tableNumber: candidates.first.table.tableNumber,
        openSeats: candidates.first.openSeats,
        capacity: candidates.first.table.capacity,
        isShared: candidates.first.isShared,
        tone: QueueTableRecommendationTone.best,
      ),
      if (candidates.length > 1)
        QueueTableRecommendation(
          tableId: candidates[1].table.id,
          tableNumber: candidates[1].table.tableNumber,
          openSeats: candidates[1].openSeats,
          capacity: candidates[1].table.capacity,
          isShared: candidates[1].isShared,
          tone: QueueTableRecommendationTone.nextBest,
        ),
    ];
  }

  List<_TableFitCandidate> _tableFitCandidatesForQueueEntry({
    required QueueEntry entry,
    required List<RestaurantTable> tables,
    required int Function(RestaurantTable) occupiedCountFor,
  }) {
    final candidates = <_TableFitCandidate>[];
    for (final table in tables) {
      if (table.status != TableStatus.available) continue;
      final openSeats = table.capacity;
      if (openSeats < entry.partySize) continue;
      candidates.add(
        _TableFitCandidate(table: table, openSeats: openSeats, isShared: false),
      );
    }

    candidates.sort((a, b) {
      final waste = (a.openSeats - entry.partySize).compareTo(
        b.openSeats - entry.partySize,
      );
      if (waste != 0) return waste;
      final capacity = a.table.capacity.compareTo(b.table.capacity);
      if (capacity != 0) return capacity;
      final sortOrder = a.table.sortOrder.compareTo(b.table.sortOrder);
      if (sortOrder != 0) return sortOrder;
      return a.table.tableNumber.compareTo(b.table.tableNumber);
    });
    return candidates;
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
  }) {
    if (!mounted) return;
    _spotlightGeneration++;
    setState(() {
      _selectedQueueEntry = null;
      _spotlightQueueEntryId = bestEntry.id;
      _spotlightLabel = bestLabel;
      _secondarySpotlightQueueEntryId = nextEntry?.id;
      _secondarySpotlightLabel = nextEntry == null ? null : nextLabel;
    });
  }
}

class _TableFitCandidate {
  const _TableFitCandidate({
    required this.table,
    required this.openSeats,
    required this.isShared,
  });

  final RestaurantTable table;
  final int openSeats;
  final bool isShared;
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
  late final Map<String, QueueTableRecommendationTone> _recommendationTones =
      _recommendationTonesForTables();
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

  Map<String, QueueTableRecommendationTone> _recommendationTonesForTables() {
    if (_sortedAvailableTables.isEmpty) return const {};

    final wasteByTable = {
      for (final table in _sortedAvailableTables)
        table.id:
            table.capacity -
            widget.occupiedCountFor(table) -
            widget.entry.partySize,
    };
    final bestWaste = wasteByTable.values.reduce(math.min);
    int? nextWaste;
    for (final waste in wasteByTable.values.toList()..sort()) {
      if (waste > bestWaste) {
        nextWaste = waste;
        break;
      }
    }

    return {
      for (final entry in wasteByTable.entries)
        if (entry.value == bestWaste)
          entry.key: QueueTableRecommendationTone.best
        else if (nextWaste != null && entry.value == nextWaste)
          entry.key: QueueTableRecommendationTone.nextBest,
    };
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
                      child: _ReserveTableOption(
                        label: _tableOptionLabel(table),
                        tone: _recommendationTones[table.id],
                      ),
                    ),
                ],
                selectedItemBuilder: (context) => [
                  for (final table in _sortedAvailableTables)
                    _ReserveTableOption(
                      label: _tableOptionLabel(table),
                      tone: _recommendationTones[table.id],
                      compact: true,
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
    final openSeats = table.capacity - widget.occupiedCountFor(table);
    final fitLabel = table.capacity == widget.entry.partySize
        ? 'exact fit'
        : 'fits';
    return '${table.tableNumber} · $openSeats seats · $fitLabel';
  }
}

class _ReserveTableOption extends StatelessWidget {
  const _ReserveTableOption({
    required this.label,
    required this.tone,
    this.compact = false,
  });

  final String label;
  final QueueTableRecommendationTone? tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      QueueTableRecommendationTone.best => AppColors.successGreen,
      QueueTableRecommendationTone.nextBest => AppColors.recommendationYellow,
      null => AppColors.mutedText,
    };
    final toneForeground = color.computeLuminance() > 0.56
        ? AppColors.navyText
        : color;
    final toneLabel = switch (tone) {
      QueueTableRecommendationTone.best => 'Best',
      QueueTableRecommendationTone.nextBest => 'Next',
      null => null,
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 10,
        vertical: compact ? 0 : 9,
      ),
      decoration: BoxDecoration(
        color: tone == null || compact
            ? Colors.transparent
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: tone == null || compact
            ? null
            : Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          if (toneLabel != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: compact ? 0.12 : 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                toneLabel,
                style: TextStyle(
                  color: toneForeground,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tone == null ? AppColors.navyText : toneForeground,
                fontWeight: tone == null ? FontWeight.w600 : FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
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
    required this.restaurantId,
    required this.branchId,
    required this.restaurantName,
    required this.branchName,
    required this.freeTables,
    required this.occupiedTables,
    required this.waitingCount,
    required this.selectedMetric,
    required this.onMetricTap,
    required this.onLogout,
    required this.onQrManagement,
    required this.onReports,
  });

  final String restaurantId;
  final String branchId;
  final String restaurantName;
  final String branchName;
  final int freeTables;
  final int occupiedTables;
  final int waitingCount;
  final _TopMetricFilter? selectedMetric;
  final ValueChanged<_TopMetricFilter> onMetricTap;
  final VoidCallback onLogout;
  final VoidCallback onQrManagement;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1100;
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
                      child: _AdminLocationTitle(
                        restaurantName: restaurantName,
                        branchName: branchName,
                        compact: true,
                      ),
                    ),
                    IconButton(
                      tooltip: 'QR management',
                      onPressed: onQrManagement,
                      icon: const Icon(Icons.qr_code_2),
                    ),
                    IconButton(
                      tooltip: 'Daily summary',
                      onPressed: onReports,
                      icon: const Icon(Icons.bar_chart),
                    ),
                    IconButton(
                      tooltip: 'Logout',
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout_rounded),
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
                        selected: selectedMetric == _TopMetricFilter.free,
                        onTap: () => onMetricTap(_TopMetricFilter.free),
                        compact: true,
                      ),
                    ),
                    Expanded(
                      child: _TopMetric(
                        label: 'Occupied',
                        value: occupiedTables,
                        color: AppColors.errorRed,
                        selected: selectedMetric == _TopMetricFilter.occupied,
                        onTap: () => onMetricTap(_TopMetricFilter.occupied),
                        compact: true,
                      ),
                    ),
                    Expanded(
                      child: _TopMetric(
                        label: 'Waiting',
                        value: waitingCount,
                        color: AppColors.accentPurple,
                        selected: selectedMetric == _TopMetricFilter.waiting,
                        onTap: () => onMetricTap(_TopMetricFilter.waiting),
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
                          builder: (context) => _WalkInDialog(
                            restaurantId: restaurantId,
                            branchId: branchId,
                          ),
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
                  _AdminLocationTitle(
                    restaurantName: restaurantName,
                    branchName: branchName,
                  ),
                  const Spacer(),
                  _TopMetric(
                    label: 'Free',
                    value: freeTables,
                    color: AppColors.primaryTeal,
                    selected: selectedMetric == _TopMetricFilter.free,
                    onTap: () => onMetricTap(_TopMetricFilter.free),
                  ),
                  _TopMetric(
                    label: 'Occupied',
                    value: occupiedTables,
                    color: AppColors.errorRed,
                    selected: selectedMetric == _TopMetricFilter.occupied,
                    onTap: () => onMetricTap(_TopMetricFilter.occupied),
                  ),
                  _TopMetric(
                    label: 'Waiting',
                    value: waitingCount,
                    color: AppColors.accentPurple,
                    selected: selectedMetric == _TopMetricFilter.waiting,
                    onTap: () => onMetricTap(_TopMetricFilter.waiting),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 150,
                    child: EzqButton(
                      label: 'Walk-in',
                      icon: Icons.add,
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => _WalkInDialog(
                          restaurantId: restaurantId,
                          branchId: branchId,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'QR management',
                    onPressed: onQrManagement,
                    icon: const Icon(Icons.qr_code_2),
                  ),
                  IconButton(
                    tooltip: 'Daily summary',
                    onPressed: onReports,
                    icon: const Icon(Icons.bar_chart),
                  ),
                  IconButton(
                    tooltip: 'Logout',
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AdminLocationTitle extends StatelessWidget {
  const _AdminLocationTitle({
    required this.restaurantName,
    required this.branchName,
    this.compact = false,
  });

  final String restaurantName;
  final String branchName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            restaurantName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navyText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            branchName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          restaurantName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.navyText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.softSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.65)),
          ),
          child: Text(
            branchName,
            style: const TextStyle(
              color: AppColors.deepTeal,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

String _restaurantDisplayName(String restaurantId) {
  if (restaurantId == AppConstants.demoRestaurantId) return 'The Spice House';
  return restaurantId
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

class _WalkInDialog extends ConsumerStatefulWidget {
  const _WalkInDialog({required this.restaurantId, required this.branchId});

  final String restaurantId;
  final String branchId;

  @override
  ConsumerState<_WalkInDialog> createState() => _WalkInDialogState();
}

class _WalkInDialogState extends ConsumerState<_WalkInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  int _partySize = 4;
  bool _sharePreference = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final now = DateTime.now();
    final eta =
        ref
            .read(
              _adminWalkInEtaProvider((
                restaurantId: widget.restaurantId,
                branchId: widget.branchId,
                partySize: _partySize,
              )),
            )
            .value ??
        ref
            .read(seatingPreferenceServiceProvider)
            .computeEtaEstimate(partySize: _partySize);
    final navigator = Navigator.of(context);
    try {
      final result = await ref
          .read(queueRepositoryProvider)
          .addWalkIn(
            AddWalkInRequest(
              restaurantId: widget.restaurantId,
              branchId: widget.branchId,
              customerName: _nameController.text,
              phone: _phoneController.text,
              partySize: _partySize,
              notes: _notesController.text,
              customerPreferences: CustomerPreferences(
                seatingPreference: _sharePreference
                    ? SeatingPreference.anyAvailable
                    : SeatingPreference.emptyTableOnly,
                acceptedLongerWait: !_sharePreference,
                etaShared: eta.sharedMinutes,
                etaEmptyTable: eta.emptyTableMinutes,
                selectedAt: now,
              ),
            ),
          );
      if (!mounted) return;
      navigator.pop();
      _showAdminPopup(
        navigator.context,
        message: '${result.tokenCode} walk-in added to queue',
        tone: _AdminPopupTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      _showAdminPopup(
        context,
        message: error.toString(),
        tone: _AdminPopupTone.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = _dialogWidth(context, 420);
    final etaAsync = ref.watch(
      _adminWalkInEtaProvider((
        restaurantId: widget.restaurantId,
        branchId: widget.branchId,
        partySize: _partySize,
      )),
    );
    final eta =
        etaAsync.value ??
        ref
            .watch(seatingPreferenceServiceProvider)
            .computeEtaEstimate(partySize: _partySize);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      actionsPadding: EdgeInsets.zero,
      title: const SizedBox.shrink(),
      content: SizedBox(
        width: dialogWidth,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x26BDC8D0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A12A9DC),
                blurRadius: 28,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add walk-in',
                    style: TextStyle(
                      color: AppColors.deepTeal,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _WalkInField(
                  label: 'Guest Name',
                  hintText: 'Enter guest name',
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter guest name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _WalkInField(
                  label: 'Mobile Number (Optional)',
                  hintText: '9876543210',
                  prefixWidget: const Text(
                    '+91  ',
                    style: TextStyle(
                      color: AppColors.navyText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  controller: _phoneController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.number,
                  enableSuggestions: false,
                  autofillHints: const <String>[],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (value) {
                    final phone = value?.trim() ?? '';
                    if (phone.isEmpty) return null;
                    if (phone.length != 10) {
                      return 'Enter a 10 digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _WalkInPartySizeSelector(
                  value: _partySize,
                  onChanged: (value) => setState(() => _partySize = value),
                ),
                const SizedBox(height: 14),
                _WalkInPreferenceSelector(
                  sharePreference: _sharePreference,
                  eta: eta,
                  isLive: etaAsync.hasValue,
                  onChanged: (value) =>
                      setState(() => _sharePreference = value),
                ),
                const SizedBox(height: 16),
                _WalkInField(
                  label: 'Special Notes (Optional)',
                  hintText: 'e.g. High chair, birthday',
                  controller: _notesController,
                  textInputAction: TextInputAction.done,
                  maxLines: 2,
                  onFieldSubmitted: (_) => _submitting ? null : _submit(),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: EzqButton(
                        label: _submitting ? 'Adding...' : 'Add to queue',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _submitting ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WalkInField extends StatelessWidget {
  const _WalkInField({
    required this.label,
    required this.hintText,
    required this.controller,
    this.prefixWidget,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.enableSuggestions = true,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.maxLines = 1,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final Widget? prefixWidget;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool enableSuggestions;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF3E484F),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          enableSuggestions: enableSuggestions,
          autocorrect: enableSuggestions,
          autofillHints: autofillHints,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          maxLines: maxLines,
          style: const TextStyle(
            color: AppColors.deepTeal,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixWidget == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 18, right: 2),
                    child: Center(widthFactor: 1, child: prefixWidget),
                  ),
            prefixIconConstraints: prefixWidget == null
                ? null
                : const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 15,
            ),
          ),
        ),
      ],
    );
  }
}

class _WalkInPartySizeSelector extends StatelessWidget {
  const _WalkInPartySizeSelector({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Party Size',
            style: TextStyle(
              color: Color(0xFF3E484F),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DropdownButtonFormField<int>(
          initialValue: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(Icons.groups_outlined),
          ),
          items: [
            for (final option in List<int>.generate(20, (index) => index + 1))
              DropdownMenuItem<int>(
                value: option,
                child: Text(option == 1 ? '1 person' : '$option people'),
              ),
          ],
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ],
    );
  }
}

class _WalkInPreferenceSelector extends StatelessWidget {
  const _WalkInPreferenceSelector({
    required this.sharePreference,
    required this.eta,
    required this.isLive,
    required this.onChanged,
  });

  final bool sharePreference;
  final SeatingEta eta;
  final bool isLive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Seating preference',
                style: TextStyle(
                  color: Color(0xFF3E484F),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isLive) const _WalkInLiveEtaDot(),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _WalkInEtaCard(
                label: 'Non-shared',
                minutes: eta.emptyTableMinutes,
                active: !sharePreference,
                leading: Icons.event_seat_rounded,
                onTap: () => onChanged(false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _WalkInEtaCard(
                label: 'Share',
                minutes: eta.sharedMinutes,
                active: sharePreference,
                leading: Icons.groups_2_rounded,
                onTap: () => onChanged(!sharePreference),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          sharePreference
              ? 'Can be seated with another party when seats are available.'
              : 'Default: seat only when a separate table is available.',
          style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
        ),
      ],
    );
  }
}

class _WalkInEtaCard extends StatelessWidget {
  const _WalkInEtaCard({
    required this.label,
    required this.minutes,
    required this.active,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final int minutes;
  final bool active;
  final IconData leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primaryTeal : AppColors.mutedText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.softSurface : AppColors.softerSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? AppColors.primaryTeal.withValues(alpha: 0.55)
                  : AppColors.line.withValues(alpha: 0.55),
              width: active ? 1.5 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primaryTeal.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    active
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 5),
                  Icon(leading, size: 15, color: color),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? AppColors.deepTeal
                            : AppColors.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Text(
                  '~$minutes min',
                  key: ValueKey(minutes),
                  style: TextStyle(
                    color: active ? AppColors.navyText : AppColors.mutedText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalkInLiveEtaDot extends StatelessWidget {
  const _WalkInLiveEtaDot();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Live',
          style: TextStyle(
            color: AppColors.mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 5),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.successGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x6610B981),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: SizedBox(width: 7, height: 7),
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
  final candidates = <_TableFitCandidate>[];
  for (final table in tables) {
    if (table.status != TableStatus.available) continue;
    final openSeats = table.capacity;
    if (openSeats < entry.partySize) continue;
    candidates.add(
      _TableFitCandidate(table: table, openSeats: openSeats, isShared: false),
    );
  }
  if (candidates.isEmpty) return const {};
  candidates.sort((a, b) {
    final waste = (a.openSeats - entry.partySize).compareTo(
      b.openSeats - entry.partySize,
    );
    if (waste != 0) return waste;
    final capacity = a.table.capacity.compareTo(b.table.capacity);
    if (capacity != 0) return capacity;
    final sortOrder = a.table.sortOrder.compareTo(b.table.sortOrder);
    if (sortOrder != 0) return sortOrder;
    return a.table.tableNumber.compareTo(b.table.tableNumber);
  });
  final bestWaste = candidates.first.openSeats - entry.partySize;
  int? nextWaste;
  for (final candidate in candidates) {
    final waste = candidate.openSeats - entry.partySize;
    if (waste <= bestWaste) continue;
    nextWaste = waste;
    break;
  }
  return {
    for (final candidate in candidates)
      if (candidate.openSeats - entry.partySize == bestWaste)
        candidate.table.id: TableHighlightTone.best
      else if (nextWaste != null &&
          candidate.openSeats - entry.partySize == nextWaste)
        candidate.table.id: TableHighlightTone.nextBest,
  };
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
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final int value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = switch (label) {
      'Free' => Icons.event_seat_rounded,
      'Occupied' => Icons.table_restaurant_rounded,
      _ => Icons.hourglass_top_rounded,
    };
    final foreground = selected ? Colors.white : color;
    final background = selected ? color : Colors.white;
    final tintedBackground = color.withValues(alpha: 0.11);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 5),
      child: Material(
        color: background,
        elevation: selected ? 2 : 0,
        shadowColor: color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withValues(alpha: 0.14),
          highlightColor: color.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(
              minWidth: compact ? 70 : 92,
              minHeight: compact ? 54 : 60,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 13,
              vertical: compact ? 7 : 9,
            ),
            decoration: BoxDecoration(
              color: selected ? color : tintedBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.26)
                    : color.withValues(alpha: 0.62),
                width: selected ? 2 : 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? color.withValues(alpha: 0.24)
                      : color.withValues(alpha: 0.10),
                  blurRadius: selected ? 18 : 11,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 16 : 17, color: foreground),
                SizedBox(width: compact ? 6 : 7),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground.withValues(alpha: 0.82),
                          fontSize: compact ? 10 : 12,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 3),
                      Text(
                        '$value',
                        style: TextStyle(
                          color: foreground,
                          fontSize: compact ? 20 : 23,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) ...[
                  SizedBox(width: compact ? 5 : 7),
                  Icon(
                    Icons.check_circle_rounded,
                    size: compact ? 14 : 16,
                    color: foreground.withValues(alpha: 0.92),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _TopMetricFilter {
  free,
  occupied,
  waiting;

  String get snackBarLabel => switch (this) {
    _TopMetricFilter.free => 'Highlighting available tables',
    _TopMetricFilter.occupied => 'Highlighting occupied tables',
    _TopMetricFilter.waiting =>
      'Highlighting tables for the next waiting party',
  };
}
