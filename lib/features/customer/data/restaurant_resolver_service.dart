// ignore_for_file: prefer_initializing_formals

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/branch.dart';

enum RestaurantResolverFailure {
  restaurantNotFound,
  restaurantClosed,
  branchNotFound,
  branchInactive,
}

class RestaurantResolverException implements Exception {
  const RestaurantResolverException(this.failure);

  final RestaurantResolverFailure failure;
}

class RestaurantDocument {
  const RestaurantDocument({
    required this.id,
    required this.name,
    required this.isActive,
    required this.data,
  });

  final String id;
  final String name;
  final bool isActive;
  final Map<String, dynamic> data;
}

class BranchBrandingData {
  const BranchBrandingData({
    required this.restaurantName,
    required this.branchName,
    this.cuisine,
    this.logoUrl,
  });

  final String restaurantName;
  final String branchName;
  final String? cuisine;
  final String? logoUrl;
}

class BranchMenuData {
  const BranchMenuData({this.menuPdfUrl, this.menuPreviewImageUrl});

  final String? menuPdfUrl;
  final String? menuPreviewImageUrl;
}

class QueueConfiguration {
  const QueueConfiguration({
    required this.queueUrl,
    required this.averageDiningMinutes,
    required this.averageCleaningMinutes,
    required this.holdMinutes,
    this.averageTurnoverMinutes,
  });

  final String queueUrl;
  final int averageDiningMinutes;
  final int averageCleaningMinutes;
  final int holdMinutes;
  final int? averageTurnoverMinutes;
}

class RestaurantResolution {
  const RestaurantResolution({
    required this.restaurant,
    required this.branch,
    required this.branding,
    required this.menu,
    required this.queueConfiguration,
  });

  final RestaurantDocument restaurant;
  final Branch branch;
  final BranchBrandingData branding;
  final BranchMenuData menu;
  final QueueConfiguration queueConfiguration;
}

class RestaurantResolverService {
  RestaurantResolverService({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<RestaurantResolution> resolve({
    required String restaurantSlug,
    required String branchSlug,
  }) async {
    final restaurantSnapshot = await _db
        .doc(FirestorePaths.restaurant(restaurantSlug))
        .get();
    final restaurantData = restaurantSnapshot.data();
    if (!restaurantSnapshot.exists || restaurantData == null) {
      throw const RestaurantResolverException(
        RestaurantResolverFailure.restaurantNotFound,
      );
    }

    final restaurant = _restaurantFromSnapshot(restaurantSlug, restaurantData);
    if (!restaurant.isActive) {
      throw const RestaurantResolverException(
        RestaurantResolverFailure.restaurantClosed,
      );
    }

    final branchSnapshot = await _resolveBranchSnapshot(
      restaurantSlug: restaurantSlug,
      branchSlug: branchSlug,
    );
    final branchData = branchSnapshot.data();
    if (branchData == null) {
      throw const RestaurantResolverException(
        RestaurantResolverFailure.branchNotFound,
      );
    }

    final branch = Branch.fromMap(branchSnapshot.id, branchData);
    if (!branch.isActive) {
      throw const RestaurantResolverException(
        RestaurantResolverFailure.branchInactive,
      );
    }

    final restaurantName = branch.restaurantName ?? restaurant.name;
    final branchName = branch.name.isEmpty
        ? (branch.branchSlug ?? branch.id)
        : branch.name;

    return RestaurantResolution(
      restaurant: restaurant,
      branch: branch,
      branding: BranchBrandingData(
        restaurantName: restaurantName,
        branchName: branchName,
        cuisine: branch.cuisine ?? restaurantData['cuisine'] as String?,
        logoUrl: branch.logoUrl ?? restaurantData['logoUrl'] as String?,
      ),
      menu: BranchMenuData(
        menuPdfUrl: branchData['menuPdfUrl'] as String?,
        menuPreviewImageUrl: branchData['menuPreviewImageUrl'] as String?,
      ),
      queueConfiguration: QueueConfiguration(
        queueUrl: branch.queueUrl ?? _queueUrl(restaurantSlug, branchSlug),
        averageDiningMinutes: branch.averageDiningMinutes,
        averageCleaningMinutes: branch.averageCleaningMinutes,
        holdMinutes: branch.holdMinutes,
        averageTurnoverMinutes: branch.averageTurnoverMinutes,
      ),
    );
  }

  RestaurantDocument _restaurantFromSnapshot(
    String restaurantId,
    Map<String, dynamic> data,
  ) {
    return RestaurantDocument(
      id: restaurantId,
      name:
          data['brandName'] as String? ??
          data['name'] as String? ??
          restaurantId,
      isActive: data['isActive'] as bool? ?? false,
      data: Map<String, dynamic>.unmodifiable(data),
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _resolveBranchSnapshot({
    required String restaurantSlug,
    required String branchSlug,
  }) async {
    final directSnapshot = await _db
        .doc(FirestorePaths.branch(restaurantSlug, branchSlug))
        .get();
    if (directSnapshot.exists) return directSnapshot;

    final slugSnapshot = await _db
        .collection(FirestorePaths.branches(restaurantSlug))
        .where('branchSlug', isEqualTo: branchSlug)
        .limit(2)
        .get();
    if (slugSnapshot.docs.length != 1) {
      throw const RestaurantResolverException(
        RestaurantResolverFailure.branchNotFound,
      );
    }
    return slugSnapshot.docs.single;
  }

  String _queueUrl(String restaurantSlug, String branchSlug) {
    return 'https://ezq-dev-cubiquitous.web.app/customer/'
        '$restaurantSlug/$branchSlug';
  }
}

class PassthroughRestaurantResolverService extends RestaurantResolverService {
  PassthroughRestaurantResolverService({super.firestore});

  @override
  Future<RestaurantResolution> resolve({
    required String restaurantSlug,
    required String branchSlug,
  }) async {
    final branch = Branch(
      id: branchSlug,
      branchId: branchSlug,
      branchSlug: branchSlug,
      restaurantId: restaurantSlug,
      restaurantName: restaurantSlug,
      name: branchSlug,
      address: '',
      city: '',
      state: '',
      country: 'India',
      timezone: 'Asia/Kolkata',
      qrSlug: '$restaurantSlug-$branchSlug',
      queueUrl: _queueUrl(restaurantSlug, branchSlug),
      isActive: true,
      averageDiningMinutes: 35,
      averageCleaningMinutes: 5,
      holdMinutes: 5,
    );
    final restaurant = RestaurantDocument(
      id: restaurantSlug,
      name: restaurantSlug,
      isActive: true,
      data: const {},
    );
    return RestaurantResolution(
      restaurant: restaurant,
      branch: branch,
      branding: BranchBrandingData(
        restaurantName: restaurant.name,
        branchName: branch.name,
      ),
      menu: const BranchMenuData(),
      queueConfiguration: QueueConfiguration(
        queueUrl: branch.queueUrl!,
        averageDiningMinutes: branch.averageDiningMinutes,
        averageCleaningMinutes: branch.averageCleaningMinutes,
        holdMinutes: branch.holdMinutes,
      ),
    );
  }

  @override
  String _queueUrl(String restaurantSlug, String branchSlug) {
    return 'https://ezq-dev-cubiquitous.web.app/customer/'
        '$restaurantSlug/$branchSlug';
  }
}

final restaurantResolverServiceProvider = Provider<RestaurantResolverService>((
  ref,
) {
  const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  if (useFirebase || kIsWeb) return RestaurantResolverService();
  return PassthroughRestaurantResolverService();
});
