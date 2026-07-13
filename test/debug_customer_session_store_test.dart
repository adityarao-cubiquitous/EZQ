import 'package:ezq/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('temporary OTP session can be restored and cleared', () async {
    final store = DebugCustomerSessionStore(persistToDevice: false);

    expect(await store.loadPhone(), isNull);

    await store.savePhone('9880478370');
    expect(await store.loadPhone(), '+919880478370');

    await store.clearPhone();
    expect(await store.loadPhone(), isNull);
  });
}
