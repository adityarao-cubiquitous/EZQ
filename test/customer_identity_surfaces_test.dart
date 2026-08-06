import 'package:ezq/features/customer/data/branch_identity_repository.dart';
import 'package:ezq/features/customer/data/menu_repository.dart';
import 'package:ezq/features/customer/domain/branch.dart';
import 'package:ezq/features/customer/domain/menu_document.dart';
import 'package:ezq/features/customer/presentation/customer_menu_screen.dart';
import 'package:ezq/features/customer/presentation/customer_support_screen.dart';
import 'package:ezq/features/customer/presentation/seated_view.dart';
import 'package:ezq/features/customer/presentation/table_ready_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const restaurantBranchId = 'noodle-yard-indiranagar';
  final branchLink = CustomerBranchLink.fromBranch(
    Branch.fromMap(restaurantBranchId, {
      'restaurantName': 'Noodle Yard',
      'branchName': 'Indiranagar',
      'address': '12th Main Road, Indiranagar, Bengaluru',
      'isActive': true,
    }),
  );

  Future<void> pumpSurface(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          branchIdentityRepositoryProvider.overrideWithValue(
            _FixedBranchIdentityRepository(branchLink),
          ),
          menuRepositoryProvider.overrideWithValue(
            const _UnavailableMenuRepository(),
          ),
        ],
        child: MaterialApp(home: child),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  void expectIdentity() {
    expect(find.text('Noodle Yard'), findsWidgets);
    expect(find.text('Indiranagar Branch'), findsOneWidget);
    expect(find.text('12th Main Road, Indiranagar, Bengaluru'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('restaurant-logo-asset-noodle-yard-indiranagar'),
      ),
      findsWidgets,
    );
  }

  testWidgets('menu uses the shared restaurant identity', (tester) async {
    await pumpSurface(
      tester,
      const CustomerMenuScreen(restaurantBranchId: restaurantBranchId),
    );

    expectIdentity();
    expect(find.text('Menu PDF pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('support uses the shared restaurant identity', (tester) async {
    await pumpSurface(
      tester,
      const CustomerSupportScreen(restaurantBranchId: restaurantBranchId),
    );

    expectIdentity();
    expect(find.text('Support'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('table-ready view uses the shared restaurant identity', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      const TableReadyView(
        restaurantBranchId: restaurantBranchId,
        queueEntryId: 'queue-entry',
      ),
    );

    expectIdentity();
    expect(find.text('Your table is ready!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seated view uses the shared restaurant identity', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      const SeatedView(
        restaurantBranchId: restaurantBranchId,
        queueEntryId: 'queue-entry',
      ),
    );

    expectIdentity();
    expect(find.text('Enjoy your meal!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FixedBranchIdentityRepository implements BranchIdentityRepository {
  const _FixedBranchIdentityRepository(this.branchLink);

  final CustomerBranchLink branchLink;

  @override
  Future<CustomerBranchLink> resolveCustomerBranch({
    required String restaurantBranchId,
  }) async {
    return branchLink;
  }
}

class _UnavailableMenuRepository implements MenuRepository {
  const _UnavailableMenuRepository();

  @override
  Stream<MenuDocument> watchMenu({required String restaurantBranchId}) {
    return Stream.value(
      const MenuDocument(
        restaurantName: 'Ignored legacy name',
        branchName: 'Ignored legacy branch',
        pdfUrl: null,
        previewImageUrl: null,
      ),
    );
  }
}
