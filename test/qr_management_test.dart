import 'package:ezq/core/utils/qr_generation.dart';
import 'package:ezq/features/admin/data/qr_management_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonicalCustomerQueueUrl', () {
    test('uses the active canonical RestaurantBranch ID', () {
      expect(
        canonicalCustomerQueueUrl(
          restaurantBranchId: 'the-spice-house-indiranagar',
        ),
        'https://ezq-dev-cubiquitous.web.app/customer/'
        'the-spice-house-indiranagar',
      );
    });

    test('uses another canonical RestaurantBranch ID unchanged', () {
      expect(
        canonicalCustomerQueueUrl(
          restaurantBranchId: 'biryani-bay-domlur-edge',
        ),
        'https://ezq-dev-cubiquitous.web.app/customer/biryani-bay-domlur-edge',
      );
    });
  });

  test('generated SVG changes with the canonical customer URL', () {
    final first = generateQrSvg(
      canonicalCustomerQueueUrl(
        restaurantBranchId: 'the-spice-house-indiranagar',
      ),
    );
    final second = generateQrSvg(
      canonicalCustomerQueueUrl(restaurantBranchId: 'biryani-bay-domlur-edge'),
    );

    expect(first, startsWith('<svg'));
    expect(second, startsWith('<svg'));
    expect(first, isNot(second));
  });
}
