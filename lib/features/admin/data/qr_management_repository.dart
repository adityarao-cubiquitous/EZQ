import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';

const _hostingOrigin = 'https://ezq-dev-cubiquitous.web.app';

String canonicalCustomerQueueUrl({
  required String restaurantId,
  required String branchId,
}) => '$_hostingOrigin${FirestorePaths.customerRoute(restaurantId, branchId)}';

class BranchQrInfo {
  const BranchQrInfo({
    required this.restaurantId,
    required this.restaurantBranchId,
    required this.restaurantName,
    required this.branchName,
    required this.queueUrl,
    this.restaurantLogoUrl,
    this.generatedAt,
  });

  final String restaurantId;
  final String restaurantBranchId;
  final String restaurantName;
  final String branchName;
  final String queueUrl;
  final String? restaurantLogoUrl;
  final DateTime? generatedAt;

  factory BranchQrInfo.fallback({
    required String restaurantId,
    required String branchId,
  }) {
    return BranchQrInfo(
      restaurantId: restaurantId,
      restaurantBranchId: FirestorePaths.restaurantBranchIdFromRoute(
        restaurantId,
        branchId,
      ),
      restaurantName: restaurantId,
      branchName: branchId,
      queueUrl: canonicalCustomerQueueUrl(
        restaurantId: restaurantId,
        branchId: branchId,
      ),
    );
  }

  String get pngFileName => '$restaurantBranchId.png';
  String get svgFileName => '$restaurantBranchId.svg';
}

class QrManagementRepository {
  QrManagementRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<BranchQrInfo> watchBranchQrInfo({
    required String restaurantId,
    required String branchId,
  }) {
    return _firestore
        .doc(FirestorePaths.branch(restaurantId, branchId))
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (!snapshot.exists || data == null) {
            throw StateError('Branch $branchId was not found.');
          }
          return _fromBranchData(
            restaurantId: restaurantId,
            branchId: branchId,
            data: data,
          );
        });
  }

  BranchQrInfo _fromBranchData({
    required String restaurantId,
    required String branchId,
    required Map<String, dynamic> data,
  }) {
    final restaurantName =
        (data['restaurantName'] as String? ?? '').trim().isNotEmpty
        ? (data['restaurantName'] as String).trim()
        : restaurantId;
    final branchNameValue =
        (data['branchName'] as String? ?? data['name'] as String? ?? '').trim();
    final branchName = branchNameValue.isEmpty ? branchId : branchNameValue;
    final restaurantBranchId = FirestorePaths.restaurantBranchIdFromRoute(
      restaurantId,
      branchId,
    );
    final queueUrl = canonicalCustomerQueueUrl(
      restaurantId: restaurantId,
      branchId: branchId,
    );
    final generatedAtValue = data['qrGeneratedAt'];
    final logoUrl = (data['logoUrl'] as String? ?? '').trim();

    return BranchQrInfo(
      restaurantId: restaurantId,
      restaurantBranchId: restaurantBranchId,
      restaurantName: restaurantName,
      branchName: branchName,
      queueUrl: queueUrl,
      restaurantLogoUrl: logoUrl.isEmpty ? null : logoUrl,
      generatedAt: switch (generatedAtValue) {
        Timestamp timestamp => timestamp.toDate(),
        String isoDate => DateTime.tryParse(isoDate),
        _ => null,
      },
    );
  }
}

final qrManagementRepositoryProvider = Provider<QrManagementRepository>((ref) {
  return QrManagementRepository();
});
