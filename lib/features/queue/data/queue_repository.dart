import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../recommendation/domain/customer_preferences.dart';
import '../../recommendation/domain/recommendation_types.dart';
import '../domain/queue_entry.dart';
import '../domain/queue_status.dart';

abstract class QueueRepository {
  Stream<List<QueueEntry>> watchTodayQueue({
    required String restaurantId,
    required String branchId,
  });

  Future<void> skipCustomer({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
  });

  Future<void> markNoShow({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
  });
}

class FirebaseQueueRepository implements QueueRepository {
  FirebaseQueueRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<QueueEntry>> watchTodayQueue({
    required String restaurantId,
    required String branchId,
  }) {
    return _firestore
        .collection(FirestorePaths.queueEntries(restaurantId, branchId))
        .orderBy('joinedAt')
        .snapshots()
        .map((snapshot) {
          final entries = snapshot.docs
              .map((doc) => QueueEntry.fromMap(doc.id, doc.data()))
              .toList();
          entries.sort(compareQueueEntriesByFifo);
          return entries;
        });
  }

  @override
  Future<void> skipCustomer({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
  }) async {
    await _firestore
        .doc(FirestorePaths.queueEntry(restaurantId, branchId, queueEntryId))
        .update({
          'status': QueueStatus.skipped.wireName,
          'skippedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<void> markNoShow({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
  }) async {
    await _firestore
        .doc(FirestorePaths.queueEntry(restaurantId, branchId, queueEntryId))
        .update({
          'status': QueueStatus.noShow.wireName,
          'noShowAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
}

class MockQueueRepository implements QueueRepository {
  @override
  Stream<List<QueueEntry>> watchTodayQueue({
    required String restaurantId,
    required String branchId,
  }) async* {
    yield [
      QueueEntry(
        id: 'q7',
        tokenNumber: 7,
        tokenCode: 'Q07',
        businessDate: '2026-06-18',
        customerName: 'Alex Johnson',
        phone: '+919876543210',
        partySize: 4,
        partySizeBand: '3-4',
        status: QueueStatus.waiting,
        estimatedWaitMinutes: 15,
        queuePosition: 3,
        extensionUsed: false,
        joinedAt: DateTime.now().subtract(const Duration(minutes: 18)),
        customerPreferences: const CustomerPreferences(
          seatingPreference: SeatingPreference.emptyTableOnly,
        ),
      ),
      QueueEntry(
        id: 'q8',
        tokenNumber: 8,
        tokenCode: 'Q08',
        businessDate: '2026-06-18',
        customerName: 'Nisha Rao',
        phone: '+919812345678',
        partySize: 2,
        partySizeBand: '1-2',
        status: QueueStatus.reserved,
        assignedTableNumber: 'T4',
        estimatedWaitMinutes: 5,
        queuePosition: 1,
        extensionUsed: false,
        joinedAt: DateTime.now().subtract(const Duration(minutes: 24)),
      ),
    ]..sort(compareQueueEntriesByFifo);
  }

  @override
  Future<void> skipCustomer({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
  }) async {}

  @override
  Future<void> markNoShow({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
  }) async {}
}

final queueRepositoryProvider = Provider<QueueRepository>((ref) {
  const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  if (useFirebase) {
    return FirebaseQueueRepository();
  }
  return MockQueueRepository();
});
