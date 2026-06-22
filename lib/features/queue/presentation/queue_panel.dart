import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
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
    final compact = Responsive.isCompact(context);
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1ABDC8D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Queue',
            style: TextStyle(
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
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
          SizedBox(height: compact ? 12 : 16),
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
    final compact = Responsive.isCompact(context);
    final canReserve = entry.status == QueueStatus.waiting;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
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
                style: TextStyle(
                  color: AppColors.deepTeal,
                  fontFamily: 'JetBrains Mono',
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: Text(
                  entry.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'Party ${entry.partySize}',
                style: TextStyle(fontSize: compact ? 12 : 14),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            '${entry.estimatedWaitMinutes} min wait • ${entry.status.wireName}',
            style: TextStyle(fontSize: compact ? 12 : 14),
          ),
          SizedBox(height: compact ? 10 : 12),
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReserveAction(
                  canReserve: canReserve,
                  availableTables: availableTables,
                  statusLabel: entry.status.wireName,
                  onReserve: onReserve,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: canReserve ? onSkip : null,
                  child: const Text('Skip'),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _ReserveAction(
                    canReserve: canReserve,
                    availableTables: availableTables,
                    statusLabel: entry.status.wireName,
                    onReserve: onReserve,
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

class _ReserveAction extends StatelessWidget {
  const _ReserveAction({
    required this.canReserve,
    required this.availableTables,
    required this.statusLabel,
    required this.onReserve,
  });

  final bool canReserve;
  final List<RestaurantTable> availableTables;
  final String statusLabel;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    if (!canReserve) {
      return OutlinedButton(onPressed: null, child: Text(statusLabel));
    }
    return EzqButton(
      label: 'Reserve',
      onPressed: availableTables.isEmpty
          ? () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No available tables right now.')),
            )
          : onReserve,
    );
  }
}
