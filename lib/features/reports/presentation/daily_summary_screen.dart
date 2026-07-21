import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../admin/presentation/admin_restaurant_display_name.dart';
import '../../admin/presentation/widgets/admin_branch_identity_pill.dart';
import 'analytics_html_viewer.dart';

class DailySummaryScreen extends StatelessWidget {
  const DailySummaryScreen({
    super.key,
    required this.restaurantId,
    required this.branchId,
  });

  final String restaurantId;
  final String branchId;

  static const htmlAssetPath = 'assets/analytics/ezq_analytics_v5.html';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _AnalyticsNavbar(
              restaurantName: adminRestaurantDisplayName(restaurantId),
              onBackToDashboard: () => context.go(
                '${FirestorePaths.adminRoute(restaurantId, branchId)}/dashboard',
              ),
            ),
            const Expanded(
              child: AnalyticsHtmlViewer(assetPath: htmlAssetPath),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsNavbar extends StatelessWidget {
  const _AnalyticsNavbar({
    required this.restaurantName,
    required this.onBackToDashboard,
  });

  final String restaurantName;
  final VoidCallback onBackToDashboard;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1100;
    final tablet = Responsive.isTablet(context);
    final horizontalPadding = compact ? 14.0 : 32.0;
    final title = Text(
      'Analytics Report',
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
    final controls = Row(
      children: [
        BrandMark(size: compact ? 50 : 70),
        SizedBox(width: compact ? 12 : 30),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AdminBranchIdentityPill(
              restaurantName: restaurantName,
              compact: compact,
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onBackToDashboard,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to Dashboard'),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        compact ? 12 : 0,
        horizontalPadding,
        compact ? 12 : 0,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.primaryTeal, width: 4),
          bottom: BorderSide(color: Color(0x1ABDC8D0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x12006687),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 50, child: controls),
                const SizedBox(height: 8),
                Center(child: title),
              ],
            )
          : SizedBox(
              height: tablet ? 72 : 76,
              child: Stack(
                children: [
                  Positioned.fill(child: controls),
                  Center(child: title),
                ],
              ),
            ),
    );
  }
}
