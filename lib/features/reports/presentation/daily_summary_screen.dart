import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/reports_repository.dart';

class DailySummaryScreen extends ConsumerWidget {
  const DailySummaryScreen({
    super.key,
    required this.restaurantId,
    required this.branchId,
  });

  final String restaurantId;
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref
        .watch(reportsRepositoryProvider)
        .watchDailyCounter(
          restaurantId: restaurantId,
          branchId: branchId,
          businessDate: DateTimeUtils.businessDate(),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Summary')),
      body: StreamBuilder(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LoadingView();
          final counter = snapshot.data!;
          final metrics = {
            'Total joined': counter.totalJoined,
            'Total seated': counter.totalSeated,
            'Waiting now': counter.lastTokenNumber - counter.totalSeated,
            'Skipped': counter.totalSkipped,
            'No-show': counter.totalNoShow,
            'Cancelled': counter.totalCancelled,
            'Peak queue size': counter.peakQueueDepth,
          };
          return GridView.count(
            padding: const EdgeInsets.all(24),
            crossAxisCount: MediaQuery.sizeOf(context).width > 800 ? 4 : 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              for (final metric in metrics.entries)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x1ABDC8D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        metric.key,
                        style: const TextStyle(color: AppColors.mutedText),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${metric.value}',
                        style: const TextStyle(
                          color: AppColors.deepTeal,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
