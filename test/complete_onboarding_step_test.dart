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
        home: Scaffold(body: _successStep(onManageQr: () => manageQrCount++)),
      ),
    );

    await tester.ensureVisible(find.text('Manage QR'));
    await tester.tap(find.text('Manage QR'));

    expect(manageQrCount, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  for (final size in <Size>[
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1440, 1200),
  ]) {
    testWidgets('inline setup summary fits ${size.width.toInt()}px viewport', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _successStep())),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Setup Summary'), findsOneWidget);
      expect(find.text('Provisioning Checklist'), findsNothing);
      expect(find.text('View Setup Summary'), findsNothing);
      expect(find.text('4 Top, 6 Top'), findsOneWidget);
      expect(find.text('Manage QR'), findsOneWidget);
      expect(find.text('Go to Dashboard'), findsOneWidget);
    });
  }
}

CompleteOnboardingStep _successStep({VoidCallback? onManageQr}) {
  return CompleteOnboardingStep(
    viewState: CompleteOnboardingViewState.success,
    restaurantName: 'The Spice House',
    branchName: 'Indiranagar',
    restaurantId: 'the-spice-house-indiranagar',
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
    onManageQr: onManageQr ?? () {},
    onGoToDashboard: () {},
  );
}
