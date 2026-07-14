import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';

const _hostingOrigin = 'https://ezq-dev-cubiquitous.web.app';
const _qrAssetRoot = 'assets/qr';

class BranchQrInfo {
  const BranchQrInfo({
    required this.restaurantId,
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
    required String branchSlug,
  }) {
    return _firestore
        .doc(FirestorePaths.branch(restaurantId, branchSlug))
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (!snapshot.exists || data == null) {
            throw StateError('Branch $branchSlug was not found.');
          }
          return _fromBranchData(
            restaurantId: restaurantId,
            branchSlug: snapshot.id,
            data: data,
          );
        });
  }

  BranchQrInfo _fromBranchData({
    required String restaurantId,
    required String branchSlug,
    required Map<String, dynamic> data,
  }) {
    final branchName = data['name'] as String? ?? branchSlug;
    final restaurantBranchId = FirestorePaths.restaurantBranchIdFromRoute(
      restaurantId,
      branchSlug,
    );
    final storedQrSlug = (data['qrSlug'] as String? ?? '').trim();
    final qrSlug = storedQrSlug.isEmpty ? restaurantBranchId : storedQrSlug;
    final queueUrl = _canonicalQueueUrl(
      data['queueUrl'] as String?,
      restaurantBranchId,
    );
    final fallbackPng =
        '$_qrAssetRoot/$restaurantBranchId/$restaurantBranchId.png';
    final fallbackSvg =
        '$_qrAssetRoot/$restaurantBranchId/$restaurantBranchId.svg';
    final generatedAtValue = data['qrGeneratedAt'];

    return BranchQrInfo(
      restaurantId: restaurantId,
      branchSlug: restaurantBranchId,
      branchName: branchName,
      queueUrl: queueUrl,
      qrSlug: qrSlug,
      pngAssetPath:
          _canonicalAssetPath(data['qrPngLocalPath'] as String?) ??
          data['qrImageUrl'] as String? ??
          fallbackPng,
      svgAssetPath:
          _canonicalAssetPath(data['qrSvgLocalPath'] as String?) ??
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

  String _canonicalQueueUrl(String? storedQueueUrl, String restaurantBranchId) {
    final canonicalPath = '/customer/$restaurantBranchId';
    final canonicalUrl = '$_hostingOrigin$canonicalPath';
    final value = storedQueueUrl?.trim();
    if (value == null || value.isEmpty) return canonicalUrl;

    final uri = Uri.tryParse(value);
    if (uri == null) return canonicalUrl;
    if (uri.path == canonicalPath) return value;
    return canonicalUrl;
  }

  String? _canonicalAssetPath(String? storedPath) {
    final value = storedPath?.trim();
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    final segments = value.split('/').where((segment) => segment.isNotEmpty);
    if (value.startsWith('$_qrAssetRoot/') && segments.length == 3) {
      return value;
    }
    return null;
  }
}

final qrManagementRepositoryProvider = Provider<QrManagementRepository>((ref) {
  return QrManagementRepository();
});
