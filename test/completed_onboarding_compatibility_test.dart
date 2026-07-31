import 'package:ezq/features/rest_onboarding/domain/completed_onboarding_compatibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('newly onboarded configuration remains unchanged', () {
    final result = resolveCompletedOnboardingCompatibility(
      restaurantBranchId: 'new-branch',
      branchData: {
        'floorCount': 1,
        'totalTables': 2,
        'capacityTypes': <int>[2, 4],
        'queueUrl': 'https://ezq-dev-cubiquitous.web.app/customer/new-branch',
      },
      floorDocumentIds: const <String>['F1'],
      tables: const <CompletedOnboardingTableRecord>[
        CompletedOnboardingTableRecord(id: 'T1', floorId: 'F1', capacity: 2),
        CompletedOnboardingTableRecord(id: 'T2', floorId: 'F1', capacity: 4),
      ],
      settingsDocumentExists: true,
    );

    expect(result.isValid, isTrue);
    expect(result.usedLegacyCompatibility, isFalse);
    expect(result.capacityTypes, <int>[2, 4]);
    expect(result.tableCountsByFloor, <List<int>>[
      <int>[1, 1],
    ]);
    expect(
      result.queueUrl,
      'https://ezq-dev-cubiquitous.web.app/customer/new-branch',
    );
  });

  test('Spice House legacy metadata is reconstructed in memory', () {
    final result = resolveCompletedOnboardingCompatibility(
      restaurantBranchId: 'the-spice-house-indiranagar',
      branchData: {
        'floorCount': 1,
        'totalTables': 3,
        'capacityTypes': <int>[2, 4, 6],
        'averageTurnoverMinutes': 35,
      },
      floorDocumentIds: const <String>['F1'],
      tables: const <CompletedOnboardingTableRecord>[
        CompletedOnboardingTableRecord(id: 'T1', floorId: 'F1', capacity: 2),
        CompletedOnboardingTableRecord(id: 'T2', floorId: 'F1', capacity: 4),
        CompletedOnboardingTableRecord(id: 'T3', floorId: 'F1', capacity: 6),
      ],
      settingsDocumentExists: false,
    );

    expect(result.isValid, isTrue);
    expect(result.usedLegacyCompatibility, isTrue);
    expect(result.capacityTypes, <int>[2, 4, 6]);
    expect(
      result.queueUrl,
      'https://ezq-dev-cubiquitous.web.app/customer/'
      'the-spice-house-indiranagar',
    );
  });

  test('Grill Garden capacity types and queue URL are derived', () {
    final result = resolveCompletedOnboardingCompatibility(
      restaurantBranchId: 'grill-garden-old-airport-road',
      branchData: {'floorCount': 2, 'totalTables': 4},
      floorDocumentIds: const <String>['F1', 'F2'],
      tables: const <CompletedOnboardingTableRecord>[
        CompletedOnboardingTableRecord(id: 'T1', floorId: 'F1', capacity: 2),
        CompletedOnboardingTableRecord(id: 'T2', floorId: 'F1', capacity: 4),
        CompletedOnboardingTableRecord(id: 'T3', floorId: 'F2', capacity: 6),
        CompletedOnboardingTableRecord(id: 'T4', floorId: 'F2', capacity: 8),
      ],
      settingsDocumentExists: true,
    );

    expect(result.isValid, isTrue);
    expect(result.usedLegacyCompatibility, isTrue);
    expect(result.capacityTypes, <int>[2, 4, 6, 8]);
    expect(result.tableCountsByFloor, <List<int>>[
      <int>[1, 1, 0, 0],
      <int>[0, 0, 1, 1],
    ]);
    expect(
      result.queueUrl,
      'https://ezq-dev-cubiquitous.web.app/customer/'
      'grill-garden-old-airport-road',
    );
  });

  test('genuinely incomplete settings remain blocked', () {
    final result = resolveCompletedOnboardingCompatibility(
      restaurantBranchId: 'incomplete-branch',
      branchData: {
        'floorCount': 1,
        'totalTables': 1,
        'capacityTypes': <int>[4],
      },
      floorDocumentIds: const <String>['F1'],
      tables: const <CompletedOnboardingTableRecord>[
        CompletedOnboardingTableRecord(id: 'T1', floorId: 'F1', capacity: 4),
      ],
      settingsDocumentExists: false,
    );

    expect(result.isValid, isFalse);
    expect(result.error, contains('no equivalent legacy operational setting'));
  });

  test('corrupted floor and table counts remain blocked', () {
    final floorMismatch = resolveCompletedOnboardingCompatibility(
      restaurantBranchId: 'corrupt-branch',
      branchData: {'floorCount': 2, 'totalTables': 1},
      floorDocumentIds: const <String>['F1'],
      tables: const <CompletedOnboardingTableRecord>[
        CompletedOnboardingTableRecord(id: 'T1', floorId: 'F1', capacity: 4),
      ],
      settingsDocumentExists: true,
    );
    final tableMismatch = resolveCompletedOnboardingCompatibility(
      restaurantBranchId: 'corrupt-branch',
      branchData: {'floorCount': 1, 'totalTables': 2},
      floorDocumentIds: const <String>['F1'],
      tables: const <CompletedOnboardingTableRecord>[
        CompletedOnboardingTableRecord(id: 'T1', floorId: 'F1', capacity: 4),
      ],
      settingsDocumentExists: true,
    );

    expect(floorMismatch.isValid, isFalse);
    expect(floorMismatch.error, contains('Expected 2 floors'));
    expect(tableMismatch.isValid, isFalse);
    expect(tableMismatch.error, contains('Expected 2 tables'));
  });

  test('non-canonical floor IDs remain blocked', () {
    final result = resolveCompletedOnboardingCompatibility(
      restaurantBranchId: 'corrupt-branch',
      branchData: {'floorCount': 1, 'totalTables': 1},
      floorDocumentIds: const <String>['ground'],
      tables: const <CompletedOnboardingTableRecord>[
        CompletedOnboardingTableRecord(id: 'T1', floorId: 'F1', capacity: 4),
      ],
      settingsDocumentExists: true,
    );

    expect(result.isValid, isFalse);
    expect(result.error, contains('Floor document IDs must be F1'));
  });

  test('persisted capacity mismatch remains blocked rather than widened', () {
    final result = resolveCompletedOnboardingCompatibility(
      restaurantBranchId: 'corrupt-branch',
      branchData: {
        'floorCount': 1,
        'totalTables': 1,
        'capacityTypes': <int>[2],
      },
      floorDocumentIds: const <String>['F1'],
      tables: const <CompletedOnboardingTableRecord>[
        CompletedOnboardingTableRecord(id: 'T1', floorId: 'F1', capacity: 8),
      ],
      settingsDocumentExists: true,
    );

    expect(result.isValid, isFalse);
    expect(result.error, contains('invalid floorId or capacity'));
  });
}
