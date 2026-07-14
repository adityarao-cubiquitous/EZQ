import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/admin_repository.dart';

class BranchSelectorScreen extends ConsumerWidget {
  const BranchSelectorScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref
        .watch(adminRepositoryProvider)
        .watchBranches(restaurantId);
    return Scaffold(
      appBar: AppBar(title: const Text('Select Branch')),
      body: StreamBuilder(
        stream: branches,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LoadingView();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: GridView.count(
                padding: const EdgeInsets.all(24),
                crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 2 : 1,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 2.6,
                children: [
                  for (final branch in snapshot.data!)
                    InkWell(
                      onTap: () => context.go(
                        '${FirestorePaths.adminRoute(restaurantId, branch.id)}/dashboard',
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x1ABDC8D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              branch.name,
                              style: const TextStyle(
                                color: AppColors.navyText,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(branch.address),
                            const SizedBox(height: 12),
                            const Text(
                              'Today: 18 joined',
                              style: TextStyle(color: AppColors.deepTeal),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
