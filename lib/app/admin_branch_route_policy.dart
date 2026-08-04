String? resolveAdminBranchRouteRedirect({
  required String currentPath,
  required String restaurantBranchId,
  required bool branchReady,
  required bool allowCompletedOnboardingSummary,
}) {
  final onboardingPath = '/admin/$restaurantBranchId/register/onboarding';
  final dashboardPath = '/admin/$restaurantBranchId/dashboard';
  final reportsPath = '/admin/$restaurantBranchId/reports';

  if (branchReady &&
      ((allowCompletedOnboardingSummary && currentPath == onboardingPath) ||
          currentPath == reportsPath)) {
    return null;
  }

  final destination = branchReady ? dashboardPath : onboardingPath;
  return currentPath == destination ? null : destination;
}
