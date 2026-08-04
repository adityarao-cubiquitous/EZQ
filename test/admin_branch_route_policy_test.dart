import 'package:ezq/app/admin_branch_route_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const branchId = 'the-spice-house-indiranagar';
  const onboardingPath = '/admin/$branchId/register/onboarding';
  const dashboardPath = '/admin/$branchId/dashboard';
  const reportsPath = '/admin/$branchId/reports';

  group('admin authentication route policy', () {
    test('redirects every unauthenticated admin child route to login', () {
      for (final path in <String>[
        '/admin/branch-a/dashboard',
        '/admin/branch-a/reports',
        '/admin/branch-a/analytics',
        '/admin/branch-a/register/onboarding',
        '/admin/register/onboarding',
      ]) {
        expect(
          resolveAdminAuthenticationRedirect(
            currentPath: path,
            isAuthenticated: false,
          ),
          adminLoginPath,
          reason: path,
        );
      }
    });

    test('does not redirect login or non-admin routes', () {
      for (final path in <String>[
        adminLoginPath,
        '/',
        '/customer/branch-a',
        '/app/home',
      ]) {
        expect(
          resolveAdminAuthenticationRedirect(
            currentPath: path,
            isAuthenticated: false,
          ),
          isNull,
          reason: path,
        );
      }
    });

    test('preserves authenticated admin child routes', () {
      expect(
        resolveAdminAuthenticationRedirect(
          currentPath: reportsPath,
          isAuthenticated: true,
        ),
        isNull,
      );
    });
  });

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

  test('completed branch remains on reports', () {
    expect(
      resolveAdminBranchRouteRedirect(
        currentPath: reportsPath,
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
