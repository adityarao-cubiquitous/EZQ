import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class OnboardingWizardStep {
  const OnboardingWizardStep({required this.number, required this.label});

  final int number;
  final String label;
}

class RestaurantOnboardingWizardBar extends StatelessWidget {
  const RestaurantOnboardingWizardBar({
    super.key,
    required this.steps,
    required this.currentStepIndex,
    required this.completedStepIndexes,
    required this.enabledStepIndexes,
    required this.onStepSelected,
  });

  final List<OnboardingWizardStep> steps;
  final int currentStepIndex;
  final Set<int> completedStepIndexes;
  final Set<int> enabledStepIndexes;
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width <= 768;
        final isTablet = width > 768 && width <= 1024;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: (currentStepIndex + 1) / steps.length,
                  backgroundColor: AppColors.softSurface,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryTeal,
                  ),
                ),
              ),
              Container(
                height: 5,
                decoration: const BoxDecoration(
                  gradient: AppColors.progressGradient,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 16,
                  vertical: isMobile ? 10 : 14,
                ),
                child: Row(
                  children: [
                    for (var index = 0; index < steps.length; index++) ...[
                      Expanded(
                        child: _WizardStepButton(
                          step: steps[index],
                          index: index,
                          isCurrent: index == currentStepIndex,
                          isCompleted: completedStepIndexes.contains(index),
                          isEnabled: enabledStepIndexes.contains(index),
                          isMobile: isMobile,
                          isTablet: isTablet,
                          onTap: () => onStepSelected(index),
                        ),
                      ),
                      if (index != steps.length - 1)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 4 : 8,
                          ),
                          child: Text(
                            isMobile ? '>' : '',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: AppColors.mutedText,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WizardStepButton extends StatelessWidget {
  const _WizardStepButton({
    required this.step,
    required this.index,
    required this.isCurrent,
    required this.isCompleted,
    required this.isEnabled,
    required this.isMobile,
    required this.isTablet,
    required this.onTap,
  });

  final OnboardingWizardStep step;
  final int index;
  final bool isCurrent;
  final bool isCompleted;
  final bool isEnabled;
  final bool isMobile;
  final bool isTablet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = isMobile
        ? '${step.number}'
        : isTablet
        ? _compactLabel(step.label)
        : '${step.number}. ${step.label}';

    return Semantics(
      button: true,
      enabled: isEnabled,
      selected: isCurrent,
      label: '${step.number} ${step.label}',
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 6 : 10,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: isCurrent ? AppColors.softSurface : AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCurrent
                  ? AppColors.primaryTeal
                  : isCompleted
                  ? AppColors.accentPurple
                  : !isEnabled
                  ? AppColors.softSurface
                  : AppColors.line,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: isMobile ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textTheme.labelLarge?.copyWith(
                    color: isCurrent
                        ? AppColors.primaryTeal
                        : isCompleted
                        ? AppColors.accentPurple
                        : !isEnabled
                        ? AppColors.mutedText
                        : AppColors.navyText,
                    fontWeight: isCurrent || isCompleted
                        ? FontWeight.w800
                        : FontWeight.w700,
                  ),
                ),
              ),
              if (!isMobile && isCompleted) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppColors.accentPurple,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _compactLabel(String label) {
    return switch (index) {
      0 => 'Restaurant',
      1 => 'Tables',
      2 => 'Review',
      _ => 'Complete',
    };
  }
}
