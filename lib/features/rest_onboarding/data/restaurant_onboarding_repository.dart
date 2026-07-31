import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/onboarding_provisioning.dart';
import 'provisioning_stage_runner.dart';

typedef ProvisioningStepCallback =
    void Function(OnboardingProvisioningStep step);

abstract class RestaurantOnboardingRepository {
  Future<RestaurantBranchAdminContext?> loadAdminContext();

  Future<CompletedRestaurantOnboarding?> completedOnboardingForCurrentAdmin();

  Future<void> saveOnboardingDraft(RestaurantOnboardingDraft draft);

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
    ProvisioningFailureInjector? failureInjector,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _failureInjector = failureInjector ?? _debugFailureInjector();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ProvisioningFailureInjector? _failureInjector;

  static ProvisioningFailureInjector? _debugFailureInjector() {
    if (!kDebugMode) return null;
    const requestedStage = String.fromEnvironment(
      'ONBOARDING_FAIL_AFTER_STAGE',
    );
    if (requestedStage.isEmpty) return null;
    var hasInjectedFailure = false;
    return (stage) {
      if (hasInjectedFailure || stage.logName != requestedStage) return;
      hasInjectedFailure = true;
      throw StateError(
        'Forced onboarding failure after ${stage.logName} stage.',
      );
    };
  }

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
    _debugLog(
      '[ONBOARDING_CONTEXT] loadedAdmin '
      'path=$adminPath uid=${user.uid} '
      'restaurantBranchId=$restaurantBranchId '
      'name=${(adminData['name'] as String? ?? '').trim()} '
      'email=${(adminData['email'] as String? ?? '').trim()} '
      'phone=${(adminData['phone'] as String? ?? '').trim()} '
      'isActive=${adminData['isActive']} '
      'onboardingCompleted=${adminData['onboardingCompleted']}',
    );
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
        adminOnboardingCompleted:
            adminData['onboardingCompleted'] as bool? ?? false,
        provisioningStatus: 'pending',
        branchActive: false,
        restaurantName: _titleFromBranchId(restaurantBranchId),
        branchName: 'Main',
        area: '',
        address: '',
        slug: restaurantBranchId,
        onboardingDraft: null,
      );
      _debugLog(
        '[ONBOARDING_REPO] EXIT loadAdminContext missing branch default',
      );
      return context;
    }
    _debugLog(
      '[ONBOARDING_CONTEXT] loadedRestaurantBranch '
      'path=$outletPath '
      'restaurantName=${(branchData['restaurantName'] as String? ?? '').trim()} '
      'branchName=${(branchData['branchName'] as String? ?? '').trim()} '
      'area=${(branchData['area'] as String? ?? '').trim()} '
      'address=${(branchData['address'] as String? ?? '').trim()} '
      'slug=${(branchData['slug'] as String? ?? '').trim()} '
      'onboardingCompleted=${branchData['onboardingCompleted'] as bool? ?? false} '
      'provisioningStatus=${branchData['provisioningStatus'] as String? ?? ''}',
    );

    final onboardingCompleted =
        branchData['onboardingCompleted'] as bool? ?? false;
    final provisioningStatus =
        (branchData['provisioningStatus'] as String? ?? '').trim();
    final adminOnboardingCompleted =
        adminData['onboardingCompleted'] as bool? ?? false;
    final expectedProvisioningStatus = onboardingCompleted
        ? 'completed'
        : 'pending';
    if (adminOnboardingCompleted != onboardingCompleted ||
        provisioningStatus != expectedProvisioningStatus) {
      throw AdminContextLoadException(
        'Onboarding state is inconsistent. $adminPath.onboardingCompleted='
        '$adminOnboardingCompleted, $outletPath.onboardingCompleted='
        '$onboardingCompleted, and $outletPath.provisioningStatus='
        '${provisioningStatus.isEmpty ? '(missing)' : provisioningStatus}.',
      );
    }
    final completedConfiguration = onboardingCompleted
        ? await _loadCompletedConfiguration(
            restaurantBranchId: restaurantBranchId,
            branchData: branchData,
          )
        : null;
    final capacityTypes = _intListFromValue(branchData['capacityTypes']);
    final completedAt =
        _dateTimeFromValue(branchData['onboardingCompletedAt']) ??
        _dateTimeFromValue(adminData['onboardedAt']) ??
        _dateTimeFromValue(branchData['createdAt']);
    final context = RestaurantBranchAdminContext(
      uid: user.uid,
      name: (adminData['name'] as String? ?? '').trim(),
      email: (adminData['email'] as String? ?? '').trim(),
      phone: (adminData['phone'] as String? ?? '').trim(),
      restaurantBranchId: restaurantBranchId,
      role: (adminData['role'] as String? ?? 'owner').trim(),
      isActive: adminData['isActive'] as bool? ?? false,
      onboardingCompleted: onboardingCompleted,
      adminOnboardingCompleted: adminOnboardingCompleted,
      provisioningStatus: provisioningStatus,
      branchActive: branchData['isActive'] as bool? ?? false,
      restaurantName: (branchData['restaurantName'] as String? ?? '').trim(),
      branchName: (branchData['branchName'] as String? ?? '').trim(),
      area: (branchData['area'] as String? ?? '').trim(),
      address: (branchData['address'] as String? ?? '').trim(),
      slug: (branchData['slug'] as String? ?? restaurantBranchId).trim().isEmpty
          ? restaurantBranchId
          : (branchData['slug'] as String? ?? restaurantBranchId).trim(),
      floorCount: _intFromValue(branchData['floorCount']),
      totalTables: _intFromValue(branchData['totalTables']),
      totalSeats: _intFromValue(branchData['totalSeats']),
      capacityTypes: capacityTypes,
      selectedTableCapacities: capacityTypes,
      tableCountsByFloor:
          completedConfiguration?.tableCountsByFloor ?? const <List<int>>[],
      onboardingCompletedAt: _dateTimeFromValue(
        branchData['onboardingCompletedAt'],
      ),
      onboardedAt: _dateTimeFromValue(adminData['onboardedAt']),
      createdAt: completedAt,
      queueUrl: (branchData['queueUrl'] as String? ?? '').trim(),
      provisioningFingerprint:
          (branchData['provisioningFingerprint'] as String? ?? '').trim(),
      onboardingDraft: RestaurantOnboardingDraft.fromFirestore(
        branchData['onboardingDraft'],
      ),
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
  Future<void> saveOnboardingDraft(RestaurantOnboardingDraft draft) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AdminContextLoadException(
        'Admin authentication is required to save onboarding progress.',
      );
    }
    final restaurantBranchId = draft.restaurantBranchId.trim();
    if (restaurantBranchId.isEmpty) return;

    final branchRef = _firestore.doc(
      FirestorePaths.restaurantBranch(restaurantBranchId),
    );
    try {
      await _writeOnboardingDraft(branchRef, draft);
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      await _replaceOnboardingDraft(branchRef, draft);
    }
  }

  Future<void> _writeOnboardingDraft(
    DocumentReference<Map<String, dynamic>> branchRef,
    RestaurantOnboardingDraft draft,
  ) {
    return branchRef.update(<String, dynamic>{
      'onboardingDraft': draft.toFirestore(),
      'onboardingDraftUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _replaceOnboardingDraft(
    DocumentReference<Map<String, dynamic>> branchRef,
    RestaurantOnboardingDraft draft,
  ) async {
    await branchRef.update(<String, dynamic>{
      'onboardingDraft': FieldValue.delete(),
      'onboardingDraftUpdatedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _writeOnboardingDraft(branchRef, draft);
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

    if ((adminContext.onboardingCompleted ||
            adminContext.adminOnboardingCompleted == true ||
            adminContext.provisioningStatus == 'completed') &&
        !adminContext.isProvisioningCompleted) {
      throw const RestaurantOnboardingFailure(
        step: OnboardingProvisioningStep.updateAdmin,
        message:
            'Persisted onboarding completion is inconsistent between the '
            'admin and restaurant branch. Provisioning was stopped.',
      );
    }

    final qrUrl = '/customer/${request.restaurantBranchId}';
    final hostedQrUrl = 'https://ezq-dev-cubiquitous.web.app$qrUrl';
    final qrAssetBase =
        'assets/qr/${request.restaurantBranchId}/${request.restaurantBranchId}';
    RestaurantOnboardingResult resultFor(DateTime completionTime) {
      return RestaurantOnboardingResult(
        restaurantBranchId: request.restaurantBranchId,
        createdAt: completionTime,
        adminEmail: adminContext.email.isEmpty
            ? 'Not available'
            : adminContext.email,
        qrUrl: qrUrl,
      );
    }

    if (adminContext.isProvisioningCompleted) {
      final persistedFingerprint = adminContext.provisioningFingerprint;
      if (persistedFingerprint.isNotEmpty &&
          persistedFingerprint != request.provisioningFingerprint) {
        throw const RestaurantOnboardingFailure(
          step: OnboardingProvisioningStep.updateRestaurantBranch,
          message:
              'This branch is already provisioned with a different table '
              'configuration. Existing production setup was not changed.',
        );
      }
      final completionTime =
          adminContext.onboardingCompletedAt ?? adminContext.onboardedAt;
      if (completionTime == null) {
        throw const RestaurantOnboardingFailure(
          step: OnboardingProvisioningStep.commitProvisioning,
          message:
              'Completed onboarding is missing its persisted completion '
              'timestamp. Existing production setup was not changed.',
        );
      }
      _debugLog(
        '[ONBOARDING_PROVISIONING] replay=idempotent '
        'authenticatedUid=${user.uid} '
        'restaurantId=${request.restaurantBranchId} '
        'branchId=${request.restaurantBranchId} '
        'batchWriteCount=0 commit=not_required',
      );
      for (final step in OnboardingProvisioningStep.values) {
        onStepStarted(step);
        onStepCompleted(step);
      }
      return resultFor(completionTime);
    }

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
    await _assertNoPartialProvisioningData(branchRef);

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
    final completionUpdates = buildOnboardingCompletionUpdates(
      request: request,
      hostedQrUrl: hostedQrUrl,
      qrAssetBase: qrAssetBase,
    );
    final startedUiSteps = <OnboardingProvisioningStep>{};
    var currentStage = RestaurantProvisioningStage.branch;
    var commitAttempted = false;
    final attemptId =
        '${user.uid}-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

    final actions = <RestaurantProvisioningStage, ProvisioningStageAction>{
      RestaurantProvisioningStage.branch: () async {},
      RestaurantProvisioningStage.qr: () async {
        batch.update(branchRef, completionUpdates.branch);
      },
      RestaurantProvisioningStage.floors: () async {
        for (
          var floorIndex = 0;
          floorIndex < request.floorCount;
          floorIndex++
        ) {
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
          batch.set(
            branchRef.collection('floors').doc(floorId),
            <String, dynamic>{
              'floorId': floorId,
              'floorName': 'Floor $floorNumber',
              'displayOrder': floorNumber,
              'tableCount': tableCount,
              'seatCount': seatCount,
            },
          );
        }
      },
      RestaurantProvisioningStage.tables: () async {
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
                  'displayTableName': '$floorId-$tableId',
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
      },
      RestaurantProvisioningStage.settings: () async {
        batch.set(
          branchRef.collection('settings').doc('general'),
          <String, dynamic>{
            'averageDiningMinutes': 35,
            'averageCleaningMinutes': 5,
            'reservationHoldMinutes': 5,
          },
        );
      },
      RestaurantProvisioningStage.admin: () async {
        batch.update(adminRef, completionUpdates.admin);
      },
    };

    _debugLog(
      '[ONBOARDING_PROVISIONING] attempt=$attemptId '
      'authenticatedUid=${user.uid} expectedUid=${adminContext.uid} '
      'restaurantId=${request.restaurantBranchId} '
      'branchId=${request.restaurantBranchId} '
      'adminPath=${adminRef.path} branchPath=${branchRef.path} '
      'batchWriteCount=$batchWriteCount stage=starting',
    );
    try {
      await runAtomicProvisioningStages(
        actions: actions,
        failureInjector: _failureInjector,
        onStageStarted: (stage) {
          currentStage = stage;
          if (startedUiSteps.add(stage.uiStep)) {
            onStepStarted(stage.uiStep);
          }
          _debugLog(
            '[ONBOARDING_PROVISIONING] attempt=$attemptId '
            'stage=${stage.logName} status=started '
            'authenticatedUid=${user.uid} '
            'restaurantId=${request.restaurantBranchId} '
            'branchId=${request.restaurantBranchId} '
            'batchWriteCount=$batchWriteCount',
          );
        },
        onStagePrepared: (stage) {
          _debugLog(
            '[ONBOARDING_PROVISIONING] attempt=$attemptId '
            'stage=${stage.logName} status='
            '${stage == RestaurantProvisioningStage.commit ? 'committed' : 'prepared'}',
          );
        },
        commit: () async {
          commitAttempted = true;
          _debugLog(
            '[ONBOARDING_PROVISIONING] attempt=$attemptId '
            'commit=started batchWriteCount=$batchWriteCount',
          );
          await batch.commit();
        },
      );
      for (final step in OnboardingProvisioningStep.values) {
        onStepCompleted(step);
      }
      _debugLog(
        '[ONBOARDING_PROVISIONING] attempt=$attemptId commit=success '
        'rollback=not_required authenticatedUid=${user.uid} '
        'restaurantId=${request.restaurantBranchId} '
        'branchId=${request.restaurantBranchId} '
        'batchWriteCount=$batchWriteCount',
      );
    } catch (error, stackTrace) {
      _debugLog(
        '[ONBOARDING_PROVISIONING] attempt=$attemptId '
        'commit=${commitAttempted ? 'failed' : 'not_attempted'} '
        'stage=${currentStage.logName} '
        'rollback=${commitAttempted ? 'confirmed_atomic_batch' : 'not_required_no_commit'} '
        'authenticatedUid=${user.uid} '
        'restaurantId=${request.restaurantBranchId} '
        'branchId=${request.restaurantBranchId} '
        'batchWriteCount=$batchWriteCount error=$error '
        'stackTrace=$stackTrace',
      );
      throw RestaurantOnboardingFailure(
        step: currentStage.uiStep,
        message: 'Provisioning failed: $error',
        cause: error,
      );
    }

    try {
      final persistedContext = await loadAdminContext();
      final persistedCompletionTime =
          persistedContext?.onboardingCompletedAt ??
          persistedContext?.onboardedAt;
      if (persistedContext == null ||
          !persistedContext.isProvisioningCompleted ||
          persistedCompletionTime == null) {
        throw const AdminContextLoadException(
          'Committed onboarding could not be reconstructed from Firestore.',
        );
      }
      _debugLog(
        '[ONBOARDING_PROVISIONING] attempt=$attemptId '
        'restoration=success source=firestore',
      );
      return resultFor(persistedCompletionTime);
    } catch (error, stackTrace) {
      _debugLog(
        '[ONBOARDING_PROVISIONING] attempt=$attemptId commit=success '
        'restoration=failed retry=safe error=$error '
        'stackTrace=$stackTrace',
      );
      throw RestaurantOnboardingFailure(
        step: OnboardingProvisioningStep.commitProvisioning,
        message:
            'Provisioning was committed, but Firestore confirmation could not '
            'be loaded. Press Retry to restore the completed setup safely.',
        cause: error,
      );
    }
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

  Future<_PersistedProvisioningConfiguration> _loadCompletedConfiguration({
    required String restaurantBranchId,
    required Map<String, dynamic> branchData,
  }) async {
    final branchRef = _firestore.doc(
      FirestorePaths.restaurantBranch(restaurantBranchId),
    );
    final results = await Future.wait<Object>([
      branchRef
          .collection('floors')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10)),
      branchRef
          .collection('tables')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10)),
      branchRef
          .collection('settings')
          .doc('general')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10)),
    ]);
    final floors = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final tables = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final settings = results[2] as DocumentSnapshot<Map<String, dynamic>>;
    final floorCount = _intFromValue(branchData['floorCount']);
    final totalTables = _intFromValue(branchData['totalTables']);
    final capacityTypes = _intListFromValue(branchData['capacityTypes']);
    final queueUrl = (branchData['queueUrl'] as String? ?? '').trim();

    if (floorCount <= 0 ||
        floors.docs.length != floorCount ||
        tables.docs.length != totalTables ||
        !settings.exists ||
        capacityTypes.isEmpty ||
        queueUrl.isEmpty) {
      throw AdminContextLoadException(
        'Completed onboarding data is inconsistent for '
        'restaurantBranches/$restaurantBranchId. Expected $floorCount floors, '
        '$totalTables tables, settings/general, capacityTypes, and queueUrl; '
        'found ${floors.docs.length} floors, ${tables.docs.length} tables, '
        'settings=${settings.exists}, capacities=${capacityTypes.length}, '
        'queueUrl=${queueUrl.isNotEmpty}.',
      );
    }

    final counts = List<List<int>>.generate(
      floorCount,
      (_) => List<int>.filled(capacityTypes.length, 0),
    );
    for (final table in tables.docs) {
      final data = table.data();
      final floorId = (data['floorId'] as String? ?? '').trim();
      final floorNumber = int.tryParse(floorId.replaceFirst('F', ''));
      final capacity = _intFromValue(data['capacity']);
      final capacityIndex = capacityTypes.indexOf(capacity);
      if (floorNumber == null ||
          floorNumber < 1 ||
          floorNumber > floorCount ||
          capacityIndex < 0) {
        throw AdminContextLoadException(
          'Completed onboarding table ${table.reference.path} has an invalid '
          'floorId or capacity.',
        );
      }
      counts[floorNumber - 1][capacityIndex]++;
    }
    return _PersistedProvisioningConfiguration(tableCountsByFloor: counts);
  }

  Future<void> _assertNoPartialProvisioningData(
    DocumentReference<Map<String, dynamic>> branchRef,
  ) async {
    final results = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
      branchRef
          .collection('floors')
          .limit(1)
          .get(const GetOptions(source: Source.server)),
      branchRef
          .collection('tables')
          .limit(1)
          .get(const GetOptions(source: Source.server)),
      branchRef
          .collection('settings')
          .limit(1)
          .get(const GetOptions(source: Source.server)),
    ]);
    if (results.every((snapshot) => snapshot.docs.isEmpty)) return;
    throw const RestaurantOnboardingFailure(
      step: OnboardingProvisioningStep.updateRestaurantBranch,
      message:
          'Pending onboarding contains partial floors, tables, or settings. '
          'Provisioning was stopped to avoid duplicate or orphan data.',
    );
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

@visibleForTesting
OnboardingCompletionUpdates buildOnboardingCompletionUpdates({
  required RestaurantOnboardingRequest request,
  required String hostedQrUrl,
  required String qrAssetBase,
}) {
  return OnboardingCompletionUpdates(
    branch: <String, dynamic>{
      'onboardingCompleted': true,
      'provisioningStatus': 'completed',
      'onboardingCompletedAt': FieldValue.serverTimestamp(),
      'provisioningFingerprint': request.provisioningFingerprint,
      'qrEnabled': true,
      'qrSlug': request.restaurantBranchId,
      'queueUrl': hostedQrUrl,
      'qrPngLocalPath': '$qrAssetBase.png',
      'qrSvgLocalPath': '$qrAssetBase.svg',
      'floorCount': request.floorCount,
      'totalTables': request.totalTables,
      'totalSeats': request.totalSeats,
      'capacityTypes': request.selectedTableCapacities,
      'onboardingDraft': FieldValue.delete(),
      'onboardingDraftUpdatedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    },
    admin: <String, dynamic>{
      'onboardingCompleted': true,
      'onboardedAt': FieldValue.serverTimestamp(),
    },
  );
}

class OnboardingCompletionUpdates {
  const OnboardingCompletionUpdates({
    required this.branch,
    required this.admin,
  });

  final Map<String, dynamic> branch;
  final Map<String, dynamic> admin;
}

class _PersistedProvisioningConfiguration {
  const _PersistedProvisioningConfiguration({required this.tableCountsByFloor});

  final List<List<int>> tableCountsByFloor;
}

int _intFromValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<int> _intListFromValue(Object? value) {
  if (value is! Iterable) return const <int>[];
  return value.map(_intFromValue).where((item) => item > 0).toList();
}

DateTime? _dateTimeFromValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class AdminContextLoadException implements Exception {
  const AdminContextLoadException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
