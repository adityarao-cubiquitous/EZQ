const adminLoginPath = '/admin/login';

String? resolveAdminAuthenticationRedirect({
  required String currentPath,
  required bool isAuthenticated,
}) {
  final isAdminChildRoute =
      currentPath.startsWith('/admin/') && currentPath != adminLoginPath;
  if (isAdminChildRoute && !isAuthenticated) return adminLoginPath;
  return null;
}

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
