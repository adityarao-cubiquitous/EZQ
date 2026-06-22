import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/ezq_button.dart';
import '../data/customer_queue_repository.dart';
import 'customer_shell.dart';

class TableReadyView extends ConsumerWidget {
  const TableReadyView({
    super.key,
    required this.restaurantId,
    required this.branchId,
    required this.queueEntryId,
  });

  final String restaurantId;
  final String branchId;
  final String queueEntryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomerShell(
      restaurantId: restaurantId,
      branchId: branchId,
      activeTab: CustomerTab.status,
      queueEntryId: queueEntryId,
      showBottomNav: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(33),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2212A9DC),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.table_restaurant,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Your table is ready!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Table T4 is being held for you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF3E484F), fontSize: 18),
              ),
              const SizedBox(height: 24),
              const Text(
                '05:00',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  color: AppColors.navyText,
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              EzqButton(
                label: "I'm on my way",
                onPressed: () async {
                  await ref
                      .read(customerQueueRepositoryProvider)
                      .markOnTheWay(
                        restaurantId: restaurantId,
                        branchId: branchId,
                        queueEntryId: queueEntryId,
                        phone: '+919876543210',
                      );
                  if (!context.mounted) return;
                  context.go(
                    '/customer/$restaurantId/$branchId/status/$queueEntryId',
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await ref
                      .read(customerQueueRepositoryProvider)
                      .extendHold(
                        restaurantId: restaurantId,
                        branchId: branchId,
                        queueEntryId: queueEntryId,
                        phone: '+919876543210',
                      );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('5 minute extension requested'),
                    ),
                  );
                },
                child: const Text('Need 5 more minutes'),
              ),
              const SizedBox(height: 18),
              const Text(
                'If you do not arrive in time, your place may be moved back in queue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.warningOrange),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
