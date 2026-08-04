import 'package:ezq/app/customer_route_policy.dart';
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

  test('does not affect admin, app, or public paths', () {
    for (final path in <String>['/', '/app/home', '/admin/branch/dashboard']) {
      expect(resolveLegacyCustomerRouteRedirect(path), isNull, reason: path);
    }
  });
}
