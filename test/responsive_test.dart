import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezq/core/utils/responsive.dart';

void main() {
  testWidgets('phone landscape detection excludes portrait and tablets', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> expectPhoneLandscape(Size size, bool expected) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) =>
                Text(Responsive.isPhoneLandscape(context).toString()),
          ),
        ),
      );
      expect(find.text(expected.toString()), findsOneWidget);
    }

    await expectPhoneLandscape(const Size(844, 390), true);
    await expectPhoneLandscape(const Size(390, 844), false);
    await expectPhoneLandscape(const Size(1024, 768), false);

    debugDefaultTargetPlatformOverride = null;
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('phone landscape detection excludes desktop platforms', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              Text(Responsive.isPhoneLandscape(context).toString()),
        ),
      ),
    );

    expect(find.text('false'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
