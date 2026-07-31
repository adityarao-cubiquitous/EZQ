import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezq/features/admin/data/qr_management_repository.dart';
import 'package:ezq/features/admin/presentation/qr_management_panel.dart';

void main() {
  test(
    'desktop QR preview stays capped instead of expanding to dialog width',
    () {
      expect(
        qrPreviewSizeFor(maxWidth: 760, viewport: const Size(1366, 900)),
        220,
      );
    },
  );

  test('short landscape QR preview fits the available height', () {
    expect(
      qrPreviewSizeFor(maxWidth: 760, viewport: const Size(1024, 580)),
      132,
    );
  });

  testWidgets('canonical QR remains visible while metadata is loading', (
    tester,
  ) async {
    const args = (restaurantId: 'the-spice-house', branchId: 'indiranagar');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          branchQrInfoProvider(
            args,
          ).overrideWith((ref) => const Stream<BranchQrInfo>.empty()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 720,
              child: QrManagementPanel(
                restaurantId: 'the-spice-house',
                branchId: 'indiranagar',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('qr-code-preview')), findsOneWidget);
    expect(
      find.text(
        canonicalCustomerQueueUrl(
          restaurantId: args.restaurantId,
          branchId: args.branchId,
        ),
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shared QR dialog exposes the complete management action set', (
    tester,
  ) async {
    const args = (restaurantId: 'the-spice-house', branchId: 'indiranagar');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          branchQrInfoProvider(args).overrideWith(
            (ref) => Stream.value(
              const BranchQrInfo(
                restaurantId: 'the-spice-house',
                restaurantBranchId: 'the-spice-house-indiranagar',
                restaurantName: 'The Spice House',
                branchName: 'Indiranagar',
                queueUrl:
                    'https://ezq-dev-cubiquitous.web.app/customer/the-spice-house-indiranagar',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showQrManagementDialog(
                  context: context,
                  restaurantId: args.restaurantId,
                  branchId: args.branchId,
                ),
                child: const Text('Open QR'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open QR'));
    await tester.pumpAndSettle();

    expect(find.byType(QrManagementDialog), findsOneWidget);
    expect(find.byType(QrManagementPanel), findsOneWidget);
    expect(find.text('PNG'), findsOneWidget);
    expect(find.text('SVG'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);
  });
}
