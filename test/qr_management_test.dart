import 'package:ezq/core/utils/qr_generation.dart';
import 'package:ezq/features/admin/data/qr_management_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonicalCustomerQueueUrl', () {
    test('uses the active canonical RestaurantBranch ID', () {
      expect(
        canonicalCustomerQueueUrl(
          restaurantId: 'the-spice-house-indiranagar',
          branchId: 'the-spice-house-indiranagar',
        ),
        'https://ezq-dev-cubiquitous.web.app/customer/'
        'the-spice-house-indiranagar',
      );
    });

    test(
      'combines distinct restaurant and branch IDs through customerRoute',
      () {
        expect(
          canonicalCustomerQueueUrl(
            restaurantId: 'biryani-bay',
            branchId: 'domlur-edge',
          ),
          'https://ezq-dev-cubiquitous.web.app/customer/biryani-bay-domlur-edge',
        );
      },
    );
  });

  test('generated SVG changes with the canonical customer URL', () {
    final first = generateQrSvg(
      canonicalCustomerQueueUrl(
        restaurantId: 'the-spice-house-indiranagar',
        branchId: 'the-spice-house-indiranagar',
      ),
    );
    final second = generateQrSvg(
      canonicalCustomerQueueUrl(
        restaurantId: 'biryani-bay',
        branchId: 'domlur-edge',
      ),
    );

    expect(first, startsWith('<svg'));
    expect(second, startsWith('<svg'));
    expect(first, isNot(second));
  });
}
