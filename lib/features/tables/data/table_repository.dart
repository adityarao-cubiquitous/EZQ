import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../queue/domain/queue_status.dart';
import '../domain/floor_table_map.dart';
import '../domain/restaurant_floor.dart';
import '../domain/restaurant_table.dart';
import '../domain/table_status.dart';

abstract class TableRepository {
  Stream<List<RestaurantTable>> watchTables({
    required String restaurantId,
    required String branchId,
  });

  Stream<RestaurantFloorTableMap> watchFloorTableMap({
    required String restaurantId,
    required String branchId,
  });

  Future<void> reserveTable({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String tableId,
  });

  Future<void> undoReservation({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String tableId,
  });

  Future<void> updateTableStatus({
    required String restaurantId,
    required String branchId,
    required String tableId,
    required TableStatus status,
  });

  Future<void> completeMeal({
    required String restaurantId,
    required String branchId,
    required String tableId,
    required String queueEntryId,
    required int completedPartySize,
  });
}

class FirebaseTableRepository implements TableRepository {
  FirebaseTableRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<RestaurantTable>> watchTables({
    required String restaurantId,
    required String branchId,
  }) {
    return _firestore
        .collection(FirestorePaths.tables(restaurantId, branchId))
        .snapshots()
        .map((snapshot) {
          final tables = snapshot.docs
              .map((doc) => RestaurantTable.fromMap(doc.id, doc.data()))
              .toList();
          tables.sort(_compareTablesByCapacity);
          return tables;
        });
  }

  @override
  Stream<RestaurantFloorTableMap> watchFloorTableMap({
    required String restaurantId,
    required String branchId,
  }) {
    final controller = StreamController<RestaurantFloorTableMap>();
    List<RestaurantFloor>? latestFloors;
    List<RestaurantTable>? latestTables;

    void emitIfReady() {
      final floors = latestFloors;
      final tables = latestTables;
      if (floors == null || tables == null || controller.isClosed) return;
      controller.add(_buildFloorTableMap(floors: floors, tables: tables));
    }

    final floorSubscription = _firestore
        .collection(FirestorePaths.floors(restaurantId, branchId))
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => RestaurantFloor.fromMap(doc.id, doc.data()))
                  .toList()
                ..sort(_compareFloors),
        )
        .listen((floors) {
          latestFloors = floors;
          emitIfReady();
        }, onError: controller.addError);

    final tableSubscription =
        watchTables(restaurantId: restaurantId, branchId: branchId).listen((
          tables,
        ) {
          latestTables = tables;
          emitIfReady();
        }, onError: controller.addError);

    controller.onCancel = () async {
      await floorSubscription.cancel();
      await tableSubscription.cancel();
    };

    return controller.stream;
  }

  @override
  Future<void> reserveTable({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String tableId,
  }) async {
    final tableRef = _firestore.doc(
      FirestorePaths.table(restaurantId, branchId, tableId),
    );
    final entryRef = _firestore.doc(
      FirestorePaths.queueEntry(restaurantId, branchId, queueEntryId),
    );
    final counterRef = _firestore.doc(
      FirestorePaths.dailyCounter(
        restaurantId,
        branchId,
        DateTimeUtils.businessDate(),
      ),
    );

    await _firestore.runTransaction<void>((transaction) async {
      final tableSnapshot = await transaction.get(tableRef);
      final entrySnapshot = await transaction.get(entryRef);
      if (!tableSnapshot.exists || !entrySnapshot.exists) {
        throw StateError('Table or queue entry not found.');
      }
      final status = TableStatus.fromWireName(
        tableSnapshot.data()?['status'] as String?,
      );
      if (status != TableStatus.available) {
        throw StateError('Selected table is no longer available.');
      }
      final tableData = tableSnapshot.data();
      final previousCycleEndAt =
          tableData?['lastCycleEndAt'] ?? tableData?['lastCompletedAt'];
      final cycleStartAt = previousCycleEndAt ?? FieldValue.serverTimestamp();
      final cycleSource = previousCycleEndAt == null
          ? 'first_reservation'
          : 'previous_completion';
      final assignedTableNumber =
          (tableData?['displayTableName'] as String?) ??
          (tableData?['tableNumber'] as String? ?? '');
      final tokenCode = entrySnapshot.data()?['tokenCode'] as String? ?? '';
      final partySize = entrySnapshot.data()?['partySize'] as int? ?? 0;
      final assignedAt = FieldValue.serverTimestamp();
      transaction.update(tableRef, {
        'status': TableStatus.occupied.wireName,
        'currentQueueEntryId': queueEntryId,
        'currentTokenCode': tokenCode,
        'currentPartySize': partySize,
        'reservedAt': assignedAt,
        'occupiedAt': assignedAt,
        'currentCycleStartAt': cycleStartAt,
        'currentCycleSource': cycleSource,
        'updatedAt': assignedAt,
      });
      transaction.update(entryRef, {
        'status': QueueStatus.seated.wireName,
        'assignedTableId': tableId,
        'assignedTableNumber': assignedTableNumber,
        'reservedAt': assignedAt,
        'seatedAt': assignedAt,
        'tableCycleStartAt': cycleStartAt,
        'tableCycleSource': cycleSource,
        'updatedAt': assignedAt,
      });
      transaction.set(counterRef, {
        'totalSeated': FieldValue.increment(1),
        'updatedAt': assignedAt,
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<void> undoReservation({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String tableId,
  }) async {
    final tableRef = _firestore.doc(
      FirestorePaths.table(restaurantId, branchId, tableId),
    );
    final entryRef = _firestore.doc(
      FirestorePaths.queueEntry(restaurantId, branchId, queueEntryId),
    );
    final counterRef = _firestore.doc(
      FirestorePaths.dailyCounter(
        restaurantId,
        branchId,
        DateTimeUtils.businessDate(),
      ),
    );

    await _firestore.runTransaction<void>((transaction) async {
      final tableSnapshot = await transaction.get(tableRef);
      final entrySnapshot = await transaction.get(entryRef);
      if (!tableSnapshot.exists || !entrySnapshot.exists) {
        throw StateError('Table or queue entry not found.');
      }

      final tableData = tableSnapshot.data();
      final entryData = entrySnapshot.data();
      final tableQueueEntryId = tableData?['currentQueueEntryId'] as String?;
      final assignedTableId = entryData?['assignedTableId'] as String?;
      final entryStatus = QueueStatus.fromWireName(
        entryData?['status'] as String?,
      );

      if (tableQueueEntryId != queueEntryId ||
          assignedTableId != tableId ||
          entryStatus != QueueStatus.seated) {
        throw StateError('This reservation can no longer be undone.');
      }

      final undoneAt = FieldValue.serverTimestamp();
      transaction.update(tableRef, {
        'status': TableStatus.available.wireName,
        'currentQueueEntryId': null,
        'currentTokenCode': null,
        'currentPartySize': null,
        'reservedAt': null,
        'occupiedAt': null,
        'currentCycleStartAt': null,
        'currentCycleSource': null,
        'updatedAt': undoneAt,
      });
      transaction.update(entryRef, {
        'status': QueueStatus.waiting.wireName,
        'assignedTableId': null,
        'assignedTableNumber': null,
        'reservedAt': null,
        'seatedAt': null,
        'tableCycleStartAt': null,
        'tableCycleSource': null,
        'reservationUndoAt': undoneAt,
        'updatedAt': undoneAt,
      });
      transaction.set(counterRef, {
        'totalSeated': FieldValue.increment(-1),
        'updatedAt': undoneAt,
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<void> updateTableStatus({
    required String restaurantId,
    required String branchId,
    required String tableId,
    required TableStatus status,
  }) async {
    await _firestore
        .doc(FirestorePaths.table(restaurantId, branchId, tableId))
        .update({
          'status': status.wireName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<void> completeMeal({
    required String restaurantId,
    required String branchId,
    required String tableId,
    required String queueEntryId,
    required int completedPartySize,
  }) async {
    final tableRef = _firestore.doc(
      FirestorePaths.table(restaurantId, branchId, tableId),
    );
    final entryRef = _firestore.doc(
      FirestorePaths.queueEntry(restaurantId, branchId, queueEntryId),
    );
    final counterRef = _firestore.doc(
      FirestorePaths.dailyCounter(
        restaurantId,
        branchId,
        DateTimeUtils.businessDate(),
      ),
    );

    await _firestore.runTransaction<void>((transaction) async {
      final tableSnapshot = await transaction.get(tableRef);
      final entrySnapshot = await transaction.get(entryRef);
      if (!tableSnapshot.exists) {
        throw StateError('Table not found.');
      }
      if (!entrySnapshot.exists) {
        debugPrint(
          '[TABLE_REPO] Completing meal for tableId=$tableId with missing '
          'queueEntryId=$queueEntryId. Freeing table and skipping queue update.',
        );
      }
      final tableData = tableSnapshot.data();
      final entryData = entrySnapshot.data();
      final cycleStartAt =
          tableData?['currentCycleStartAt'] ??
          entryData?['tableCycleStartAt'] ??
          tableData?['reservedAt'] ??
          tableData?['occupiedAt'];
      final completionTimestamp = FieldValue.serverTimestamp();
      transaction.update(tableRef, {
        'status': TableStatus.available.wireName,
        'currentQueueEntryId': null,
        'currentTokenCode': null,
        'currentPartySize': null,
        'reservedAt': null,
        'occupiedAt': null,
        'cleaningStartedAt': null,
        'lastCompletedQueueEntryId': queueEntryId,
        'lastCompletedPartySize': completedPartySize,
        'lastCompletedAt': completionTimestamp,
        'lastCycleStartAt': cycleStartAt,
        'lastCycleEndAt': completionTimestamp,
        'currentCycleStartAt': null,
        'currentCycleSource': null,
        'updatedAt': completionTimestamp,
      });
      if (entrySnapshot.exists) {
        transaction.update(entryRef, {
          'status': QueueStatus.completed.wireName,
          'completedAt': completionTimestamp,
          'completedPartySize': completedPartySize,
          'tableCycleStartAt': cycleStartAt,
          'tableCycleEndAt': completionTimestamp,
          'updatedAt': completionTimestamp,
        });
      }
      transaction.set(counterRef, {
        'totalCompleted': FieldValue.increment(1),
        'totalGuestsCompleted': FieldValue.increment(completedPartySize),
        'updatedAt': completionTimestamp,
      }, SetOptions(merge: true));
    });
  }
}

RestaurantFloorTableMap _buildFloorTableMap({
  required List<RestaurantFloor> floors,
  required List<RestaurantTable> tables,
}) {
  final floorById = {for (final floor in floors) floor.floorId: floor};
  final tablesByFloorId = {
    for (final floor in floors) floor.floorId: <RestaurantTable>[],
  };

  for (final table in tables) {
    final floorId = table.floorId.trim();
    if (floorId.isEmpty) {
      debugPrint(
        '[TABLE_REPO] Rejected table tableId=${table.id} '
        'floorId="$floorId" reason=missing_floorId',
      );
      continue;
    }
    if (!floorById.containsKey(floorId)) {
      debugPrint(
        '[TABLE_REPO] Rejected table tableId=${table.id} '
        'floorId="$floorId" reason=floorId_not_in_provisioned_floors '
        'validFloorIds=${floorById.keys.join(',')}',
      );
      continue;
    }
    tablesByFloorId[floorId]!.add(table);
  }

  return RestaurantFloorTableMap(
    sections: [
      for (final floor in floors)
        RestaurantFloorTableSection(
          floor: floor,
          tables: tablesByFloorId[floor.floorId]!
            ..sort(_compareTablesByCapacity),
        ),
    ],
  );
}

int _compareFloors(RestaurantFloor a, RestaurantFloor b) {
  final displayOrder = a.displayOrder.compareTo(b.displayOrder);
  if (displayOrder != 0) return displayOrder;
  return a.floorId.compareTo(b.floorId);
}

int _compareTablesByCapacity(RestaurantTable a, RestaurantTable b) {
  final capacity = a.capacity.compareTo(b.capacity);
  if (capacity != 0) return capacity;
  final sortOrder = a.sortOrder.compareTo(b.sortOrder);
  if (sortOrder != 0) return sortOrder;
  return a.tableNumber.compareTo(b.tableNumber);
}

class MockTableRepository implements TableRepository {
  @override
  Stream<RestaurantFloorTableMap> watchFloorTableMap({
    required String restaurantId,
    required String branchId,
  }) async* {
    const floor = RestaurantFloor(
      id: 'F1',
      floorId: 'F1',
      floorName: 'Floor 1',
      displayOrder: 1,
      tableCount: 4,
      seatCount: 16,
    );
    final tables = await watchTables(
      restaurantId: restaurantId,
      branchId: branchId,
    ).first;
    yield RestaurantFloorTableMap(
      sections: [RestaurantFloorTableSection(floor: floor, tables: tables)],
    );
  }

  @override
  Stream<List<RestaurantTable>> watchTables({
    required String restaurantId,
    required String branchId,
  }) async* {
    yield const [
      RestaurantTable(
        id: 't1',
        tableNumber: 'T1',
        displayTableName: 'F1-T1',
        capacity: 2,
        tableType: '2-top',
        section: 'main',
        floorId: 'F1',
        status: TableStatus.available,
        sortOrder: 1,
      ),
      RestaurantTable(
        id: 't2',
        tableNumber: 'T2',
        displayTableName: 'F1-T2',
        capacity: 4,
        tableType: '4-top',
        section: 'main',
        floorId: 'F1',
        status: TableStatus.reserved,
        currentTokenCode: 'Q08',
        currentQueueEntryId: 'q8',
        sortOrder: 2,
      ),
      RestaurantTable(
        id: 't3',
        tableNumber: 'T3',
        displayTableName: 'F1-T3',
        capacity: 4,
        tableType: '4-top',
        section: 'patio',
        floorId: 'F1',
        status: TableStatus.occupied,
        currentTokenCode: 'Q05',
        currentQueueEntryId: 'q5',
        sortOrder: 3,
      ),
      RestaurantTable(
        id: 't4',
        tableNumber: 'T4',
        displayTableName: 'F1-T4',
        capacity: 6,
        tableType: '6-top',
        section: 'family',
        floorId: 'F1',
        status: TableStatus.available,
        sortOrder: 4,
      ),
    ];
  }

  @override
  Future<void> reserveTable({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String tableId,
  }) async {}

  @override
  Future<void> undoReservation({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String tableId,
  }) async {}

  @override
  Future<void> updateTableStatus({
    required String restaurantId,
    required String branchId,
    required String tableId,
    required TableStatus status,
  }) async {}

  @override
  Future<void> completeMeal({
    required String restaurantId,
    required String branchId,
    required String tableId,
    required String queueEntryId,
    required int completedPartySize,
  }) async {}
}

final tableRepositoryProvider = Provider<TableRepository>((ref) {
  const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  if (useFirebase) {
    return FirebaseTableRepository();
  }
  return MockTableRepository();
});
