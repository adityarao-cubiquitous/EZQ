import 'package:ezq/core/constants/app_colors.dart';
import 'package:ezq/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const responsiveViewports = <Size>[
    Size(1440, 900),
    Size(1000, 700),
    Size(1440, 400),
    Size(1024, 768),
    Size(900, 600),
    Size(768, 1024),
    Size(844, 500),
    Size(390, 844),
    Size(844, 390),
  ];

  for (final count in <int>[0, 4, 12, 99, 1234]) {
    testWidgets('Parties waiting $count stays contained at every viewport', (
      tester,
    ) async {
      for (final viewport in responsiveViewports) {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_MetricRow(waitingCount: count));
        await tester.pumpAndSettle();

        expect(find.text('Parties waiting'), findsOneWidget);
        expect(find.text('$count'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final card = tester.getRect(
          find.byKey(const ValueKey('admin-metric-card-Parties waiting')),
        );
        final label = tester.getRect(
          find.byKey(const ValueKey('admin-metric-label-Parties waiting')),
        );
        final value = tester.getRect(
          find.byKey(const ValueKey('admin-metric-value-Parties waiting')),
        );

        expect(card.contains(label.topLeft), isTrue);
        expect(card.contains(label.bottomRight), isTrue);
        expect(card.contains(value.topLeft), isTrue);
        expect(card.contains(value.bottomRight), isTrue);
        expect(label.bottom, lessThanOrEqualTo(value.top));
      }
    });
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.waitingCount});

  final int waitingCount;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: AdminDashboardMetric(
                    label: 'Free',
                    value: 7,
                    color: AppColors.primaryTeal,
                    selected: false,
                    onTap: _noop,
                    compact: true,
                  ),
                ),
                Expanded(
                  child: AdminDashboardMetric(
                    label: 'Occupied',
                    value: 8,
                    color: AppColors.errorRed,
                    selected: false,
                    onTap: _noop,
                    compact: true,
                  ),
                ),
                Expanded(
                  child: AdminDashboardMetric(
                    label: 'Parties waiting',
                    value: waitingCount,
                    color: AppColors.accentPurple,
                    selected: false,
                    onTap: _noop,
                    compact: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _noop() {}
}
