import 'package:ezq/app/admin_branch_route_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const branchId = 'the-spice-house-indiranagar';
  const onboardingPath = '/admin/$branchId/register/onboarding';
  const dashboardPath = '/admin/$branchId/dashboard';
  const reportsPath = '/admin/$branchId/reports';

  test('completed onboarding remains at an explicitly opened summary URL', () {
    expect(
      resolveAdminBranchRouteRedirect(
        currentPath: onboardingPath,
        restaurantBranchId: branchId,
        branchReady: true,
        allowCompletedOnboardingSummary: true,
      ),
      isNull,
    );
  });

  test('completed dashboard route remains unchanged for normal login', () {
    expect(
      resolveAdminBranchRouteRedirect(
        currentPath: dashboardPath,
        restaurantBranchId: branchId,
        branchReady: true,
        allowCompletedOnboardingSummary: false,
      ),
      isNull,
    );
  });

  test(
    'incomplete branch is still redirected from dashboard to onboarding',
    () {
      expect(
        resolveAdminBranchRouteRedirect(
          currentPath: dashboardPath,
          restaurantBranchId: branchId,
          branchReady: false,
          allowCompletedOnboardingSummary: false,
        ),
        onboardingPath,
      );
    },
  );

  test('incomplete branch is redirected from reports to onboarding', () {
    expect(
      resolveAdminBranchRouteRedirect(
        currentPath: reportsPath,
        restaurantBranchId: branchId,
        branchReady: false,
        allowCompletedOnboardingSummary: false,
      ),
      onboardingPath,
    );
  });

  test('corrupted completed branch may remain on onboarding error screen', () {
    expect(
      resolveAdminBranchRouteRedirect(
        currentPath: onboardingPath,
        restaurantBranchId: branchId,
        branchReady: false,
        allowCompletedOnboardingSummary: true,
      ),
      isNull,
    );
  });
}
