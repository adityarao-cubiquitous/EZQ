import 'package:ezq/app/ezq_app.dart';
import 'package:ezq/features/customer/data/customer_branch_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _TestCustomerBranchRepository implements CustomerBranchRepository {
  const _TestCustomerBranchRepository();

  @override
  Stream<CustomerBranchDisplay> watchBranchDisplay({
    required String restaurantId,
    required String branchId,
  }) {
    return Stream.value(
      CustomerBranchDisplay(
        restaurantId: restaurantId,
        branchId: branchId,
        restaurantName: 'The Spice House',
        branchName: 'Indiranagar',
        isRestaurantActive: true,
        isBranchActive: true,
      ),
    );
  }
}

void main() {
  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('EZQ customer buttons navigate and respond', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerBranchRepositoryProvider.overrideWithValue(
            const _TestCustomerBranchRepository(),
          ),
        ],
        child: const EzqApp(),
      ),
    );
    await pumpFrames(tester);

    expect(find.text('EZQ Camera Lens'), findsOneWidget);
    expect(find.text('Open queue'), findsOneWidget);
    expect(find.text('The Spice House'), findsNothing);

    GoRouter.of(
      tester.element(find.text('EZQ Camera Lens')),
    ).go('/customer/the-spice-house/indiranagar');
    await pumpFrames(tester);

    expect(find.text('The Spice House'), findsOneWidget);
    expect(find.text('Join Queue'), findsOneWidget);
    expect(find.text('No app install required'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Alex Johnson');
    await tester.tap(find.text('4 people'));
    await pumpFrames(tester);
    await tester.tap(find.text('2 people').last);
    await pumpFrames(tester);
    expect(find.text('2 people'), findsWidgets);

    await tester.ensureVisible(find.text('Join Queue'));
    await tester.tap(find.text('Join Queue'));
    await pumpFrames(tester);
    expect(find.text('Q07'), findsOneWidget);
    expect(find.text('Cancel Reservation'), findsOneWidget);

    await tester.ensureVisible(find.text('View Menu'));
    await tester.tap(find.text('View Menu'));
    await pumpFrames(tester);
    expect(find.text('The Spice House Menu'), findsOneWidget);
    expect(find.text('Indiranagar'), findsWidgets);

    final supportTab = find.text('Support').last;
    await tester.ensureVisible(supportTab);
    await tester.tap(supportTab);
    await pumpFrames(tester);
    expect(find.text('Need help with your queue token?'), findsOneWidget);

    final statusTab = find.text('My\nStatus').last;
    await tester.ensureVisible(statusTab);
    await tester.tap(statusTab);
    await pumpFrames(tester);
    await tester.ensureVisible(find.text('Cancel Reservation'));
    await tester.tap(find.text('Cancel Reservation'));
    await tester.pump();
    expect(find.text('Reservation cancelled'), findsWidgets);
  });
}
