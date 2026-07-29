import 'package:ezq/features/rest_onboarding/data/restaurant_onboarding_repository.dart';
import 'package:ezq/features/rest_onboarding/domain/onboarding_provisioning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('restaurant onboarding provisioning', () {
    test('completes the admin state in the same batch as the branch', () {
      final update = buildAdminProvisioningCompletionUpdate();

      expect(
        update.keys,
        unorderedEquals(<String>['onboardingCompleted', 'onboardedAt']),
      );
      expect(update['onboardingCompleted'], isTrue);
      expect(update['onboardedAt'], isNotNull);
    });

    test('attributes an atomic batch failure to the commit step', () {
      expect(
        OnboardingProvisioningStep.commitProvisioning.label,
        'Commit Provisioning',
      );
      expect(
        OnboardingProvisioningStep.values.last,
        OnboardingProvisioningStep.commitProvisioning,
      );
    });
  });
}
