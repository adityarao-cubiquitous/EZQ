import 'package:flutter/material.dart';

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
    return const AnalyticsHtmlViewer(assetPath: htmlAssetPath);
  }
}
