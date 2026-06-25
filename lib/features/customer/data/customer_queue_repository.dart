import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/validators.dart';
import '../../queue/domain/queue_entry.dart';
import '../../queue/domain/queue_status.dart';
import '../../recommendation/domain/customer_preferences.dart';

class JoinQueueRequest {
  const JoinQueueRequest({
    required this.restaurantId,
    required this.branchId,
    required this.customerName,
    required this.phone,
    required this.partySize,
    this.notes,
    this.appSource = 'web',
    this.customerPreferences,
  });

  final String restaurantId;
  final String branchId;
  final String customerName;
  final String phone;
  final int partySize;
  final String? notes;
  final String appSource;
  final CustomerPreferences? customerPreferences;
}

class JoinQueueResult {
  const JoinQueueResult({
    required this.queueEntryId,
    required this.tokenNumber,
    required this.tokenCode,
    required this.estimatedWaitMinutes,
  });

  final String queueEntryId;
  final int tokenNumber;
  final String tokenCode;
  final int estimatedWaitMinutes;
}

abstract class CustomerQueueRepository {
  Future<JoinQueueResult> joinQueue(JoinQueueRequest request);

  Stream<QueueEntry> watchQueueEntry({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
  });

  Future<void> markOnTheWay({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String phone,
  });

  Future<void> extendHold({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String phone,
  });

  Future<void> cancelQueueEntry({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String phone,
  });
}

class FirebaseCustomerQueueRepository implements CustomerQueueRepository {
  FirebaseCustomerQueueRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<JoinQueueResult> joinQueue(JoinQueueRequest request) async {
    final businessDate = DateTimeUtils.businessDate();
    final phone = PhoneUtils.normalizeIndiaMobile(request.phone);
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

    return _firestore.runTransaction<JoinQueueResult>((transaction) async {
      final branchSnapshot = await transaction.get(branchRef);
      if (!branchSnapshot.exists ||
          branchSnapshot.data()?['isActive'] != true) {
        throw StateError('This restaurant branch is not accepting joins yet.');
      }

      final counterSnapshot = await transaction.get(counterRef);
      final nextToken =
          ((counterSnapshot.data()?['lastTokenNumber'] as int?) ?? 0) + 1;
      final tokenCode = 'Q${nextToken.toString().padLeft(2, '0')}';
      final estimatedWaitMinutes = 10 + ((nextToken - 1) * 5).clamp(0, 40);

      transaction.set(counterRef, {
        'businessDate': businessDate,
        'lastTokenNumber': nextToken,
        'updatedAt': FieldValue.serverTimestamp(),
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
        'sessionType': 'web_guest',
        'appSource': request.appSource,
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

      return JoinQueueResult(
        queueEntryId: queueRef.id,
        tokenNumber: nextToken,
        tokenCode: tokenCode,
        estimatedWaitMinutes: estimatedWaitMinutes,
      );
    });
  }

  @override
  Stream<QueueEntry> watchQueueEntry({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
  }) {
    return _firestore
        .doc(FirestorePaths.queueEntry(restaurantId, branchId, queueEntryId))
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null) {
            throw StateError('Queue entry not found');
          }
          return QueueEntry.fromMap(snapshot.id, data);
        });
  }

  @override
  Future<void> markOnTheWay({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String phone,
  }) async {
    await _updateOwnedQueueEntry(
      restaurantId: restaurantId,
      branchId: branchId,
      queueEntryId: queueEntryId,
      phone: phone,
      data: {
        'status': QueueStatus.onTheWay.wireName,
        'onTheWayAt': FieldValue.serverTimestamp(),
      },
    );
  }

  @override
  Future<void> extendHold({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String phone,
  }) async {
    await _updateOwnedQueueEntry(
      restaurantId: restaurantId,
      branchId: branchId,
      queueEntryId: queueEntryId,
      phone: phone,
      data: {
        'extensionUsed': true,
        'estimatedWaitMinutes': FieldValue.increment(5),
      },
    );
  }

  @override
  Future<void> cancelQueueEntry({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String phone,
  }) async {
    await _updateOwnedQueueEntry(
      restaurantId: restaurantId,
      branchId: branchId,
      queueEntryId: queueEntryId,
      phone: phone,
      data: {
        'status': QueueStatus.cancelled.wireName,
        'cancelledAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> _updateOwnedQueueEntry({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String phone,
    required Map<String, Object?> data,
  }) async {
    final entryRef = _firestore.doc(
      FirestorePaths.queueEntry(restaurantId, branchId, queueEntryId),
    );
    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(entryRef);
      if (!snapshot.exists) {
        throw StateError('Queue entry not found.');
      }
      if (snapshot.data()?['phone'] != PhoneUtils.normalizeIndiaMobile(phone)) {
        throw StateError('Phone number does not match this queue entry.');
      }
      transaction.update(entryRef, {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

class MockCustomerQueueRepository implements CustomerQueueRepository {
  final _controller = StreamController<QueueEntry>.broadcast();
  QueueEntry _entry = QueueEntry(
    id: 'demo-entry',
    tokenNumber: 7,
    tokenCode: 'Q07',
    businessDate: DateTimeUtils.businessDate(),
    customerName: 'Alex Johnson',
    phone: '+919876543210',
    partySize: 4,
    partySizeBand: '3-4',
    status: QueueStatus.waiting,
    estimatedWaitMinutes: 15,
    queuePosition: 3,
    extensionUsed: false,
    joinedAt: DateTime.now().subtract(const Duration(minutes: 7)),
  );

  @override
  Future<JoinQueueResult> joinQueue(JoinQueueRequest request) async {
    _entry = QueueEntry(
      id: 'demo-entry',
      tokenNumber: 7,
      tokenCode: 'Q07',
      businessDate: DateTimeUtils.businessDate(),
      customerName: request.customerName.trim(),
      phone: PhoneUtils.normalizeIndiaMobile(request.phone),
      partySize: request.partySize,
      partySizeBand: Validators.partySizeBand(request.partySize),
      notes: request.notes?.trim().isEmpty ?? true ? null : request.notes,
      status: QueueStatus.waiting,
      estimatedWaitMinutes: 15,
      queuePosition: 3,
      extensionUsed: false,
      joinedAt: DateTime.now(),
      customerPreferences: request.customerPreferences,
    );
    _controller.add(_entry);
    return const JoinQueueResult(
      queueEntryId: 'demo-entry',
      tokenNumber: 7,
      tokenCode: 'Q07',
      estimatedWaitMinutes: 15,
    );
  }

  @override
  Stream<QueueEntry> watchQueueEntry({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
  }) async* {
    yield _entry;
    yield* _controller.stream;
  }

  @override
  Future<void> markOnTheWay({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String phone,
  }) async {
    _entry = _entry.copyWith(status: QueueStatus.onTheWay);
    _controller.add(_entry);
  }

  @override
  Future<void> extendHold({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String phone,
  }) async {}

  @override
  Future<void> cancelQueueEntry({
    required String restaurantId,
    required String branchId,
    required String queueEntryId,
    required String phone,
  }) async {
    _entry = _entry.copyWith(status: QueueStatus.cancelled);
    _controller.add(_entry);
  }
}

final customerQueueRepositoryProvider = Provider<CustomerQueueRepository>((
  ref,
) {
  const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  if (useFirebase) {
    return FirebaseCustomerQueueRepository();
  }
  return MockCustomerQueueRepository();
});

typedef QueueEntryWatchArgs = ({
  String restaurantId,
  String branchId,
  String queueEntryId,
});

final queueEntryProvider =
    StreamProvider.family<QueueEntry, QueueEntryWatchArgs>((ref, args) {
      final repository = ref.watch(customerQueueRepositoryProvider);
      return repository.watchQueueEntry(
        restaurantId: args.restaurantId,
        branchId: args.branchId,
        queueEntryId: args.queueEntryId,
      );
    });
