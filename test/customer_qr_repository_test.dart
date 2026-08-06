import 'package:ezq/features/customer/data/customer_qr_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts canonical RestaurantBranch customer links', () {
    expect(
      customerRouteFromQrValue(
        'https://ezq.example/customer/the-spice-house-indiranagar',
      ),
      '/customer/the-spice-house-indiranagar',
    );
    expect(
      customerRouteFromQrValue(
        'https://ezq.example/scan?restaurantBranchId=biryani-bay-domlur-edge',
      ),
      '/customer/biryani-bay-domlur-edge',
    );
  });

  test('rejects legacy two-segment customer links and query identities', () {
    expect(
      customerRouteFromQrValue(
        'https://ezq.example/customer/the-spice-house/indiranagar',
      ),
      isNull,
    );
    expect(
      customerRouteFromQrValue(
        'https://ezq.example/scan?restaurantId=the-spice-house&branchId=indiranagar',
      ),
      isNull,
    );
    expect(
      customerRouteFromQrValue(
        'https://ezq.example/scan?outletId=the-spice-house-indiranagar',
      ),
      isNull,
    );
  });
}
