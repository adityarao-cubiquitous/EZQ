import 'package:flutter/material.dart';

import 'customer_queue_status_screen.dart';

/// Validated entry point for a seated deep link.
class SeatedView extends StatelessWidget {
  const SeatedView({
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
      routeExpectation: CustomerQueueRouteExpectation.seated,
    );
  }
}
