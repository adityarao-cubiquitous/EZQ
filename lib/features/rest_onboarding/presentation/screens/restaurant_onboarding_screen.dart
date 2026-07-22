import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../admin/presentation/widgets/admin_branch_identity_pill.dart';
import '../../../auth/data/auth_repository.dart';
import '../../providers/restaurant_onboarding_controller.dart';
import '../widgets/complete_onboarding_step.dart';
import '../widgets/floors_tables_step.dart';
import '../widgets/restaurant_details_step.dart';
import '../widgets/restaurant_onboarding_wizard_bar.dart';
import '../widgets/review_confirm_step.dart';

class RestaurantOnboardingScreen extends ConsumerStatefulWidget {
  const RestaurantOnboardingScreen({super.key});

  @override
  ConsumerState<RestaurantOnboardingScreen> createState() =>
      _RestaurantOnboardingScreenState();
}

class _RestaurantOnboardingScreenState
    extends ConsumerState<RestaurantOnboardingScreen> {
  static const _steps = [
    OnboardingWizardStep(number: 1, label: 'Restaurant & Branch Details'),
    OnboardingWizardStep(number: 2, label: 'Configure Floors & Tables'),
    OnboardingWizardStep(number: 3, label: 'Review & Confirm'),
    OnboardingWizardStep(number: 4, label: 'Complete Onboarding'),
  ];
  bool _didInitialize = false;

  RestaurantOnboardingController get _controller {
    return ref.read(restaurantOnboardingControllerProvider.notifier);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) return;
    _didInitialize = true;
    _initialize();
  }

  Future<void> _initialize() async {
    final restaurantBranchId = GoRouterState.of(
      context,
    ).pathParameters['restaurantBranchId']?.trim();
    debugPrint(
      '[ONBOARDING_INIT] ENTER _initialize '
      'pathRestaurantBranchId=${restaurantBranchId ?? ''}',
    );
    try {
      debugPrint(
        '[ONBOARDING_INIT] BEFORE await completedOnboardingForCurrentAdmin',
      );
      final completion = await _controller
          .completedOnboardingForCurrentAdmin()
          .timeout(const Duration(seconds: 12));
      debugPrint(
        '[ONBOARDING_INIT] AFTER await completedOnboardingForCurrentAdmin '
        'completion=${completion?.restaurantBranchId ?? 'null'}',
      );
      if (!mounted) return;
      if (completion != null) {
        debugPrint(
          '[ONBOARDING_INIT] REDIRECT dashboard '
          'restaurantBranchId=${completion.restaurantBranchId}',
        );
        context.go('/admin/${completion.restaurantBranchId}/dashboard');
        return;
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[ONBOARDING_INIT] completedOnboardingForCurrentAdmin failed: $error\n'
        '$stackTrace',
      );
      if (!mounted) return;
    }
    debugPrint('[ONBOARDING_INIT] BEFORE await loadAdminContext');
    await _controller.loadAdminContext(
      expectedRestaurantBranchId: restaurantBranchId,
    );
    debugPrint('[ONBOARDING_INIT] AFTER await loadAdminContext');
  }

  Future<void> _saveDraft() async {
    try {
      await _controller.saveDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save draft: $error')));
    }
  }

  Future<void> _logoutAdmin() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    try {
      await _controller.saveDraft();
    } catch (error, stackTrace) {
      debugPrint(
        '[ONBOARDING_LOGOUT] draft save failed before logout: $error\n'
        '$stackTrace',
      );
    }

    try {
      await ref.read(authRepositoryProvider).signOut();
      ref.invalidate(restaurantOnboardingControllerProvider);
      if (!mounted) return;
      context.go('/admin/login');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not logout: $error')));
    }
  }

  Future<void> _confirmReview() async {
    await _controller.startProvisioning();
  }

  Future<void> _retryProvisioning() async {
    await _controller.startProvisioning();
  }

  void _downloadSetupSummary(RestaurantOnboardingState state) {
    final result = state.provisioningResult;
    if (result == null) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Setup Summary'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(state.setupSummaryText(result)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _goToDashboard(RestaurantOnboardingState state) {
    final result = state.provisioningResult;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete provisioning first.')),
      );
      return;
    }
    context.go('/admin/${result.restaurantBranchId}/dashboard');
  }

  void _showProvisioningWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Provisioning is running. Keep this tab open.'),
      ),
    );
  }

  CompleteOnboardingViewState _completeViewState(
    RestaurantOnboardingState state,
  ) {
    if (state.isProvisioning) {
      return CompleteOnboardingViewState.provisioning;
    }
    if (state.failedProvisioningStep != null) {
      return CompleteOnboardingViewState.failure;
    }
    if (state.provisioningResult == null) {
      return CompleteOnboardingViewState.failure;
    }
    return CompleteOnboardingViewState.success;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(restaurantOnboardingControllerProvider);
    assert(state.debugAssertTableConfigurationInvariant());

    return PopScope(
      canPop: !state.lockNavigation,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (state.isProvisioning) {
          _showProvisioningWarning();
          return;
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.softerSurface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth <= 768;
              final horizontalPadding = isMobile ? 16.0 : 32.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OnboardingTopBar(
                    restaurantSlug: state.restaurantBranchId,
                    restaurantName: state.trimmedRestaurantName.isEmpty
                        ? state.restaurantBranchId
                        : state.trimmedRestaurantName,
                    onLogout: _logoutAdmin,
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      isMobile ? 16 : 24,
                      horizontalPadding,
                      0,
                    ),
                    child: RestaurantOnboardingWizardBar(
                      steps: _steps,
                      currentStepIndex: state.currentStepIndex,
                      completedStepIndexes: state.completedStepIndexes,
                      enabledStepIndexes: state.enabledStepIndexes,
                      onStepSelected: (index) {
                        if (state.isProvisioning) {
                          _showProvisioningWarning();
                          return;
                        }
                        _controller.selectStep(index);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1440),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: isMobile ? 16 : 24,
                          ),
                          child: _buildStepContent(state),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(RestaurantOnboardingState state) {
    if (state.isLoadingAdminContext) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryTeal),
      );
    }

    if (state.adminContextError != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warningOrange,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to Load Onboarding',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.navyText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.adminContextError!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _controller.loadAdminContext,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.currentStepIndex == 0) {
      return RestaurantDetailsStep(
        adminName: state.adminName,
        adminEmail: state.adminEmail,
        adminPhone: state.adminPhone,
        restaurantName: state.trimmedRestaurantName,
        branchName: state.trimmedBranchName,
        area: state.trimmedArea,
        address: state.address,
        canContinue: state.isStep1Valid,
        onSaveDraft: _saveDraft,
        onContinue: _controller.continueFromStep1,
      );
    }

    if (state.currentStepIndex == 1) {
      return FloorsTablesStep(
        floorCount: state.floorCount,
        selectedTableCapacities: state.selectedTableCapacities,
        tableCountsByFloor: state.tableCountsByFloor,
        showValidationError: state.showStep2ValidationError,
        canContinue: state.isStep2Valid,
        onFloorCountChanged: _controller.updateFloorCount,
        onTableCapacityAdded: _controller.addTableCapacity,
        onTableCapacityRemoved: _controller.removeTableCapacity,
        onTableCountChanged: _controller.updateTableCount,
        onBack: _controller.backFromStep2,
        onSaveDraft: _saveDraft,
        onContinue: _controller.continueFromStep2,
      );
    }

    if (state.currentStepIndex == 2) {
      return ReviewConfirmStep(
        restaurantName: state.trimmedRestaurantName,
        branchName: state.trimmedBranchName,
        area: state.trimmedArea,
        floorCount: state.floorCount,
        selectedTableCapacities: state.selectedTableCapacities,
        tableCountsByFloor: state.tableCountsByFloor,
        totalTables: state.totalTables,
        totalSeats: state.totalSeats,
        onBack: _controller.backFromStep3,
        onSaveDraft: _saveDraft,
        onConfirm: _confirmReview,
      );
    }

    return CompleteOnboardingStep(
      viewState: _completeViewState(state),
      restaurantName: state.trimmedRestaurantName,
      branchName: state.trimmedBranchName,
      restaurantId: state.provisioningResult?.restaurantBranchId,
      branchId: state.provisioningResult?.restaurantBranchId,
      createdAt: state.provisioningResult?.createdAt,
      adminEmail: state.provisioningResult?.adminEmail,
      qrUrl: state.provisioningResult?.qrUrl,
      floorCount: state.floorCount,
      selectedTableCapacities: state.selectedTableCapacities,
      provisioningSteps: state.provisioningProgress,
      provisioningPercent: state.provisioningPercent,
      provisioningProgressValue: state.provisioningProgressValue,
      currentProvisioningStep: state.currentProvisioningStepLabel,
      estimatedRemainingTime: state.estimatedRemainingTimeLabel,
      totalTables: state.totalTables,
      totalSeats: state.totalSeats,
      failedStep: state.failedProvisioningStep,
      errorMessage: state.provisioningErrorMessage,
      onBack: _controller.backFromStep4,
      onRetry: _retryProvisioning,
      onBackToReview: _controller.backToReviewFromFailure,
      onViewSummary: () => _downloadSetupSummary(state),
      onGoToDashboard: () => _goToDashboard(state),
    );
  }
}

class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({
    required this.restaurantSlug,
    required this.restaurantName,
    required this.onLogout,
  });

  final String restaurantSlug;
  final String restaurantName;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1100;
    final horizontalPadding = compact ? 14.0 : 32.0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        compact ? 12 : 0,
        horizontalPadding,
        compact ? 12 : 0,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.primaryTeal, width: 4),
          bottom: BorderSide(color: Color(0x1ABDC8D0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x12006687),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: compact
          ? Row(
              children: [
                const BrandMark(size: 50),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminBranchIdentityPill(
                    restaurantName: restaurantName,
                    restaurantSlug: restaurantSlug,
                    compact: true,
                  ),
                ),
                IconButton(
                  tooltip: 'Logout',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            )
          : SizedBox(
              height: 76,
              child: Row(
                children: [
                  const BrandMark(size: 70),
                  const SizedBox(width: 30),
                  AdminBranchIdentityPill(
                    restaurantName: restaurantName,
                    restaurantSlug: restaurantSlug,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Logout',
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
            ),
    );
  }
}
