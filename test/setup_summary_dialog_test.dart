import 'package:ezq/core/widgets/dialog_close_button.dart';
import 'package:ezq/features/rest_onboarding/presentation/widgets/setup_summary_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openSummary(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) =>
                    const SetupSummaryDialog(summaryText: 'Summary details'),
              ),
              child: const Text('Open summary'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open summary'));
    await tester.pumpAndSettle();
  }

  testWidgets('uses the shared accessible top-right close control', (
    tester,
  ) async {
    await openSummary(tester);

    expect(find.byType(SetupSummaryDialog), findsOneWidget);
    expect(find.byType(DialogCloseButton), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-summary-close')), findsOneWidget);
    expect(find.byTooltip('Close Setup Summary'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Close'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('setup-summary-close')));
    await tester.pumpAndSettle();

    expect(find.byType(SetupSummaryDialog), findsNothing);
  });

  testWidgets('retains Escape-key dismissal', (tester) async {
    await openSummary(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(SetupSummaryDialog), findsNothing);
  });
}
