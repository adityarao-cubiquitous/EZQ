import 'package:ezq/features/customer/domain/menu_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('menu URI resolver supports hosted and relative URLs', () {
    expect(
      resolveCustomerMenuUri('https://cdn.example.com/menu.pdf').toString(),
      'https://cdn.example.com/menu.pdf',
    );
    expect(
      resolveCustomerMenuUri('/menus/current.pdf').toString(),
      'https://ezq-dev-cubiquitous.web.app/menus/current.pdf',
    );
    expect(
      resolveCustomerMenuUri('menus/current.pdf').toString(),
      'https://ezq-dev-cubiquitous.web.app/menus/current.pdf',
    );
  });

  test('menu URI resolver rejects empty values', () {
    expect(resolveCustomerMenuUri(null), isNull);
    expect(resolveCustomerMenuUri('   '), isNull);
  });
}
