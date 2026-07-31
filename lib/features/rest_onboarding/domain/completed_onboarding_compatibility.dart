class CompletedOnboardingTableRecord {
  const CompletedOnboardingTableRecord({
    required this.id,
    required this.floorId,
    required this.capacity,
  });

  final String id;
  final String floorId;
  final int capacity;
}

class CompletedOnboardingCompatibilityResult {
  const CompletedOnboardingCompatibilityResult._({
    required this.capacityTypes,
    required this.queueUrl,
    required this.tableCountsByFloor,
    required this.usedLegacyCompatibility,
    this.error,
  });

  const CompletedOnboardingCompatibilityResult.invalid(String error)
    : this._(
        capacityTypes: const <int>[],
        queueUrl: '',
        tableCountsByFloor: const <List<int>>[],
        usedLegacyCompatibility: false,
        error: error,
      );

  final List<int> capacityTypes;
  final String queueUrl;
  final List<List<int>> tableCountsByFloor;
  final bool usedLegacyCompatibility;
  final String? error;

  bool get isValid => error == null;
}

CompletedOnboardingCompatibilityResult resolveCompletedOnboardingCompatibility({
  required String restaurantBranchId,
  required Map<String, dynamic> branchData,
  required List<String> floorDocumentIds,
  required List<CompletedOnboardingTableRecord> tables,
  required bool settingsDocumentExists,
}) {
  final floorCount = _intFromValue(branchData['floorCount']);
  final totalTables = _intFromValue(branchData['totalTables']);
  if (floorCount <= 0) {
    return const CompletedOnboardingCompatibilityResult.invalid(
      'floorCount must be greater than zero.',
    );
  }
  if (floorDocumentIds.length != floorCount) {
    return CompletedOnboardingCompatibilityResult.invalid(
      'Expected $floorCount floors but found ${floorDocumentIds.length}.',
    );
  }
  final expectedFloorIds = {
    for (var floorNumber = 1; floorNumber <= floorCount; floorNumber++)
      'F$floorNumber',
  };
  if (floorDocumentIds.toSet().difference(expectedFloorIds).isNotEmpty ||
      expectedFloorIds.difference(floorDocumentIds.toSet()).isNotEmpty) {
    return CompletedOnboardingCompatibilityResult.invalid(
      'Floor document IDs must be ${expectedFloorIds.join(', ')}.',
    );
  }
  if (tables.length != totalTables) {
    return CompletedOnboardingCompatibilityResult.invalid(
      'Expected $totalTables tables but found ${tables.length}.',
    );
  }

  final hasLegacyOperationalSettings =
      _positiveInt(branchData['averageTurnoverMinutes']) ||
      _positiveInt(branchData['averageDiningMinutes']);
  if (!settingsDocumentExists && !hasLegacyOperationalSettings) {
    return const CompletedOnboardingCompatibilityResult.invalid(
      'settings/general is missing and no equivalent legacy operational '
      'setting exists.',
    );
  }

  final persistedCapacityTypes = _intListFromValue(branchData['capacityTypes']);
  final derivedCapacityTypes =
      tables
          .map((table) => table.capacity)
          .where((capacity) => capacity > 0)
          .toSet()
          .toList()
        ..sort();
  final capacityTypes = persistedCapacityTypes.isNotEmpty
      ? persistedCapacityTypes
      : derivedCapacityTypes;
  if (capacityTypes.isEmpty) {
    return const CompletedOnboardingCompatibilityResult.invalid(
      'No valid table capacity types are persisted or derivable.',
    );
  }

  final counts = List<List<int>>.generate(
    floorCount,
    (_) => List<int>.filled(capacityTypes.length, 0),
  );
  for (final table in tables) {
    final floorNumber = int.tryParse(table.floorId.replaceFirst('F', ''));
    final capacityIndex = capacityTypes.indexOf(table.capacity);
    if (floorNumber == null ||
        floorNumber < 1 ||
        floorNumber > floorCount ||
        table.floorId != 'F$floorNumber' ||
        capacityIndex < 0) {
      return CompletedOnboardingCompatibilityResult.invalid(
        'Table ${table.id} has an invalid floorId or capacity.',
      );
    }
    counts[floorNumber - 1][capacityIndex]++;
  }

  final persistedQueueUrl = (branchData['queueUrl'] as String? ?? '').trim();
  final queueUrl = persistedQueueUrl.isNotEmpty
      ? persistedQueueUrl
      : 'https://ezq-dev-cubiquitous.web.app/customer/$restaurantBranchId';
  return CompletedOnboardingCompatibilityResult._(
    capacityTypes: List<int>.unmodifiable(capacityTypes),
    queueUrl: queueUrl,
    tableCountsByFloor: List<List<int>>.unmodifiable(
      counts.map(List<int>.unmodifiable),
    ),
    usedLegacyCompatibility:
        !settingsDocumentExists ||
        persistedCapacityTypes.isEmpty ||
        persistedQueueUrl.isEmpty,
  );
}

bool _positiveInt(Object? value) => _intFromValue(value) > 0;

int _intFromValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<int> _intListFromValue(Object? value) {
  if (value is! Iterable) return const <int>[];
  return value.map(_intFromValue).where((item) => item > 0).toSet().toList()
    ..sort();
}
