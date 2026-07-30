import 'package:ezq/features/customer/domain/restaurant_branch_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completed branch with canonical provisioning state is ready', () {
    final readiness = evaluateRestaurantBranchReadiness(
      branchExists: true,
      branchData: {
        'isActive': true,
        'onboardingCompleted': true,
        'provisioningStatus': 'completed',
        'floorCount': 2,
        'totalTables': 25,
        'totalSeats': 92,
      },
    );

    expect(readiness.isReady, isTrue);
  });

  test('completed branch without provisioningStatus remains blocked', () {
    final readiness = evaluateRestaurantBranchReadiness(
      branchExists: true,
      branchData: {'isActive': true, 'onboardingCompleted': true},
    );

    expect(
      readiness.blockReason,
      RestaurantBranchReadinessBlockReason.setupIncomplete,
    );
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
        'provisioningStatus': 'completed',
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
      branchData: {
        'isActive': true,
        'onboardingCompleted': true,
        'provisioningStatus': 'completed',
      },
      restaurantExists: true,
      restaurantData: {'isActive': false},
    );

    expect(
      readiness.blockReason,
      RestaurantBranchReadinessBlockReason.restaurantUnavailable,
    );
  });
}
