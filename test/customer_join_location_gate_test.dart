import 'package:ezq/features/customer/data/branch_identity_repository.dart';
import 'package:ezq/features/customer/domain/branch.dart';
import 'package:ezq/features/customer/domain/restaurant_branch_identity.dart';
import 'package:ezq/features/customer/presentation/customer_join_location_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allows customers within the 2 km join radius', () {
    expect(isWithinCustomerJoinRadius(distanceMeters: 0), isTrue);
    expect(isWithinCustomerJoinRadius(distanceMeters: 1999.9), isTrue);
    expect(isWithinCustomerJoinRadius(distanceMeters: 2000), isTrue);
  });

  test('blocks customers outside the 2 km join radius', () {
    expect(isWithinCustomerJoinRadius(distanceMeters: 2000.1), isFalse);
    expect(isWithinCustomerJoinRadius(distanceMeters: 2500), isFalse);
  });

  test('formats distance labels for blocked join copy', () {
    expect(customerJoinDistanceLabel(850), '850 m');
    expect(customerJoinDistanceLabel(2450), '2.5 km');
  });

  testWidgets('opens the join form child when customer is nearby', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        result: const CustomerJoinVicinityResult.allowed(distanceMeters: 320),
        child: const Text('Join form opened'),
      ),
    );
    await tester.pump();

    expect(find.text('Join form opened'), findsOneWidget);
    expect(find.text('You are too far away'), findsNothing);
  });

  testWidgets('blocks the join form when customer is outside 2 km', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        result: const CustomerJoinVicinityResult.blocked(
          failureType: CustomerJoinVicinityFailureType.outsideRadius,
          distanceMeters: 2450,
        ),
        child: const Text('Join form opened'),
      ),
    );
    await tester.pump();

    expect(find.text('Join form opened'), findsNothing);
    expect(find.text('You are too far away'), findsOneWidget);
    expect(find.textContaining('2.5 km away'), findsOneWidget);
    expect(find.text('Check location again'), findsOneWidget);
  });

  testWidgets('blocks the join form when restaurant GPS is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        result: const CustomerJoinVicinityResult.blocked(
          failureType: CustomerJoinVicinityFailureType.branchLocationMissing,
        ),
        child: const Text('Join form opened'),
      ),
    );
    await tester.pump();

    expect(find.text('Join form opened'), findsNothing);
    expect(find.text('Location check unavailable'), findsOneWidget);
    expect(
      find.textContaining('has not added its map location'),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows app settings action when permission is permanently denied',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          result: const CustomerJoinVicinityResult.blocked(
            failureType:
                CustomerJoinVicinityFailureType.permissionDeniedForever,
          ),
          child: const Text('Join form opened'),
        ),
      );
      await tester.pump();

      expect(find.text('Location permission is off'), findsOneWidget);
      expect(find.text('Open App Settings'), findsOneWidget);
    },
  );

  testWidgets(
    'retry can re-open the join form after a blocked location state',
    (tester) async {
      final verifier = _SequencedJoinVicinityVerifier([
        const CustomerJoinVicinityResult.blocked(
          failureType: CustomerJoinVicinityFailureType.permissionDenied,
        ),
        const CustomerJoinVicinityResult.allowed(distanceMeters: 110),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerJoinVicinityVerifierProvider.overrideWithValue(verifier),
          ],
          child: const MaterialApp(
            home: CustomerJoinLocationGate(
              branchLink: _branchLink,
              child: Text('Join form opened'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Allow location access'), findsOneWidget);
      expect(find.text('Join form opened'), findsNothing);

      await tester.tap(find.text('Check location again'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Join form opened'), findsOneWidget);
      expect(verifier.calls, 2);
    },
  );
}

Widget _testApp({
  required CustomerJoinVicinityResult result,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      customerJoinVicinityVerifierProvider.overrideWithValue(
        _FakeJoinVicinityVerifier(result),
      ),
    ],
    child: MaterialApp(
      home: CustomerJoinLocationGate(branchLink: _branchLink, child: child),
    ),
  );
}

const _branchLink = CustomerBranchLink(
  identity: RestaurantBranchIdentity(
    restaurantBranchId: 'salad-studio-12th-main',
    restaurantName: 'Salad Studio',
    branchName: '12th Main',
  ),
  branch: Branch(
    id: 'salad-studio-12th-main',
    name: '12th Main',
    address: '12th Main, Bengaluru',
    city: 'Bengaluru',
    state: 'Karnataka',
    country: 'India',
    timezone: 'Asia/Kolkata',
    qrSlug: 'salad-studio-12th-main',
    isActive: true,
    averageDiningMinutes: 35,
    averageCleaningMinutes: 5,
    holdMinutes: 5,
    latitude: 12.89174,
    longitude: 77.59273,
  ),
);

class _FakeJoinVicinityVerifier implements CustomerJoinVicinityVerifier {
  const _FakeJoinVicinityVerifier(this.result);

  final CustomerJoinVicinityResult result;

  @override
  Future<CustomerJoinVicinityResult> verify(
    CustomerBranchLink branchLink,
  ) async {
    return result;
  }
}

class _SequencedJoinVicinityVerifier implements CustomerJoinVicinityVerifier {
  _SequencedJoinVicinityVerifier(this.results);

  final List<CustomerJoinVicinityResult> results;
  int calls = 0;

  @override
  Future<CustomerJoinVicinityResult> verify(
    CustomerBranchLink branchLink,
  ) async {
    final index = calls.clamp(0, results.length - 1);
    calls += 1;
    return results[index];
  }
}
