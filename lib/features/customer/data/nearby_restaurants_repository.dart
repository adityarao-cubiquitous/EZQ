import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/branch.dart';

class NearbyRestaurant {
  const NearbyRestaurant({
    required this.branch,
    required this.distanceMeters,
    required this.waitingCount,
    required this.approximateWaitMinutes,
    required this.usesAssumedWait,
  });

  final Branch branch;
  final double distanceMeters;
  final int waitingCount;
  final int approximateWaitMinutes;
  final bool usesAssumedWait;

  double get distanceKm => distanceMeters / 1000;
}

abstract class NearbyRestaurantsRepository {
  Future<List<NearbyRestaurant>> findNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 2,
  });
}

class FirebaseNearbyRestaurantsRepository
    implements NearbyRestaurantsRepository {
  FirebaseNearbyRestaurantsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<NearbyRestaurant>> findNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 2,
  }) async {
    final snapshot = await _firestore
        .collection('restaurantBranches')
        .where('isActive', isEqualTo: true)
        .get();

    final nearby = <NearbyRestaurant>[];
    for (final doc in snapshot.docs) {
      final branch = Branch.fromMap(doc.id, doc.data());
      if (!branch.hasLocation) continue;
      final distanceMeters = Geolocator.distanceBetween(
        latitude,
        longitude,
        branch.latitude!,
        branch.longitude!,
      );
      if (distanceMeters <= radiusKm * 1000) {
        final queueLoad = await _queueLoadForBranch(doc.reference, branch);
        nearby.add(
          NearbyRestaurant(
            branch: branch,
            distanceMeters: distanceMeters,
            waitingCount: queueLoad.waitingCount,
            approximateWaitMinutes: queueLoad.approximateWaitMinutes,
            usesAssumedWait: queueLoad.usesAssumedWait,
          ),
        );
      }
    }

    nearby.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return nearby;
  }

  Future<({int waitingCount, int approximateWaitMinutes, bool usesAssumedWait})>
  _queueLoadForBranch(
    DocumentReference<Map<String, dynamic>> branchRef,
    Branch branch,
  ) async {
    final waitingSnapshot = await branchRef
        .collection('queueEntries')
        .where('status', isEqualTo: 'waiting')
        .get();
    final tablesSnapshot = await branchRef.collection('tables').get();
    final waitingCount = waitingSnapshot.docs.length;
    if (waitingCount == 0 && tablesSnapshot.docs.isEmpty) {
      final assumedWaiting = 1 + branch.id.length % 5;
      return (
        waitingCount: assumedWaiting,
        approximateWaitMinutes: 10 + assumedWaiting * 4,
        usesAssumedWait: true,
      );
    }

    final tableCount = tablesSnapshot.docs.isEmpty
        ? 6
        : tablesSnapshot.docs.length;
    final averageTurnover =
        branch.averageTurnoverMinutes ??
        branch.averageDiningMinutes + branch.averageCleaningMinutes;
    final approximateWait = waitingCount == 0
        ? 0
        : (waitingCount * averageTurnover / tableCount).ceil();
    return (
      waitingCount: waitingCount,
      approximateWaitMinutes: approximateWait,
      usesAssumedWait: false,
    );
  }
}

class MockNearbyRestaurantsRepository implements NearbyRestaurantsRepository {
  @override
  Future<List<NearbyRestaurant>> findNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 2,
  }) async {
    final branches = [
      const Branch(
        id: 'indiranagar',
        restaurantId: 'the-spice-house',
        restaurantName: 'The Spice House',
        name: 'Indiranagar',
        address: '100 Feet Road, Indiranagar, Bengaluru',
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        timezone: 'Asia/Kolkata',
        branchSlug: 'indiranagar',
        qrSlug: 'the-spice-house-indiranagar',
        queueUrl:
            'https://ezq-dev-cubiquitous.web.app/customer/the-spice-house/indiranagar',
        qrImageUrl:
            'https://storage.googleapis.com/ezq-dev-cubiquitous.firebasestorage.app/qr-codes/the-spice-house-indiranagar.png',
        isActive: true,
        averageDiningMinutes: 35,
        averageCleaningMinutes: 5,
        holdMinutes: 5,
        cuisine: 'Modern Indian',
        latitude: 12.9784,
        longitude: 77.6408,
      ),
      const Branch(
        id: 'indiranagar',
        restaurantId: 'cubbon-curry',
        restaurantName: 'Cubbon Curry',
        name: 'Indiranagar',
        address: 'CMH Road, Indiranagar, Bengaluru',
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        timezone: 'Asia/Kolkata',
        branchSlug: 'indiranagar',
        qrSlug: 'cubbon-curry-indiranagar',
        queueUrl:
            'https://ezq-dev-cubiquitous.web.app/customer/cubbon-curry/indiranagar',
        qrImageUrl:
            'https://storage.googleapis.com/ezq-dev-cubiquitous.firebasestorage.app/qr-codes/cubbon-curry-indiranagar.png',
        isActive: true,
        averageDiningMinutes: 32,
        averageCleaningMinutes: 5,
        holdMinutes: 5,
        cuisine: 'South Indian',
        latitude: 12.9790,
        longitude: 77.6418,
      ),
      const Branch(
        id: 'indiranagar',
        restaurantId: 'noodle-yard',
        restaurantName: 'Noodle Yard',
        name: 'Indiranagar',
        address: '12th Main Road, Indiranagar, Bengaluru',
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        timezone: 'Asia/Kolkata',
        branchSlug: 'indiranagar',
        qrSlug: 'noodle-yard-indiranagar',
        queueUrl:
            'https://ezq-dev-cubiquitous.web.app/customer/noodle-yard/indiranagar',
        qrImageUrl:
            'https://storage.googleapis.com/ezq-dev-cubiquitous.firebasestorage.app/qr-codes/noodle-yard-indiranagar.png',
        isActive: true,
        averageDiningMinutes: 30,
        averageCleaningMinutes: 5,
        holdMinutes: 5,
        cuisine: 'Asian',
        latitude: 12.9769,
        longitude: 77.6387,
      ),
      const Branch(
        id: 'indiranagar',
        restaurantId: 'taco-tawa',
        restaurantName: 'Taco Tawa',
        name: 'Indiranagar',
        address: '100 Feet Road, Indiranagar, Bengaluru',
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        timezone: 'Asia/Kolkata',
        branchSlug: 'indiranagar',
        qrSlug: 'taco-tawa-indiranagar',
        queueUrl:
            'https://ezq-dev-cubiquitous.web.app/customer/taco-tawa/indiranagar',
        qrImageUrl:
            'https://storage.googleapis.com/ezq-dev-cubiquitous.firebasestorage.app/qr-codes/taco-tawa-indiranagar.png',
        isActive: true,
        averageDiningMinutes: 28,
        averageCleaningMinutes: 5,
        holdMinutes: 5,
        cuisine: 'Mexican-Indian',
        latitude: 12.9758,
        longitude: 77.6432,
      ),
      const Branch(
        id: 'indiranagar',
        restaurantId: 'dosa-lab',
        restaurantName: 'Dosa Lab',
        name: 'Indiranagar',
        address: 'Double Road, Indiranagar, Bengaluru',
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        timezone: 'Asia/Kolkata',
        branchSlug: 'indiranagar',
        qrSlug: 'dosa-lab-indiranagar',
        queueUrl:
            'https://ezq-dev-cubiquitous.web.app/customer/dosa-lab/indiranagar',
        qrImageUrl:
            'https://storage.googleapis.com/ezq-dev-cubiquitous.firebasestorage.app/qr-codes/dosa-lab-indiranagar.png',
        isActive: true,
        averageDiningMinutes: 25,
        averageCleaningMinutes: 5,
        holdMinutes: 5,
        cuisine: 'Modern South Indian',
        latitude: 12.9821,
        longitude: 77.6395,
      ),
      const Branch(
        id: 'hal-2nd-stage',
        restaurantId: 'pasta-pepper',
        restaurantName: 'Pasta Pepper',
        name: 'HAL 2nd Stage',
        address: 'HAL 2nd Stage, Bengaluru',
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        timezone: 'Asia/Kolkata',
        branchSlug: 'hal-2nd-stage',
        qrSlug: 'pasta-pepper-hal-2nd-stage',
        queueUrl:
            'https://ezq-dev-cubiquitous.web.app/customer/pasta-pepper/hal-2nd-stage',
        qrImageUrl:
            'https://storage.googleapis.com/ezq-dev-cubiquitous.firebasestorage.app/qr-codes/pasta-pepper-hal-2nd-stage.png',
        isActive: true,
        averageDiningMinutes: 36,
        averageCleaningMinutes: 6,
        holdMinutes: 5,
        cuisine: 'Italian',
        latitude: 12.9812,
        longitude: 77.6470,
      ),
      const Branch(
        id: 'domlur-edge',
        restaurantId: 'biryani-bay',
        restaurantName: 'Biryani Bay',
        name: 'Domlur Edge',
        address: 'Domlur, Bengaluru',
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        timezone: 'Asia/Kolkata',
        branchSlug: 'domlur-edge',
        qrSlug: 'biryani-bay-domlur-edge',
        queueUrl:
            'https://ezq-dev-cubiquitous.web.app/customer/biryani-bay/domlur-edge',
        qrImageUrl:
            'https://storage.googleapis.com/ezq-dev-cubiquitous.firebasestorage.app/qr-codes/biryani-bay-domlur-edge.png',
        isActive: true,
        averageDiningMinutes: 34,
        averageCleaningMinutes: 5,
        holdMinutes: 5,
        cuisine: 'Hyderabadi',
        latitude: 12.9719,
        longitude: 77.6415,
      ),
      const Branch(
        id: 'indiranagar-metro',
        restaurantId: 'momo-mill',
        restaurantName: 'Momo Mill',
        name: 'Indiranagar Metro',
        address: 'Near Indiranagar Metro, Bengaluru',
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        timezone: 'Asia/Kolkata',
        branchSlug: 'indiranagar-metro',
        qrSlug: 'momo-mill-indiranagar-metro',
        queueUrl:
            'https://ezq-dev-cubiquitous.web.app/customer/momo-mill/indiranagar-metro',
        qrImageUrl:
            'https://storage.googleapis.com/ezq-dev-cubiquitous.firebasestorage.app/qr-codes/momo-mill-indiranagar-metro.png',
        isActive: true,
        averageDiningMinutes: 24,
        averageCleaningMinutes: 4,
        holdMinutes: 5,
        cuisine: 'Tibetan',
        latitude: 12.9788,
        longitude: 77.6364,
      ),
      const Branch(
        id: '12th-main',
        restaurantId: 'salad-studio',
        restaurantName: 'Salad Studio',
        name: '12th Main',
        address: '12th Main Road, Indiranagar, Bengaluru',
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        timezone: 'Asia/Kolkata',
        branchSlug: '12th-main',
        qrSlug: 'salad-studio-12th-main',
        queueUrl:
            'https://ezq-dev-cubiquitous.web.app/customer/salad-studio/12th-main',
        qrImageUrl:
            'https://storage.googleapis.com/ezq-dev-cubiquitous.firebasestorage.app/qr-codes/salad-studio-12th-main.png',
        isActive: true,
        averageDiningMinutes: 22,
        averageCleaningMinutes: 4,
        holdMinutes: 5,
        cuisine: 'Healthy Bowls',
        latitude: 12.9709,
        longitude: 77.6450,
      ),
      const Branch(
        id: 'old-airport-road',
        restaurantId: 'grill-garden',
        restaurantName: 'Grill Garden',
        name: 'Old Airport Road',
        address: 'Old Airport Road, Bengaluru',
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        timezone: 'Asia/Kolkata',
        branchSlug: 'old-airport-road',
        qrSlug: 'grill-garden-old-airport-road',
        queueUrl:
            'https://ezq-dev-cubiquitous.web.app/customer/grill-garden/old-airport-road',
        qrImageUrl:
            'https://storage.googleapis.com/ezq-dev-cubiquitous.firebasestorage.app/qr-codes/grill-garden-old-airport-road.png',
        isActive: true,
        averageDiningMinutes: 40,
        averageCleaningMinutes: 6,
        holdMinutes: 5,
        cuisine: 'Barbecue',
        latitude: 12.9649,
        longitude: 77.6407,
      ),
    ];
    const waitingCounts = [2, 3, 1, 4, 2, 5, 3, 2, 1, 4];
    const waitMinutes = [12, 16, 8, 20, 14, 24, 18, 10, 6, 22];
    return branches.indexed
        .map(
          (entry) => NearbyRestaurant(
            branch: entry.$2,
            distanceMeters: entry.$2.hasLocation
                ? Geolocator.distanceBetween(
                    latitude,
                    longitude,
                    entry.$2.latitude!,
                    entry.$2.longitude!,
                  )
                : 0,
            waitingCount: waitingCounts[entry.$1],
            approximateWaitMinutes: waitMinutes[entry.$1],
            usesAssumedWait: true,
          ),
        )
        .where((item) => item.distanceMeters <= radiusKm * 1000)
        .toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  }
}

final nearbyRestaurantsRepositoryProvider =
    Provider<NearbyRestaurantsRepository>((ref) {
      const useFirebase = bool.fromEnvironment('USE_FIREBASE');
      if (useFirebase || kIsWeb) {
        return FirebaseNearbyRestaurantsRepository();
      }
      return MockNearbyRestaurantsRepository();
    });
