import 'package:ezq/features/customer/domain/branch.dart';
import 'package:ezq/features/customer/domain/restaurant_branch_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefers explicit Firestore restaurant and branch names', () {
    final identity = resolveRestaurantBranchIdentity(
      restaurantBranchSlug: 'wrong-slug-value',
      restaurantName: '  Actual Restaurant  ',
      branchName: '  Actual Branch  ',
    );

    expect(identity.restaurantName, 'Actual Restaurant');
    expect(identity.branchName, 'Actual Branch');
  });

  test('uses compatible name and displayName fields when needed', () {
    final identity = resolveRestaurantBranchIdentity(
      restaurantBranchSlug: 'legacy-document',
      legacyBranchName: 'Legacy Branch',
      displayName: 'Legacy Restaurant - Ignored Branch',
    );

    expect(identity.restaurantName, 'Legacy Restaurant');
    expect(identity.branchName, 'Legacy Branch');
  });

  test('resolves migrated Grill Garden document with missing names', () {
    final identity = resolveRestaurantBranchIdentity(
      restaurantBranchSlug: 'grill-garden-old-airport-road',
    );

    expect(identity.restaurantName, 'Grill Garden');
    expect(identity.branchName, 'Old Airport Road');
  });

  test('resolves Salad Studio and Pasta Pepper fallback names', () {
    final salad = resolveRestaurantBranchIdentity(
      restaurantBranchSlug: 'salad-studio-12th-main',
    );
    final pasta = resolveRestaurantBranchIdentity(
      restaurantBranchSlug: 'pasta-pepper-hal-2nd-stage',
    );

    expect(salad.restaurantName, 'Salad Studio');
    expect(salad.branchName, '12th Main');
    expect(pasta.restaurantName, 'Pasta Pepper');
    expect(pasta.branchName, 'HAL 2nd Stage');
  });

  test(
    'Branch maps canonical Firestore identity fields and serializes them',
    () {
      final branch = Branch.fromMap('sample-restaurant-sample-branch', {
        'restaurantName': 'Sample Restaurant',
        'branchName': 'Sample Branch',
        'branchSlug': 'sample-branch',
        'isActive': true,
      });

      expect(branch.restaurantName, 'Sample Restaurant');
      expect(branch.name, 'Sample Branch');
      expect(branch.toMap()['restaurantName'], 'Sample Restaurant');
      expect(branch.toMap()['branchName'], 'Sample Branch');
      expect(branch.toMap()['branchSlug'], 'sample-branch');
    },
  );
}
