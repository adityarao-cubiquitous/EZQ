import 'package:ezq/features/rest_onboarding/presentation/widgets/complete_onboarding_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Manage QR delegates to the supplied shared dialog callback', (
    tester,
  ) async {
    var manageQrCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompleteOnboardingStep(
            viewState: CompleteOnboardingViewState.success,
            restaurantName: 'The Spice House',
            branchName: 'Indiranagar',
            restaurantId: 'the-spice-house-indiranagar',
            branchId: 'the-spice-house-indiranagar',
            createdAt: DateTime(2026, 7, 28),
            adminEmail: 'admin@example.com',
            qrUrl: '/customer/the-spice-house-indiranagar',
            floorCount: 1,
            selectedTableCapacities: const [4, 6],
            provisioningSteps: const [],
            provisioningPercent: 100,
            provisioningProgressValue: 1,
            currentProvisioningStep: 'Complete',
            estimatedRemainingTime: 'Done',
            totalTables: 8,
            totalSeats: 40,
            failedStep: null,
            errorMessage: null,
            onBack: () {},
            onRetry: () {},
            onBackToReview: () {},
            onViewSummary: () {},
            onManageQr: () => manageQrCount++,
            onGoToDashboard: () {},
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Manage QR'));
    await tester.tap(find.text('Manage QR'));

    expect(manageQrCount, 1);
    expect(find.byType(SnackBar), findsNothing);
  });
}
