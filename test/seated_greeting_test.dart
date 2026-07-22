import 'package:ezq/features/customer/presentation/seated_greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('personalizes the seated greeting with the party name', () {
    expect(seatedGreeting('Aarav'), 'Aarav, enjoy your meal!');
  });

  test('falls back cleanly when the party name is empty', () {
    expect(seatedGreeting('  '), 'Enjoy your meal!');
  });
}
