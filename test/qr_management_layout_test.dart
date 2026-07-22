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
}
