import 'package:ezq/app/customer_route_policy.dart';
import 'package:ezq/core/constants/firestore_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects the legacy two-segment customer entry route', () {
    expect(
      resolveLegacyCustomerRouteRedirect(
        '/customer/the-spice-house/indiranagar',
      ),
      invalidCustomerLinkPath,
    );
  });

  test('preserves every canonical customer route shape', () {
    for (final path in <String>[
      '/customer/the-spice-house-indiranagar',
      '/customer/the-spice-house-indiranagar/status/queue-entry',
      '/customer/the-spice-house-indiranagar/ready/queue-entry',
      '/customer/the-spice-house-indiranagar/seated/queue-entry',
      '/customer/the-spice-house-indiranagar/menu',
      '/customer/the-spice-house-indiranagar/support',
      '/customer/install',
    ]) {
      expect(resolveLegacyCustomerRouteRedirect(path), isNull, reason: path);
    }
  });

  test('customer route helpers never reconstruct split identity values', () {
    const restaurantBranchId = 'the-spice-house-indiranagar';
    const queueEntryId = 'queue-entry';

    expect(
      FirestorePaths.customerRoute(restaurantBranchId),
      '/customer/$restaurantBranchId',
    );
    expect(
      FirestorePaths.customerStatusRoute(restaurantBranchId, queueEntryId),
      '/customer/$restaurantBranchId/status/$queueEntryId',
    );
    expect(
      FirestorePaths.customerReadyRoute(restaurantBranchId, queueEntryId),
      '/customer/$restaurantBranchId/ready/$queueEntryId',
    );
    expect(
      FirestorePaths.customerSeatedRoute(restaurantBranchId, queueEntryId),
      '/customer/$restaurantBranchId/seated/$queueEntryId',
    );
  });

  test('does not affect admin, app, or public paths', () {
    for (final path in <String>['/', '/app/home', '/admin/branch/dashboard']) {
      expect(resolveLegacyCustomerRouteRedirect(path), isNull, reason: path);
    }
  });
}
