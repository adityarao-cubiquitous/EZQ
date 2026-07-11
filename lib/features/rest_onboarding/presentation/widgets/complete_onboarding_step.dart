import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/onboarding_provisioning.dart';

enum CompleteOnboardingViewState { provisioning, success, failure }

class CompleteOnboardingStep extends StatelessWidget {
  const CompleteOnboardingStep({
    super.key,
    required this.viewState,
    required this.restaurantName,
    required this.branchName,
    required this.restaurantId,
    required this.branchId,
    required this.createdAt,
    required this.adminEmail,
    required this.qrUrl,
    required this.floorCount,
    required this.selectedTableCapacities,
    required this.provisioningSteps,
    required this.provisioningPercent,
    required this.provisioningProgressValue,
    required this.currentProvisioningStep,
    required this.estimatedRemainingTime,
    required this.totalTables,
    required this.totalSeats,
    required this.failedStep,
    required this.errorMessage,
    required this.onBack,
    required this.onRetry,
    required this.onBackToReview,
    required this.onViewSummary,
    required this.onGoToDashboard,
  });

  final CompleteOnboardingViewState viewState;
  final String restaurantName;
  final String branchName;
  final String? restaurantId;
  final String? branchId;
  final DateTime? createdAt;
  final String? adminEmail;
  final String? qrUrl;
  final int floorCount;
  final List<int> selectedTableCapacities;
  final List<ProvisioningStepProgress> provisioningSteps;
  final int provisioningPercent;
  final double provisioningProgressValue;
  final String currentProvisioningStep;
  final String estimatedRemainingTime;
  final int totalTables;
  final int totalSeats;
  final OnboardingProvisioningStep? failedStep;
  final String? errorMessage;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final VoidCallback onBackToReview;
  final VoidCallback onViewSummary;
  final VoidCallback onGoToDashboard;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 768;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: switch (viewState) {
              CompleteOnboardingViewState.provisioning => _ProvisioningView(
                steps: provisioningSteps,
                percent: provisioningPercent,
                progressValue: provisioningProgressValue,
                currentStep: currentProvisioningStep,
                estimatedRemainingTime: estimatedRemainingTime,
              ),
              CompleteOnboardingViewState.failure => _ProvisioningFailureView(
                failedStep: failedStep,
                errorMessage: errorMessage,
                isMobile: isMobile,
                onRetry: onRetry,
                onBackToReview: onBackToReview,
              ),
              CompleteOnboardingViewState.success => _ProvisioningSuccessView(
                restaurantName: restaurantName,
                branchName: branchName,
                restaurantId: restaurantId,
                branchId: branchId,
                createdAt: createdAt,
                adminEmail: adminEmail,
                qrUrl: qrUrl,
                floorCount: floorCount,
                selectedTableCapacities: selectedTableCapacities,
                totalTables: totalTables,
                totalSeats: totalSeats,
                isMobile: isMobile,
                onDownloadSetupSummary: onViewSummary,
                onGoToDashboard: onGoToDashboard,
              ),
            },
          ),
        );
      },
    );
  }
}

class _ProvisioningView extends StatelessWidget {
  const _ProvisioningView({
    required this.steps,
    required this.percent,
    required this.progressValue,
    required this.currentStep,
    required this.estimatedRemainingTime,
  });

  final List<ProvisioningStepProgress> steps;
  final int percent;
  final double progressValue;
  final String currentStep;
  final String estimatedRemainingTime;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: _SectionPanel(
          surface: AppColors.softSurface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    color: AppColors.primaryTeal,
                    strokeWidth: 6,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Provisioning Restaurant',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.navyText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please keep this page open while setup completes.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progressValue.clamp(0, 1),
                  minHeight: 12,
                  backgroundColor: AppColors.background,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryTeal,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  _ProvisioningMetric(label: 'Complete', value: '$percent%'),
                  _ProvisioningMetric(
                    label: 'Current Step',
                    value: currentStep,
                  ),
                  _ProvisioningMetric(
                    label: 'Estimated Time',
                    value: estimatedRemainingTime,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              for (var index = 0; index < steps.length; index++) ...[
                _ProvisioningStepLine(progress: steps[index]),
                if (index != steps.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProvisioningMetric extends StatelessWidget {
  const _ProvisioningMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.navyText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProvisioningStepLine extends StatelessWidget {
  const _ProvisioningStepLine({required this.progress});

  final ProvisioningStepProgress progress;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (progress.status) {
      ProvisioningStepStatus.pending => (
        Icons.radio_button_unchecked_rounded,
        AppColors.mutedText,
      ),
      ProvisioningStepStatus.running => (
        Icons.sync_rounded,
        AppColors.accentPurple,
      ),
      ProvisioningStepStatus.complete => (
        Icons.check_circle_rounded,
        AppColors.primaryTeal,
      ),
      ProvisioningStepStatus.failed => (
        Icons.error_outline_rounded,
        AppColors.errorRed,
      ),
    };

    return Semantics(
      label: '${progress.step.label}: ${progress.status.name}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: progress.status == ProvisioningStepStatus.running
              ? AppColors.softSurface
              : AppColors.background,
          border: Border.all(
            color: progress.status == ProvisioningStepStatus.running
                ? AppColors.primaryTeal
                : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                progress.step.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.navyText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProvisioningFailureView extends StatelessWidget {
  const _ProvisioningFailureView({
    required this.failedStep,
    required this.errorMessage,
    required this.isMobile,
    required this.onRetry,
    required this.onBackToReview,
  });

  final OnboardingProvisioningStep? failedStep;
  final String? errorMessage;
  final bool isMobile;
  final VoidCallback onRetry;
  final VoidCallback onBackToReview;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: _SectionPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.errorRed,
                size: 58,
              ),
              const SizedBox(height: 16),
              Text(
                'Provisioning Failed',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.navyText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Setup stopped before continuing to the next step.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              _FailureDetail(
                label: 'Failed step',
                value: failedStep?.label ?? 'Unknown step',
              ),
              const SizedBox(height: 12),
              _FailureDetail(
                label: 'Error message',
                value: errorMessage ?? 'Unknown provisioning error',
              ),
              const SizedBox(height: 28),
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SecondaryButton(
                      label: 'Back to Review',
                      onPressed: onBackToReview,
                    ),
                    const SizedBox(height: 12),
                    _GradientButton(label: 'Retry', onPressed: onRetry),
                  ],
                )
              else
                Row(
                  children: [
                    _SecondaryButton(
                      label: 'Back to Review',
                      onPressed: onBackToReview,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 220,
                      child: _GradientButton(
                        label: 'Retry',
                        onPressed: onRetry,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailureDetail extends StatelessWidget {
  const _FailureDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.navyText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProvisioningSuccessView extends StatelessWidget {
  const _ProvisioningSuccessView({
    required this.restaurantName,
    required this.branchName,
    required this.restaurantId,
    required this.branchId,
    required this.createdAt,
    required this.adminEmail,
    required this.qrUrl,
    required this.floorCount,
    required this.selectedTableCapacities,
    required this.totalTables,
    required this.totalSeats,
    required this.isMobile,
    required this.onDownloadSetupSummary,
    required this.onGoToDashboard,
  });

  final String restaurantName;
  final String branchName;
  final String? restaurantId;
  final String? branchId;
  final DateTime? createdAt;
  final String? adminEmail;
  final String? qrUrl;
  final int floorCount;
  final List<int> selectedTableCapacities;
  final int totalTables;
  final int totalSeats;
  final bool isMobile;
  final VoidCallback onDownloadSetupSummary;
  final VoidCallback onGoToDashboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionPanel(
          surface: AppColors.softSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.progressGradient,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.background,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Restaurant Successfully Created',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.navyText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your onboarding setup is complete and ready for dashboard use.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Setup Summary',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.navyText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = constraints.maxWidth >= 960
                      ? (constraints.maxWidth - 32) / 3
                      : constraints.maxWidth >= 620
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: tileWidth,
                        height: 98,
                        child: _SummaryTile(
                          label: 'Restaurant Name',
                          value: restaurantName,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        height: 98,
                        child: _SummaryTile(
                          label: 'Branch Name',
                          value: branchName,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        height: 98,
                        child: _SummaryTile(
                          label: 'Restaurant ID',
                          value: restaurantId ?? 'Pending',
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        height: 98,
                        child: _SummaryTile(
                          label: 'Branch ID',
                          value: branchId ?? 'Pending',
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        height: 98,
                        child: _SummaryTile(
                          label: 'Date Created',
                          value: createdAt?.toIso8601String() ?? 'Pending',
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        height: 98,
                        child: _SummaryTile(
                          label: 'Admin Email',
                          value: adminEmail ?? 'Not available',
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        height: 98,
                        child: _SummaryTile(
                          label: 'QR URL',
                          value: qrUrl ?? 'Pending',
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        height: 98,
                        child: _SummaryTile(
                          label: 'Floors',
                          value: '$floorCount',
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        height: 98,
                        child: _SummaryTile(
                          label: 'Capacity Types',
                          value: '${selectedTableCapacities.length}',
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        height: 98,
                        child: _SummaryTile(
                          label: 'Tables',
                          value: '$totalTables',
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        height: 98,
                        child: _SummaryTile(
                          label: 'Seats',
                          value: '$totalSeats',
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionPanel(child: const _CompletionChecklist()),
        const SizedBox(height: 24),
        _SectionPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next steps',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.navyText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const _NextStepLine(text: 'Upload Logo'),
              const _NextStepLine(text: 'Configure Business Hours'),
              const _NextStepLine(text: 'Invite staff'),
              const _NextStepLine(text: 'Manage QR Codes'),
              const _NextStepLine(text: 'Configure Printers'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _FooterActions(
          isMobile: isMobile,
          onDownloadSetupSummary: onDownloadSetupSummary,
          onGoToDashboard: onGoToDashboard,
        ),
      ],
    );
  }
}

class _CompletionChecklist extends StatelessWidget {
  const _CompletionChecklist();

  @override
  Widget build(BuildContext context) {
    const items = [
      'Admin Account Created',
      'Restaurant Created',
      'Branch Created',
      'Restaurant Settings Created',
      'Branch Settings Created',
      'Floors Configured',
      'Tables Generated',
      'QR Configuration Ready',
      'Configuration Finalized',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Provisioning Checklist',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.navyText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth >= 960
                ? (constraints.maxWidth - 32) / 3
                : constraints.maxWidth >= 680
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final item in items)
                  SizedBox(
                    width: itemWidth,
                    child: _CompletionCheckLine(text: item),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CompletionCheckLine extends StatelessWidget {
  const _CompletionCheckLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$text complete',
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.softSurface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primaryTeal,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.navyText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.child, this.surface});

  final Widget child;
  final Color? surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surface ?? AppColors.background,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.navyText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStepLine extends StatelessWidget {
  const _NextStepLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.primaryTeal,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.navyText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.isMobile,
    required this.onDownloadSetupSummary,
    required this.onGoToDashboard,
  });

  final bool isMobile;
  final VoidCallback onDownloadSetupSummary;
  final VoidCallback onGoToDashboard;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SecondaryButton(
            label: 'Download Setup Summary',
            onPressed: onDownloadSetupSummary,
          ),
          const SizedBox(height: 12),
          _SecondaryButton(
            label: 'Manage QR',
            onPressed: () => _showComingSoon(context, 'QR management'),
          ),
          const SizedBox(height: 12),
          _GradientButton(label: 'Go to Dashboard', onPressed: onGoToDashboard),
        ],
      );
    }

    return Row(
      children: [
        const Spacer(),
        Flexible(
          child: _SecondaryButton(
            label: 'Download Setup Summary',
            onPressed: onDownloadSetupSummary,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: _SecondaryButton(
            label: 'Manage QR',
            onPressed: () => _showComingSoon(context, 'QR management'),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: _GradientButton(
            label: 'Go to Dashboard',
            onPressed: onGoToDashboard,
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label will be available after integration.')),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryTeal,
        side: const BorderSide(color: AppColors.primaryTeal),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.primaryTeal,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.progressGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.background,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
