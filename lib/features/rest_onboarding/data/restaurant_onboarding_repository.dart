import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/onboarding_provisioning.dart';

typedef ProvisioningStepCallback =
    void Function(OnboardingProvisioningStep step);

abstract class RestaurantOnboardingRepository {
  Future<RestaurantBranchAdminContext?> loadAdminContext();

  Future<CompletedRestaurantOnboarding?> completedOnboardingForCurrentAdmin();

  Future<RestaurantOnboardingResult> provisionRestaurant({
    required RestaurantOnboardingRequest request,
    required ProvisioningStepCallback onStepStarted,
    required ProvisioningStepCallback onStepCompleted,
  });
}

class FirebaseRestaurantOnboardingRepository
    implements RestaurantOnboardingRepository {
  FirebaseRestaurantOnboardingRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<RestaurantBranchAdminContext?> loadAdminContext() async {
    _debugLog('[ONBOARDING_REPO] ENTER loadAdminContext');
    final user = _auth.currentUser;
    _debugLog('[AUTH]\nuid=${user?.uid ?? 'null'}\nemail=${user?.email ?? ''}');
    if (user == null) {
      throw const AdminContextLoadException(
        'No FirebaseAuth.currentUser is available. Admin must sign in before '
        'loading onboarding context.',
      );
    }

    final adminPath = FirestorePaths.rootAdmin(user.uid);
    _debugLog('[ONBOARDING_REPO] BEFORE await _readDocument path=$adminPath');
    final adminSnapshot = await _readDocument(path: adminPath, label: 'ADMIN');
    _debugLog('[ONBOARDING_REPO] AFTER await _readDocument path=$adminPath');
    final adminData = adminSnapshot.data();
    _debugLog(
      '[ADMIN]\n'
      'path=$adminPath\n'
      'Document exists=${adminSnapshot.exists}',
    );
    if (!adminSnapshot.exists || adminData == null) {
      throw AdminContextLoadException(
        'Admin document is missing at $adminPath. Expected root admin mapping '
        'document admins/${user.uid}.',
      );
    }

    final restaurantBranchId =
        (adminData['restaurantBranchId'] as String? ?? '').trim();
    _debugLog('[ADMIN]\nrestaurantBranchId=$restaurantBranchId');
    if (restaurantBranchId.isEmpty) {
      throw AdminContextLoadException(
        'Admin document $adminPath is missing required field '
        'restaurantBranchId.',
      );
    }

    final outletPath = FirestorePaths.restaurantBranch(restaurantBranchId);
    _debugLog('[ONBOARDING_REPO] BEFORE await _readDocument path=$outletPath');
    final branchSnapshot = await _readDocument(
      path: outletPath,
      label: 'OUTLET',
    );
    _debugLog('[ONBOARDING_REPO] AFTER await _readDocument path=$outletPath');
    final branchData = branchSnapshot.data();
    _debugLog(
      '[OUTLET]\n'
      'path=$outletPath\n'
      'Document exists=${branchSnapshot.exists}',
    );
    if (!branchSnapshot.exists || branchData == null) {
      _debugLog(
        '[OUTLET]\n'
        'path=$outletPath\n'
        'Using default empty onboarding context because document is missing.',
      );
      final context = RestaurantBranchAdminContext(
        uid: user.uid,
        name: (adminData['name'] as String? ?? '').trim(),
        email: (adminData['email'] as String? ?? '').trim(),
        phone: (adminData['phone'] as String? ?? '').trim(),
        restaurantBranchId: restaurantBranchId,
        role: (adminData['role'] as String? ?? 'owner').trim(),
        isActive: adminData['isActive'] as bool? ?? false,
        onboardingCompleted: false,
        provisioningStatus: 'pending',
        branchActive: false,
        restaurantName: _titleFromBranchId(restaurantBranchId),
        branchName: 'Main',
        area: '',
        address: '',
        slug: restaurantBranchId,
      );
      _debugLog(
        '[ONBOARDING_REPO] EXIT loadAdminContext missing branch default',
      );
      return context;
    }
    _debugLog(
      '[OUTLET]\n'
      'slug=${(branchData['slug'] as String? ?? '').trim()}\n'
      'onboardingCompleted=${branchData['onboardingCompleted'] as bool? ?? false}\n'
      'provisioningStatus=${branchData['provisioningStatus'] as String? ?? ''}',
    );

    final onboardingCompleted =
        branchData['onboardingCompleted'] as bool? ?? false;
    final provisioningStatus =
        (branchData['provisioningStatus'] as String? ?? '').trim();
    final context = RestaurantBranchAdminContext(
      uid: user.uid,
      name: (adminData['name'] as String? ?? '').trim(),
      email: (adminData['email'] as String? ?? '').trim(),
      phone: (adminData['phone'] as String? ?? '').trim(),
      restaurantBranchId: restaurantBranchId,
      role: (adminData['role'] as String? ?? 'owner').trim(),
      isActive: adminData['isActive'] as bool? ?? false,
      onboardingCompleted: onboardingCompleted,
      provisioningStatus: provisioningStatus,
      branchActive: branchData['isActive'] as bool? ?? false,
      restaurantName: (branchData['restaurantName'] as String? ?? '').trim(),
      branchName: (branchData['branchName'] as String? ?? '').trim(),
      area: (branchData['area'] as String? ?? '').trim(),
      address: (branchData['address'] as String? ?? '').trim(),
      slug: (branchData['slug'] as String? ?? restaurantBranchId).trim().isEmpty
          ? restaurantBranchId
          : (branchData['slug'] as String? ?? restaurantBranchId).trim(),
    );
    _debugLog('[ONBOARDING_REPO] EXIT loadAdminContext success');
    return context;
  }

  @override
  Future<CompletedRestaurantOnboarding?>
  completedOnboardingForCurrentAdmin() async {
    _debugLog('[ONBOARDING_REPO] ENTER completedOnboardingForCurrentAdmin');
    RestaurantBranchAdminContext? context;
    try {
      _debugLog(
        '[ONBOARDING_REPO] BEFORE await loadAdminContext '
        'from completedOnboardingForCurrentAdmin',
      );
      context = await loadAdminContext();
      _debugLog(
        '[ONBOARDING_REPO] AFTER await loadAdminContext '
        'from completedOnboardingForCurrentAdmin '
        'contextRestaurantBranchId=${context?.restaurantBranchId ?? 'null'}',
      );
    } on AdminContextLoadException catch (error) {
      _debugLog('[ONBOARDING_COMPLETION]\n${error.message}');
      _debugLog(
        '[ONBOARDING_REPO] EXIT completedOnboardingForCurrentAdmin error',
      );
      return null;
    } catch (error, stackTrace) {
      _debugLog('[ONBOARDING_COMPLETION]\nunexpected=$error\n$stackTrace');
      _debugLog(
        '[ONBOARDING_REPO] EXIT completedOnboardingForCurrentAdmin unexpected',
      );
      return null;
    }
    if (context == null || !context.isProvisioningCompleted) {
      _debugLog(
        '[ONBOARDING_REPO] EXIT completedOnboardingForCurrentAdmin null',
      );
      return null;
    }
    _debugLog(
      '[ONBOARDING_REPO] EXIT completedOnboardingForCurrentAdmin completed',
    );
    return CompletedRestaurantOnboarding(
      restaurantBranchId: context.restaurantBranchId,
    );
  }

  @override
  Future<RestaurantOnboardingResult> provisionRestaurant({
    required RestaurantOnboardingRequest request,
    required ProvisioningStepCallback onStepStarted,
    required ProvisioningStepCallback onStepCompleted,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const RestaurantOnboardingFailure(
        step: OnboardingProvisioningStep.updateAdmin,
        message: 'Admin authentication is required.',
      );
    }

    final adminContext = await loadAdminContext();
    if (adminContext == null) {
      throw const RestaurantOnboardingFailure(
        step: OnboardingProvisioningStep.updateAdmin,
        message: 'Admin mapping was not found.',
      );
    }
    if (!adminContext.isActive) {
      throw const RestaurantOnboardingFailure(
        step: OnboardingProvisioningStep.updateAdmin,
        message: 'Admin account is not active.',
      );
    }
    if (adminContext.restaurantBranchId != request.restaurantBranchId) {
      throw const RestaurantOnboardingFailure(
        step: OnboardingProvisioningStep.updateRestaurantBranch,
        message: 'Admin is not mapped to this restaurant branch.',
      );
    }

    final createdAt = DateTime.now();
    final qrUrl = '/customer/${request.restaurantBranchId}';
    final hostedQrUrl = 'https://ezq-dev-cubiquitous.web.app$qrUrl';
    final qrAssetBase =
        'assets/qr/${request.restaurantBranchId}/${request.restaurantBranchId}';
    final result = RestaurantOnboardingResult(
      restaurantBranchId: request.restaurantBranchId,
      createdAt: createdAt,
      adminEmail: adminContext.email.isEmpty
          ? 'Not available'
          : adminContext.email,
      qrUrl: qrUrl,
    );

    final branchRef = _firestore.doc(
      FirestorePaths.restaurantBranch(request.restaurantBranchId),
    );
    final adminRef = _firestore.doc(FirestorePaths.rootAdmin(user.uid));
    final branchSnapshot = await branchRef.get();
    if (!branchSnapshot.exists) {
      throw const RestaurantOnboardingFailure(
        step: OnboardingProvisioningStep.updateRestaurantBranch,
        message: 'Restaurant branch was not found.',
      );
    }

    final batchWriteCount = 3 + request.floorCount + request.totalTables;
    if (batchWriteCount > 500) {
      throw RestaurantOnboardingFailure(
        step: OnboardingProvisioningStep.createTables,
        message:
            'This setup requires $batchWriteCount Firestore writes, which '
            'exceeds the 500-write batch limit. Reduce table count or use a '
            'Cloud Function provisioning flow.',
      );
    }

    final batch = _firestore.batch();

    _markStarted(
      OnboardingProvisioningStep.updateRestaurantBranch,
      onStepStarted,
    );
    batch.update(branchRef, <String, dynamic>{
      'onboardingCompleted': true,
      'provisioningStatus': 'completed',
      'qrEnabled': true,
      'qrSlug': request.restaurantBranchId,
      'queueUrl': hostedQrUrl,
      'qrPngLocalPath': '$qrAssetBase.png',
      'qrSvgLocalPath': '$qrAssetBase.svg',
      'floorCount': request.floorCount,
      'totalTables': request.totalTables,
      'totalSeats': request.totalSeats,
      'capacityTypes': request.selectedTableCapacities,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _markStarted(OnboardingProvisioningStep.createFloors, onStepStarted);
    for (var floorIndex = 0; floorIndex < request.floorCount; floorIndex++) {
      final floorNumber = floorIndex + 1;
      final floorId = 'F$floorNumber';
      final counts = request.tableCountsByFloor[floorIndex];
      final tableCount = counts.fold<int>(
        0,
        (runningTotal, tableQuantity) => runningTotal + tableQuantity,
      );
      var seatCount = 0;
      for (
        var capacityIndex = 0;
        capacityIndex < request.selectedTableCapacities.length;
        capacityIndex++
      ) {
        seatCount +=
            counts[capacityIndex] *
            request.selectedTableCapacities[capacityIndex];
      }
      batch.set(branchRef.collection('floors').doc(floorId), <String, dynamic>{
        'floorId': floorId,
        'floorName': 'Floor $floorNumber',
        'displayOrder': floorNumber,
        'tableCount': tableCount,
        'seatCount': seatCount,
      });
    }

    _markStarted(OnboardingProvisioningStep.createTables, onStepStarted);
    var tableNumber = 1;
    for (
      var floorIndex = 0;
      floorIndex < request.tableCountsByFloor.length;
      floorIndex++
    ) {
      final floorId = 'F${floorIndex + 1}';
      final counts = request.tableCountsByFloor[floorIndex];
      for (
        var capacityIndex = 0;
        capacityIndex < request.selectedTableCapacities.length;
        capacityIndex++
      ) {
        final capacity = request.selectedTableCapacities[capacityIndex];
        final count = counts[capacityIndex];
        for (var index = 0; index < count; index++) {
          final tableId = 'T$tableNumber';
          batch.set(
            branchRef.collection('tables').doc(tableId),
            <String, dynamic>{
              'tableId': tableId,
              'tableNumber': tableId,
              'floorId': floorId,
              'capacity': capacity,
              'tableType': '$capacity-top',
              'status': 'available',
              'section': 'default',
              'sortOrder': tableNumber,
              'isCombinable': false,
              'currentQueueEntryId': null,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
          tableNumber++;
        }
      }
    }

    _markStarted(OnboardingProvisioningStep.createSettings, onStepStarted);
    batch
        .set(branchRef.collection('settings').doc('general'), <String, dynamic>{
          'averageDiningMinutes': 35,
          'averageCleaningMinutes': 5,
          'reservationHoldMinutes': 5,
        });

    _markStarted(OnboardingProvisioningStep.updateAdmin, onStepStarted);
    batch.update(adminRef, <String, dynamic>{
      'onboardedAt': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
      for (final step in OnboardingProvisioningStep.values) {
        onStepCompleted(step);
      }
    } catch (error) {
      throw RestaurantOnboardingFailure(
        step: OnboardingProvisioningStep.updateAdmin,
        message: 'Provisioning failed: $error',
        cause: error,
      );
    }

    return result;
  }

  void _markStarted(
    OnboardingProvisioningStep step,
    ProvisioningStepCallback onStepStarted,
  ) {
    onStepStarted(step);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _readDocument({
    required String path,
    required String label,
  }) async {
    try {
      _debugLog('[$label]\nBEFORE Firestore get path=$path');
      final snapshot = await _firestore
          .doc(path)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      _debugLog(
        '[$label]\n'
        'AFTER Firestore get\n'
        'read=$path\n'
        'exists=${snapshot.exists}',
      );
      return snapshot;
    } on FirebaseException catch (error) {
      _debugLog(
        '[$label]\n'
        'path=$path\n'
        'FirebaseException code=${error.code}\n'
        'message=${error.message ?? ''}',
      );
      throw AdminContextLoadException(
        'Firestore read failed for $path: ${error.code} '
        '${error.message ?? ''}',
        cause: error,
      );
    } catch (error) {
      _debugLog('[$label]\npath=$path\nerror=$error');
      throw AdminContextLoadException(
        'Firestore read failed for $path: $error',
        cause: error,
      );
    }
  }

  String _titleFromBranchId(String restaurantBranchId) {
    final words = restaurantBranchId
        .split(RegExp(r'[-_\s]+'))
        .where((word) => word.trim().isNotEmpty)
        .map((word) {
          final lower = word.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        });
    final title = words.join(' ').trim();
    return title.isEmpty ? restaurantBranchId : title;
  }

  void _debugLog(String message) {
    debugPrint(message);
  }
}

class AdminContextLoadException implements Exception {
  const AdminContextLoadException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
