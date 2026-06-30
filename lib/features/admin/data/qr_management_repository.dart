import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';

const _hostingOrigin = 'https://ezq-dev-cubiquitous.web.app';

class BranchQrInfo {
  const BranchQrInfo({
    required this.restaurantId,
    required this.branchId,
    required this.branchSlug,
    required this.branchName,
    required this.queueUrl,
    required this.qrSlug,
    required this.pngAssetPath,
    required this.svgAssetPath,
    required this.qrVersion,
    this.generatedAt,
  });

  final String restaurantId;
  final String branchId;
  final String branchSlug;
  final String branchName;
  final String queueUrl;
  final String qrSlug;
  final String pngAssetPath;
  final String svgAssetPath;
  final int qrVersion;
  final DateTime? generatedAt;

  String get pngFileName => '$branchSlug.png';
  String get svgFileName => '$branchSlug.svg';
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
            branchId: snapshot.id,
            data: data,
          );
        });
  }

  BranchQrInfo _fromBranchData({
    required String restaurantId,
    required String branchId,
    required Map<String, dynamic> data,
  }) {
    final branchSlug = data['branchSlug'] as String? ?? branchId;
    final branchName = data['name'] as String? ?? branchSlug;
    final qrSlug = data['qrSlug'] as String? ?? '$restaurantId-$branchSlug';
    final queueUrl =
        data['queueUrl'] as String? ??
        '$_hostingOrigin/customer/$restaurantId/$branchSlug';
    final fallbackPng = 'assets/qr/$restaurantId/$branchSlug/$branchSlug.png';
    final fallbackSvg = 'assets/qr/$restaurantId/$branchSlug/$branchSlug.svg';
    final generatedAtValue = data['qrGeneratedAt'];

    return BranchQrInfo(
      restaurantId: restaurantId,
      branchId: data['branchId'] as String? ?? branchId,
      branchSlug: branchSlug,
      branchName: branchName,
      queueUrl: queueUrl,
      qrSlug: qrSlug,
      pngAssetPath:
          data['qrPngLocalPath'] as String? ??
          data['qrImageUrl'] as String? ??
          fallbackPng,
      svgAssetPath:
          data['qrSvgLocalPath'] as String? ??
          data['qrSvgUrl'] as String? ??
          fallbackSvg,
      qrVersion: data['qrVersion'] as int? ?? 0,
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
