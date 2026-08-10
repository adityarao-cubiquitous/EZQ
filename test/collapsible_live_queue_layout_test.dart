import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ezq/features/admin/presentation/widgets/collapsible_live_queue_layout.dart';

void main() {
  test('responsive breakpoint selects split only when width is usable', () {
    expect(useSplitLiveQueueLayout(width: 1440, height: 900), isTrue);
    expect(useSplitLiveQueueLayout(width: 1024, height: 768), isTrue);
    expect(useSplitLiveQueueLayout(width: 900, height: 700), isTrue);
    expect(useSplitLiveQueueLayout(width: 820, height: 1180), isFalse);
    expect(useSplitLiveQueueLayout(width: 844, height: 390), isFalse);
    expect(useSplitLiveQueueLayout(width: 390, height: 844), isFalse);
  });

  test('overlay width bound respects intended maximum and viewport', () {
    expect(liveQueueOverlayWidthBound(width: 768, pagePadding: 24), 560);
    expect(liveQueueOverlayWidthBound(width: 700, pagePadding: 24), 560);
    expect(liveQueueOverlayWidthBound(width: 600, pagePadding: 12), 528);
    expect(liveQueueOverlayWidthBound(width: 390, pagePadding: 12), 366);
    expect(liveQueueOverlayWidthBound(width: 390, pagePadding: 24), 342);
  });

  testWidgets('mouse drag continuously hides and reopens the queue safely', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: _LayoutHarness()));
    await tester.pumpAndSettle();

    final tablesFinder = find.byKey(const ValueKey('live-queue-tables-scroll'));
    const panelKey = ValueKey('live-queue-panel');
    const handleKey = ValueKey('live-queue-resize-handle');
    const visualHandleKey = ValueKey('live-queue-resize-handle-visual');
    final panelFinder = find.byKey(panelKey);
    final handleFinder = find.byKey(handleKey);
    final visualHandleFinder = find.byKey(visualHandleKey);
    final initialTablesWidth = tester.getSize(tablesFinder).width;
    final initialPanelWidth = tester.getSize(panelFinder).width;
    expect(find.text('Queue content'), findsOneWidget);
    expect(tester.getSize(handleFinder), const Size(48, 82));
    expect(tester.getSize(visualHandleFinder), const Size(33, 82));
    expect(find.byIcon(Icons.drag_indicator_rounded), findsOneWidget);
    expect(tester.getCenter(handleFinder).dy, closeTo(450, 1));
    expect(find.text('Open changes: 0'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('queue-search-probe')),
      'Q17',
    );
    final widenGesture = await tester.startGesture(
      tester.getCenter(handleFinder),
      kind: PointerDeviceKind.mouse,
    );
    for (var index = 0; index < 6; index++) {
      await widenGesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    await widenGesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Open changes: 0'), findsOneWidget);
    final widerPanelWidth = tester.getSize(panelFinder).width;
    expect(widerPanelWidth, closeTo(initialPanelWidth + 120, 2));
    expect(
      initialTablesWidth - tester.getSize(tablesFinder).width,
      closeTo(widerPanelWidth - initialPanelWidth, 2),
    );
    expect(find.text('Q17'), findsOneWidget);

    final hideGesture = await tester.startGesture(
      tester.getCenter(handleFinder),
      kind: PointerDeviceKind.mouse,
    );
    for (var index = 0; index < 12; index++) {
      await hideGesture.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Open changes: 0'), findsOneWidget);
    await hideGesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Open changes: 1'), findsOneWidget);
    expect(tester.getSize(panelFinder).width, 0);
    expect(find.text('Queue content'), findsNothing);
    expect(
      find
          .byKey(const ValueKey('queue-search-probe'), skipOffstage: false)
          .hitTestable(),
      findsNothing,
    );
    expect(handleFinder, findsOneWidget);
    expect(
      find.byIcon(Icons.keyboard_double_arrow_left_rounded),
      findsOneWidget,
    );
    expect(tester.getSize(tablesFinder).width, closeTo(1392, 2));
    expect(tester.takeException(), isNull);

    final reopenGesture = await tester.startGesture(
      tester.getCenter(handleFinder),
      kind: PointerDeviceKind.mouse,
    );
    for (var index = 0; index < 5; index++) {
      await reopenGesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Open changes: 1'), findsOneWidget);
    await reopenGesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Open changes: 2'), findsOneWidget);
    expect(tester.getSize(panelFinder).width, closeTo(300, 2));
    expect(find.text('Q17'), findsOneWidget);

    await tester.drag(handleFinder, const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(panelFinder).width, 620);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(900, 700);
    await tester.pumpAndSettle();
    expect(tester.getSize(panelFinder).width, 516);
    expect(find.text('Q17'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(700, 500);
    await tester.pumpAndSettle();
    expect(tester.getSize(panelFinder).width, 560);
    await tester.drag(handleFinder, const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(panelFinder).width, 560);
    expect(find.text('Q17'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.text('Q17'), findsOneWidget);
    expect(tester.getSize(panelFinder).width, 342);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(tester.getSize(panelFinder).width, 620);
    expect(find.text('Q17'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _LayoutHarness extends StatefulWidget {
  const _LayoutHarness();

  @override
  State<_LayoutHarness> createState() => _LayoutHarnessState();
}

class _LayoutHarnessState extends State<_LayoutHarness> {
  bool _isOpen = true;
  int _openChanges = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CollapsibleLiveQueueLayout(
            isLiveQueueOpen: _isOpen,
            onLiveQueueOpenChanged: (value) {
              setState(() {
                _isOpen = value;
                _openChanges++;
              });
            },
            tables: const SizedBox(height: 1600, child: Text('Tables content')),
            liveQueue: const _QueueProbe(),
          ),
          Text('Open changes: $_openChanges'),
        ],
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
