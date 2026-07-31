import 'package:ezq/features/rest_onboarding/data/provisioning_stage_runner.dart';
import 'package:ezq/features/rest_onboarding/data/restaurant_onboarding_repository.dart';
import 'package:ezq/features/rest_onboarding/domain/onboarding_provisioning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = RestaurantOnboardingRequest(
    restaurantBranchId: 'audit-branch',
    restaurantName: 'Audit Restaurant',
    branchName: 'Main',
    area: 'Indiranagar',
    address: '12th Main',
    floorCount: 2,
    selectedTableCapacities: <int>[2, 4],
    tableCountsByFloor: <List<int>>[
      <int>[2, 1],
      <int>[1, 2],
    ],
    totalTables: 6,
    totalSeats: 18,
  );

  group('restaurant onboarding provisioning', () {
    test('builds branch and admin completion from one canonical helper', () {
      final updates = buildOnboardingCompletionUpdates(
        request: request,
        hostedQrUrl: 'https://example.test/customer/audit-branch',
        qrAssetBase: 'assets/qr/audit-branch/audit-branch',
      );

      expect(updates.admin.keys, <String>{
        'onboardingCompleted',
        'onboardedAt',
      });
      expect(updates.admin['onboardingCompleted'], isTrue);
      expect(updates.branch['onboardingCompleted'], isTrue);
      expect(updates.branch['provisioningStatus'], 'completed');
      expect(
        updates.branch['provisioningFingerprint'],
        request.provisioningFingerprint,
      );
      expect(updates.branch['onboardingCompletedAt'], isNotNull);
    });

    test('fingerprint is stable for an identical request', () {
      const identical = RestaurantOnboardingRequest(
        restaurantBranchId: 'audit-branch',
        restaurantName: 'Audit Restaurant',
        branchName: 'Main',
        area: 'Indiranagar',
        address: '12th Main',
        floorCount: 2,
        selectedTableCapacities: <int>[2, 4],
        tableCountsByFloor: <List<int>>[
          <int>[2, 1],
          <int>[1, 2],
        ],
        totalTables: 6,
        totalSeats: 18,
      );
      expect(
        request.provisioningFingerprint,
        identical.provisioningFingerprint,
      );
    });

    for (final failureStage in provisioningPreparationStages) {
      test(
        'failure after ${failureStage.name} leaves the atomic store empty',
        () async {
          final store = _FakeAtomicStore();
          await expectLater(
            _runFakeProvisioning(
              store,
              failureInjector: (stage) {
                if (stage == failureStage) throw StateError('forced');
              },
            ),
            throwsStateError,
          );

          expect(store.committed, isEmpty);
          expect(store.commitCount, 0);
        },
      );
    }

    test(
      'retry commits once and replay creates no duplicate documents',
      () async {
        final store = _FakeAtomicStore();
        var failedOnce = false;

        await expectLater(
          _runFakeProvisioning(
            store,
            failureInjector: (stage) {
              if (!failedOnce && stage == RestaurantProvisioningStage.tables) {
                failedOnce = true;
                throw StateError('forced once');
              }
            },
          ),
          throwsStateError,
        );
        expect(store.committed, isEmpty);

        await _runFakeProvisioning(store);
        final firstCommit = Map<String, String>.from(store.committed);
        await _runFakeProvisioning(store);

        expect(store.committed, firstCommit);
        expect(store.committed.keys, <String>{
          'branch',
          'qr',
          'floor/F1',
          'floor/F2',
          'table/T1',
          'table/T2',
          'settings/general',
          'admin',
        });
      },
    );
  });
}

Future<void> _runFakeProvisioning(
  _FakeAtomicStore store, {
  ProvisioningFailureInjector? failureInjector,
}) {
  final actions = <RestaurantProvisioningStage, ProvisioningStageAction>{
    RestaurantProvisioningStage.branch: () async {
      store.stage('branch', 'completed');
    },
    RestaurantProvisioningStage.qr: () async {
      store.stage('qr', 'configured');
    },
    RestaurantProvisioningStage.floors: () async {
      store.stage('floor/F1', '2');
      store.stage('floor/F2', '2');
    },
    RestaurantProvisioningStage.tables: () async {
      store.stage('table/T1', 'available');
      store.stage('table/T2', 'available');
    },
    RestaurantProvisioningStage.settings: () async {
      store.stage('settings/general', 'defaults');
    },
    RestaurantProvisioningStage.admin: () async {
      store.stage('admin', 'completed');
    },
  };
  return runAtomicProvisioningStages(
    actions: actions,
    failureInjector: failureInjector,
    commit: store.commit,
  );
}

class _FakeAtomicStore {
  final staged = <String, String>{};
  final committed = <String, String>{};
  int commitCount = 0;

  void stage(String path, String value) {
    staged[path] = value;
  }

  Future<void> commit() async {
    committed.addAll(staged);
    staged.clear();
    commitCount++;
  }
}
