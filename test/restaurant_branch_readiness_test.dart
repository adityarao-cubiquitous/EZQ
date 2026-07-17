import 'package:ezq/features/customer/domain/restaurant_branch_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completed migrated branch without provisioning fields is ready', () {
    final readiness = evaluateRestaurantBranchReadiness(
      branchExists: true,
      branchData: {
        'isActive': true,
        'onboardingCompleted': true,
        'floorCount': 2,
        'totalTables': 25,
        'totalSeats': 92,
      },
    );

    expect(readiness.isReady, isTrue);
  });

  test('incomplete branch remains blocked', () {
    final readiness = evaluateRestaurantBranchReadiness(
      branchExists: true,
      branchData: {'isActive': true, 'onboardingCompleted': false},
    );

    expect(
      readiness.blockReason,
      RestaurantBranchReadinessBlockReason.setupIncomplete,
    );
  });

  test('inactive branch remains blocked', () {
    final readiness = evaluateRestaurantBranchReadiness(
      branchExists: true,
      branchData: {'isActive': false, 'onboardingCompleted': true},
    );

    expect(
      readiness.blockReason,
      RestaurantBranchReadinessBlockReason.branchUnavailable,
    );
  });

  test('explicitly disabled QR remains blocked', () {
    final readiness = evaluateRestaurantBranchReadiness(
      branchExists: true,
      branchData: {
        'isActive': true,
        'onboardingCompleted': true,
        'qrEnabled': false,
      },
    );

    expect(
      readiness.blockReason,
      RestaurantBranchReadinessBlockReason.qrDisabled,
    );
  });

  test('inactive parent restaurant blocks customer access', () {
    final readiness = evaluateRestaurantBranchReadiness(
      branchExists: true,
      branchData: {'isActive': true, 'onboardingCompleted': true},
      restaurantExists: true,
      restaurantData: {'isActive': false},
    );

    expect(
      readiness.blockReason,
      RestaurantBranchReadinessBlockReason.restaurantUnavailable,
    );
  });
}
