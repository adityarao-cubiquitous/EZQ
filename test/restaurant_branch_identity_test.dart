import 'package:ezq/core/constants/firestore_paths.dart';
import 'package:ezq/features/customer/domain/branch.dart';
import 'package:ezq/features/customer/domain/restaurant_branch_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses explicit restaurant and branch metadata', () {
    final branch = Branch.fromMap('sample-kitchen-central', {
      'restaurantName': 'Sample Kitchen',
      'branchName': 'Central',
      'displayName': 'Outdated Display Name',
    });

    expect(branch.restaurantName, 'Sample Kitchen');
    expect(branch.name, 'Central');
  });

  test('recovers identity from the canonical display name', () {
    final branch = Branch.fromMap('sample-kitchen-central', {
      'displayName': 'Sample Kitchen - Central',
    });

    expect(branch.restaurantName, 'Sample Kitchen');
    expect(branch.name, 'Central');
  });

  test('formats separate route slugs without exposing route syntax', () {
    final identity = resolveRestaurantBranchIdentity(
      restaurantBranchSlug: 'sample-kitchen-central-market',
      restaurantSlug: 'sample-kitchen',
      branchSlug: 'central-market',
    );

    expect(identity.restaurantName, 'Sample Kitchen');
    expect(identity.branchName, 'Central Market');
    expect(identity.restaurantBranchId, 'sample-kitchen-central-market');
  });

  test('unknown consolidated routes receive a clean generic fallback', () {
    final identity = resolveRestaurantBranchIdentity(
      restaurantBranchSlug: 'sample-kitchen-central-market',
    );

    expect(identity.restaurantName, 'Sample Kitchen Central Market');
    expect(identity.branchName, 'Main');
    expect(identity.restaurantName, isNot(contains('-')));
    expect(identity.branchName, isNot(contains('-')));
  });

  test('customer data operations reject split legacy identity values', () {
    expect(
      () => FirestorePaths.requireCanonicalRestaurantBranchId(
        'sample-kitchen',
        'central-market',
      ),
      throwsArgumentError,
    );
    expect(
      FirestorePaths.requireCanonicalRestaurantBranchId(
        'sample-kitchen-central-market',
        'sample-kitchen-central-market',
      ),
      'sample-kitchen-central-market',
    );
  });
}
