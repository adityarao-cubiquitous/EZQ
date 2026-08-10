import 'package:ezq/app/ezq_app.dart';
import 'package:ezq/features/auth/data/auth_repository.dart';
import 'package:ezq/features/auth/presentation/customer_name_profile_screen.dart';
import 'package:ezq/features/customer/data/nearby_restaurants_repository.dart';
import 'package:ezq/features/customer/data/customer_queue_repository.dart';
import 'package:ezq/features/customer/domain/branch.dart';
import 'package:ezq/features/customer/domain/restaurant_branch_identity.dart';
import 'package:ezq/features/customer/presentation/customer_join_queue_screen.dart';
import 'package:ezq/features/customer/presentation/customer_landing_screen.dart';
import 'package:ezq/features/queue/domain/queue_entry.dart';
import 'package:ezq/features/queue/domain/queue_status.dart';
import 'package:ezq/features/recommendation/domain/customer_preferences.dart';
import 'package:ezq/features/recommendation/domain/recommendation_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('EZQ root renders landing screen', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: EzqApp()));
    await pumpFrames(tester);

    expect(find.text('Smart Queue Platform'), findsOneWidget);
    expect(find.text('Powered by'), findsOneWidget);
    expect(find.text('Scan QR code'), findsOneWidget);
    expect(find.text('The Spice House'), findsNothing);
  });

  testWidgets('persisted customer session restores authenticated home', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const CustomerLandingScreen(),
        ),
        GoRoute(
          path: '/app/home',
          builder: (context, state) => const Text('restored-customer-home'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          debugCustomerPhoneSessionProvider.overrideWithValue(
            ValueNotifier<String?>('+919999988888'),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('restored-customer-home'), findsOneWidget);
  });

  testWidgets(
    'customer join header uses resolved restaurant and branch names',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CustomerJoinQueueScreen(
              restaurantBranchId: 'salad-studio-12th-main',
              identity: RestaurantBranchIdentity(
                restaurantBranchId: 'salad-studio-12th-main',
                restaurantName: 'Salad Studio',
                branchName: '12th Main',
                address: '12th Main Road, Indiranagar, Bengaluru',
              ),
            ),
          ),
        ),
      );
      await pumpFrames(tester);

      expect(find.text('Salad Studio'), findsOneWidget);
      expect(find.text('12th Main Branch'), findsOneWidget);
      expect(find.text('The Spice House'), findsNothing);
    },
  );

  testWidgets(
    'new guest phone starts empty, validates, and accepts submission',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const CustomerJoinQueueScreen(
              restaurantBranchId: 'salad-studio-12th-main',
              identity: RestaurantBranchIdentity(
                restaurantBranchId: 'salad-studio-12th-main',
                restaurantName: 'Salad Studio',
                branchName: '12th Main',
                address: '12th Main Road, Indiranagar, Bengaluru',
              ),
            ),
          ),
          GoRoute(
            path: '/customer/:restaurantBranchId/status/:queueEntryId',
            builder: (context, state) => const Text('queue-submitted'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerQueueRepositoryProvider.overrideWithValue(
              MockCustomerQueueRepository(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await pumpFrames(tester);

      final fields = find.byType(TextFormField);
      final phoneField = tester.widget<TextFormField>(fields.at(1));
      expect(phoneField.controller?.text, isEmpty);
      expect(phoneField.controller?.text, isNot('98765 43210'));

      await tester.enterText(fields.at(0), 'Fresh Guest');
      await tester.enterText(fields.at(1), '12345');
      await tester.tap(find.text('Join Queue'));
      await tester.pump();
      expect(find.text('Enter a 10 digit mobile number'), findsOneWidget);
      expect(find.text('queue-submitted'), findsNothing);

      await tester.enterText(fields.at(1), '9123456789');
      await tester.tap(find.text('Join Queue'));
      await tester.pumpAndSettle();
      expect(find.text('queue-submitted'), findsOneWidget);
    },
  );

  testWidgets('join again prefills editable details without auto-submitting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previousEntry = QueueEntry(
      id: 'previous-entry',
      tokenNumber: 12,
      tokenCode: 'Q12',
      businessDate: '2026-08-06',
      customerName: 'Rejoin Customer',
      phone: '+919999988888',
      partySize: 6,
      partySizeBand: '5-6',
      notes: 'Window seat',
      status: QueueStatus.completed,
      estimatedWaitMinutes: 20,
      queuePosition: 4,
      extensionUsed: false,
      joinedAt: DateTime(2026, 8, 6, 12),
      customerPreferences: const CustomerPreferences(
        seatingPreference: SeatingPreference.emptyTableOnly,
        acceptedLongerWait: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CustomerJoinQueueScreen(
            restaurantBranchId: 'salad-studio-12th-main',
            identity: const RestaurantBranchIdentity(
              restaurantBranchId: 'salad-studio-12th-main',
              restaurantName: 'Salad Studio',
              branchName: '12th Main',
              address: '12th Main Road, Indiranagar, Bengaluru',
            ),
            initialEntry: previousEntry,
          ),
        ),
      ),
    );
    await pumpFrames(tester);

    expect(find.text('Rejoin Customer'), findsOneWidget);
    final phoneField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );
    expect(phoneField.controller?.text, '9999988888');
    expect(find.text('Window seat'), findsOneWidget);
    expect(find.text('6 people'), findsOneWidget);
    expect(find.text('Empty selected'), findsOneWidget);
    expect(find.text('Join Queue'), findsOneWidget);
    expect(find.textContaining('Q13'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile account profile opens in edit mode', (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          debugCustomerPhoneSessionProvider.overrideWithValue(
            ValueNotifier<String?>('+919880478370'),
          ),
        ],
        child: const MaterialApp(
          home: CustomerNameProfileScreen(editing: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Tell us your name'), findsNothing);
  });

  test(
    'nearby fixture routes all restaurants by canonical branch id',
    () async {
      final restaurants = await MockNearbyRestaurantsRepository().findNearby(
        latitude: 12.9784,
        longitude: 77.6408,
        radiusKm: 10,
      );

      final routes = {
        for (final restaurant in restaurants)
          '/customer/${restaurant.restaurantBranchId}',
      };

      expect(restaurants, hasLength(10));
      expect(
        routes,
        containsAll({
          '/customer/the-spice-house-indiranagar',
          '/customer/cubbon-curry-indiranagar',
          '/customer/noodle-yard-indiranagar',
          '/customer/taco-tawa-indiranagar',
          '/customer/dosa-lab-indiranagar',
          '/customer/pasta-pepper-hal-2nd-stage',
          '/customer/biryani-bay-domlur-edge',
          '/customer/momo-mill-indiranagar-metro',
          '/customer/salad-studio-12th-main',
          '/customer/grill-garden-old-airport-road',
        }),
      );
      expect(
        restaurants
            .where(
              (restaurant) =>
                  restaurant.restaurantBranchId.endsWith('-indiranagar'),
            )
            .map((restaurant) => restaurant.branch.restaurantId)
            .toSet(),
        containsAll({
          'the-spice-house',
          'cubbon-curry',
          'noodle-yard',
          'taco-tawa',
          'dosa-lab',
        }),
      );
    },
  );

  test('nearby merged branch without slugs routes by document identity', () {
    final restaurant = NearbyRestaurant(
      branch: Branch.fromMap('biryani-bay-domlur-edge', {
        'restaurantName': 'Biryani Bay',
        'branchName': 'Domlur Edge',
        'isActive': true,
      }),
      distanceMeters: 1900,
      waitingCount: 4,
      approximateWaitMinutes: 26,
      usesAssumedWait: false,
    );

    expect(restaurant.restaurantBranchId, 'biryani-bay-domlur-edge');
  });

  test('nearby routing ignores legacy restaurant and branch slugs', () {
    final restaurant = NearbyRestaurant(
      branch: Branch.fromMap('biryani-bay-domlur-edge', {
        'restaurantId': 'biryani-bay',
        'branchSlug': 'domlur-edge',
        'restaurantName': 'Biryani Bay',
        'branchName': 'Domlur Edge',
        'isActive': true,
      }),
      distanceMeters: 1900,
      waitingCount: 4,
      approximateWaitMinutes: 26,
      usesAssumedWait: false,
    );

    expect(restaurant.restaurantBranchId, 'biryani-bay-domlur-edge');
  });
}
