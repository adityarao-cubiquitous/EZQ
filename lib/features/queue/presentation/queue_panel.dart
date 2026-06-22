import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../tables/domain/restaurant_table.dart';
import '../domain/queue_entry.dart';
import '../domain/queue_status.dart';

class QueuePanel extends StatelessWidget {
  const QueuePanel({
    super.key,
    required this.queue,
    required this.availableTables,
    required this.onReserve,
    required this.onSkip,
  });

  final List<QueueEntry> queue;
  final List<RestaurantTable> availableTables;
  final void Function(QueueEntry entry) onReserve;
  final void Function(QueueEntry entry) onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1ABDC8D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Queue',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search token or name',
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final entry in queue) ...[
            _QueueEntryCard(
              entry: entry,
              availableTables: availableTables,
              onReserve: () => onReserve(entry),
              onSkip: () => onSkip(entry),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _QueueEntryCard extends StatelessWidget {
  const _QueueEntryCard({
    required this.entry,
    required this.availableTables,
    required this.onReserve,
    required this.onSkip,
  });

  final QueueEntry entry;
  final List<RestaurantTable> availableTables;
  final VoidCallback onReserve;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final canReserve = entry.status == QueueStatus.waiting;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1ABDC8D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.tokenCode,
                style: const TextStyle(
                  color: AppColors.deepTeal,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text('Party ${entry.partySize}'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${entry.estimatedWaitMinutes} min wait • ${entry.status.wireName}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: canReserve
                    ? EzqButton(
                        label: 'Reserve',
                        onPressed: availableTables.isEmpty
                            ? () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No available tables right now.',
                                  ),
                                ),
                              )
                            : onReserve,
                      )
                    : OutlinedButton(
                        onPressed: null,
                        child: Text(entry.status.wireName),
                      ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: canReserve ? onSkip : null,
                child: const Text('Skip'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
