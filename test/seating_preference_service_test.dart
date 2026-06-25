import 'package:flutter_test/flutter_test.dart';

import 'package:ezq/features/customer/domain/seating_preference_service.dart';

void main() {
  const service = SeatingPreferenceService();

  group('SeatingPreferenceService.computeEtaEstimate', () {
    test('emptyTable ETA is always greater than shared ETA', () {
      for (var size = 1; size <= 20; size++) {
        final eta = service.computeEtaEstimate(partySize: size);
        expect(
          eta.emptyTableMinutes,
          greaterThan(eta.sharedMinutes),
          reason: 'party size $size: emptyTable must exceed shared',
        );
      }
    });

    test('all ETAs are positive for party sizes 1 through 10', () {
      for (var size = 1; size <= 10; size++) {
        final eta = service.computeEtaEstimate(partySize: size);
        expect(eta.sharedMinutes, greaterThan(0), reason: 'party size $size');
        expect(
          eta.emptyTableMinutes,
          greaterThan(0),
          reason: 'party size $size',
        );
      }
    });

    test('large party (5+) has a higher shared ETA than small party (≤4)', () {
      final small = service.computeEtaEstimate(partySize: 4);
      final large = service.computeEtaEstimate(partySize: 5);
      expect(
        large.sharedMinutes,
        greaterThan(small.sharedMinutes),
        reason: 'party of 5 should wait longer than party of 4',
      );
    });

    test('ETAs do not exceed configured ceilings', () {
      for (var size = 1; size <= 50; size++) {
        final eta = service.computeEtaEstimate(partySize: size);
        expect(eta.sharedMinutes, lessThanOrEqualTo(60));
        expect(eta.emptyTableMinutes, lessThanOrEqualTo(90));
      }
    });

    test('party size 1 and party size 4 both produce valid ETAs', () {
      final solo = service.computeEtaEstimate(partySize: 1);
      expect(solo.sharedMinutes, greaterThan(0));
      expect(solo.emptyTableMinutes, greaterThan(solo.sharedMinutes));

      final four = service.computeEtaEstimate(partySize: 4);
      expect(four.sharedMinutes, greaterThan(0));
      expect(four.emptyTableMinutes, greaterThan(four.sharedMinutes));
    });
  });
}
