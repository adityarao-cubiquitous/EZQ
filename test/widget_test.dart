import 'package:ezq/app/ezq_app.dart';
import 'package:ezq/features/customer/data/nearby_restaurants_repository.dart';
import 'package:ezq/features/customer/domain/branch.dart';
import 'package:ezq/features/customer/presentation/customer_join_queue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
              restaurantId: 'salad-studio',
              branchSlug: '12th-main',
              restaurantName: 'Salad Studio',
              branchName: '12th Main',
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
          '/customer/${restaurant.routeRestaurantBranchId}',
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
            .where((restaurant) => restaurant.branch.id == 'indiranagar')
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

    expect(restaurant.routeRestaurantId, 'biryani-bay-domlur-edge');
    expect(restaurant.routeBranchId, 'biryani-bay-domlur-edge');
    expect(restaurant.routeRestaurantBranchId, 'biryani-bay-domlur-edge');
  });

  test('nearby branch uses explicit restaurant and branch slugs', () {
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

    expect(restaurant.routeRestaurantId, 'biryani-bay');
    expect(restaurant.routeBranchId, 'domlur-edge');
    expect(restaurant.routeRestaurantBranchId, 'biryani-bay-domlur-edge');
  });
}
