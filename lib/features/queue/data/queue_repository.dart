import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/validators.dart';
import '../../recommendation/domain/customer_preferences.dart';
import '../domain/queue_entry.dart';
import '../domain/queue_status.dart';

class AddWalkInRequest {
  const AddWalkInRequest({
    required this.restaurantId,
    required this.branchId,
    required this.customerName,
    required this.phone,
    required this.partySize,
    this.notes,
    this.customerPreferences,
  });

  final String restaurantId;
  final String branchId;
  final String customerName;
  final String phone;
  final int partySize;
  final String? notes;
  final CustomerPreferences? customerPreferences;
}

class AddWalkInResult {
  const AddWalkInResult({
    required this.queueEntryId,
    required this.tokenNumber,
    required this.tokenCode,
  });

  final String queueEntryId;
  final int tokenNumber;
  final String tokenCode;
}

abstract class QueueRepository {
  Stream<List<QueueEntry>> watchTodayQueue({
    required String restaurantId,
    required String branchId,
  });

  Future<AddWalkInResult> addWalkIn(AddWalkInRequest request);

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
  Future<AddWalkInResult> addWalkIn(AddWalkInRequest request) async {
    final businessDate = DateTimeUtils.businessDate();
    final phone = request.phone.trim().isEmpty
        ? ''
        : PhoneUtils.normalizeIndiaMobile(request.phone);
    final partySizeBand = Validators.partySizeBand(request.partySize);
    final branchRef = _firestore.doc(
      FirestorePaths.branch(request.restaurantId, request.branchId),
    );
    final counterRef = _firestore.doc(
      FirestorePaths.dailyCounter(
        request.restaurantId,
        request.branchId,
        businessDate,
      ),
    );
    final queueRef = _firestore
        .collection(
          FirestorePaths.queueEntries(request.restaurantId, request.branchId),
        )
        .doc();

    return _firestore.runTransaction<AddWalkInResult>((transaction) async {
      final branchSnapshot = await transaction.get(branchRef);
      if (!branchSnapshot.exists ||
          branchSnapshot.data()?['isActive'] != true) {
        throw StateError('This restaurant branch is not accepting walk-ins.');
      }

      final counterSnapshot = await transaction.get(counterRef);
      final nextToken =
          ((counterSnapshot.data()?['lastTokenNumber'] as int?) ?? 0) + 1;
      final tokenCode = 'Q${nextToken.toString().padLeft(2, '0')}';
      final estimatedWaitMinutes = 10 + ((nextToken - 1) * 5).clamp(0, 40);

      transaction.set(counterRef, {
        'businessDate': businessDate,
        'lastTokenNumber': nextToken,
        'totalJoined': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
        if (!counterSnapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(queueRef, {
        'tokenNumber': nextToken,
        'tokenCode': tokenCode,
        'businessDate': businessDate,
        'customerName': request.customerName.trim(),
        'phone': phone,
        'partySize': request.partySize,
        'partySizeBand': partySizeBand,
        'notes': request.notes?.trim().isEmpty ?? true
            ? null
            : request.notes?.trim(),
        'customerId': null,
        'sessionType': 'admin_created',
        'appSource': 'admin_walkin',
        'status': QueueStatus.waiting.wireName,
        'assignedTableId': null,
        'assignedTableNumber': null,
        'estimatedWaitMinutes': estimatedWaitMinutes,
        'queuePosition': nextToken,
        'extensionUsed': false,
        'customerPreferences': request.customerPreferences?.toMap(),
        'joinedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return AddWalkInResult(
        queueEntryId: queueRef.id,
        tokenNumber: nextToken,
        tokenCode: tokenCode,
      );
    });
  }

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
          final businessDate = DateTimeUtils.businessDate();
          final entries = snapshot.docs
              .map((doc) => QueueEntry.fromMap(doc.id, doc.data()))
              .where((entry) => entry.businessDate == businessDate)
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
  Future<AddWalkInResult> addWalkIn(AddWalkInRequest request) async {
    return const AddWalkInResult(
      queueEntryId: 'walk-in-demo',
      tokenNumber: 9,
      tokenCode: 'Q09',
    );
  }

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
