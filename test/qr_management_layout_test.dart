import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
