import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezq/features/admin/presentation/widgets/collapsible_live_queue_layout.dart';

void main() {
  test('responsive breakpoint selects split only when width is usable', () {
    expect(useSplitLiveQueueLayout(width: 1440, height: 900), isTrue);
    expect(useSplitLiveQueueLayout(width: 1024, height: 768), isTrue);
    expect(useSplitLiveQueueLayout(width: 820, height: 1180), isFalse);
    expect(useSplitLiveQueueLayout(width: 844, height: 390), isFalse);
    expect(useSplitLiveQueueLayout(width: 390, height: 844), isFalse);
  });

  testWidgets(
    'collapse expands tables and queue state survives close and rotation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: _LayoutHarness()));
      await tester.pumpAndSettle();

      final tablesFinder = find.byKey(
        const ValueKey('live-queue-tables-scroll'),
      );
      final expandedTablesWidth = tester.getSize(tablesFinder).width;
      expect(find.text('Queue content'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('live-queue-toggle'))),
        const Size(42, 120),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byIcon(Icons.close_fullscreen_rounded), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('queue-search-probe')),
        'Q17',
      );
      await tester.tap(find.byKey(const ValueKey('live-queue-toggle')));
      await tester.pumpAndSettle();

      final collapsedTablesWidth = tester.getSize(tablesFinder).width;
      expect(collapsedTablesWidth, greaterThan(expandedTablesWidth + 300));
      expect(find.text('Q17'), findsOneWidget);
      expect(find.byTooltip('Show Live Queue'), findsOneWidget);

      tester.view.physicalSize = const Size(820, 1180);
      await tester.pumpAndSettle();
      expect(find.text('Q17'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('live-queue-toggle')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide Live Queue'), findsOneWidget);
      expect(find.text('Q17'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show Live Queue'), findsOneWidget);
      expect(find.text('Q17'), findsOneWidget);
    },
  );
}

class _LayoutHarness extends StatefulWidget {
  const _LayoutHarness();

  @override
  State<_LayoutHarness> createState() => _LayoutHarnessState();
}

class _LayoutHarnessState extends State<_LayoutHarness> {
  bool _isOpen = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CollapsibleLiveQueueLayout(
        isLiveQueueOpen: _isOpen,
        onLiveQueueOpenChanged: (value) => setState(() => _isOpen = value),
        tables: const SizedBox(height: 1600, child: Text('Tables content')),
        liveQueue: const _QueueProbe(),
      ),
    );
  }
}

class _QueueProbe extends StatefulWidget {
  const _QueueProbe();

  @override
  State<_QueueProbe> createState() => _QueueProbeState();
}

class _QueueProbeState extends State<_QueueProbe> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SizedBox(
        height: 1400,
        child: Column(
          children: [
            const Text('Queue content'),
            TextField(
              key: const ValueKey('queue-search-probe'),
              controller: _controller,
            ),
          ],
        ),
      ),
    );
  }
}
