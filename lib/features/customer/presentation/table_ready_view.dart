import 'package:flutter/material.dart';

import 'customer_queue_status_screen.dart';

/// Validated entry point for a table-ready deep link.
///
/// The canonical status renderer owns all persisted queue presentation. This
/// wrapper only narrows the accepted statuses so an arbitrary link cannot
/// fabricate a ready state.
class TableReadyView extends StatelessWidget {
  const TableReadyView({
    super.key,
    required this.restaurantBranchId,
    required this.queueEntryId,
  });

  final String restaurantBranchId;
  final String queueEntryId;

  @override
  Widget build(BuildContext context) {
    return CustomerQueueStatusScreen(
      restaurantBranchId: restaurantBranchId,
      queueEntryId: queueEntryId,
      routeExpectation: CustomerQueueRouteExpectation.tableReady,
    );
  }
}
