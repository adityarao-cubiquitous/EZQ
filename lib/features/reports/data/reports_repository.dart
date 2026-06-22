import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/daily_counter.dart';

abstract class ReportsRepository {
  Stream<DailyCounter> watchDailyCounter({
    required String restaurantId,
    required String branchId,
    required String businessDate,
  });
}

class FirebaseReportsRepository implements ReportsRepository {
  FirebaseReportsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<DailyCounter> watchDailyCounter({
    required String restaurantId,
    required String branchId,
    required String businessDate,
  }) {
    return _firestore
        .doc(FirestorePaths.dailyCounter(restaurantId, branchId, businessDate))
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null) {
            return DailyCounter(
              businessDate: businessDate,
              lastTokenNumber: 0,
              totalJoined: 0,
              totalSeated: 0,
              totalSkipped: 0,
              totalCancelled: 0,
              totalNoShow: 0,
              peakQueueDepth: 0,
            );
          }
          return DailyCounter.fromMap(data);
        });
  }
}

class MockReportsRepository implements ReportsRepository {
  @override
  Stream<DailyCounter> watchDailyCounter({
    required String restaurantId,
    required String branchId,
    required String businessDate,
  }) async* {
    yield DailyCounter(
      businessDate: businessDate,
      lastTokenNumber: 18,
      totalJoined: 18,
      totalSeated: 11,
      totalSkipped: 1,
      totalCancelled: 2,
      totalNoShow: 1,
      peakQueueDepth: 9,
    );
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  if (useFirebase) {
    return FirebaseReportsRepository();
  }
  return MockReportsRepository();
});
