import 'package:flutter_riverpod/flutter_riverpod.dart';

class SeatingEta {
  const SeatingEta({
    required this.sharedMinutes,
    required this.emptyTableMinutes,
  });

  final int sharedMinutes;
  final int emptyTableMinutes;
}

class SeatingPreferenceService {
  const SeatingPreferenceService();

  static const int _baseWaitMinutes = 10;
  static const int _perPositionMinutes = 5;
  static const int _largPartyAddMinutes = 8;
  static const int _emptyTablePremiumMinutes = 12;
  static const int _maxSharedMinutes = 60;
  static const int _maxEmptyTableMinutes = 90;

  // Pre-join estimate: uses a conservative assumed position (3rd in queue).
  SeatingEta computeEtaEstimate({required int partySize}) {
    const assumedPosition = 3;
    final base =
        (_baseWaitMinutes + (assumedPosition - 1) * _perPositionMinutes)
            .clamp(5, _maxSharedMinutes)
            .toInt();

    // Larger parties have fewer tables available → shared wait is longer too.
    final sharedMinutes =
        (base + (partySize > 4 ? _largPartyAddMinutes : 0))
            .clamp(5, _maxSharedMinutes)
            .toInt();

    final emptyTableMinutes =
        (sharedMinutes + _emptyTablePremiumMinutes)
            .clamp(sharedMinutes + 1, _maxEmptyTableMinutes)
            .toInt();

    return SeatingEta(
      sharedMinutes: sharedMinutes,
      emptyTableMinutes: emptyTableMinutes,
    );
  }
}

final seatingPreferenceServiceProvider = Provider<SeatingPreferenceService>(
  (_) => const SeatingPreferenceService(),
);
