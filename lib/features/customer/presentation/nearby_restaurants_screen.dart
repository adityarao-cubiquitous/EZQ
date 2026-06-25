import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/ezq_button.dart';
import '../data/nearby_restaurants_repository.dart';
import 'customer_shell.dart';

final nearbyRestaurantsControllerProvider =
    FutureProvider.autoDispose<NearbyRestaurantsResult>((ref) async {
      if (kDebugMode && !kIsWeb) {
        final restaurants = await MockNearbyRestaurantsRepository().findNearby(
          latitude: _debugIndiranagarLocation.latitude,
          longitude: _debugIndiranagarLocation.longitude,
          radiusKm: 2,
        );
        return NearbyRestaurantsResult(
          restaurants: restaurants,
          locationLabel: 'mock Indiranagar location',
          usedFallbackLocation: true,
        );
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationServiceDisabledException();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException(
          'Location permission is required to find restaurants near you.',
        );
      }

      final fix = await _currentLocationForNearby();
      final restaurants = await ref
          .read(nearbyRestaurantsRepositoryProvider)
          .findNearby(
            latitude: fix.latitude,
            longitude: fix.longitude,
            radiusKm: 2,
          );

      return NearbyRestaurantsResult(
        restaurants: restaurants,
        locationLabel: fix.locationLabel,
        usedFallbackLocation: fix.usedFallbackLocation,
      );
    });

class NearbyRestaurantsResult {
  const NearbyRestaurantsResult({
    required this.restaurants,
    required this.locationLabel,
    required this.usedFallbackLocation,
  });

  final List<NearbyRestaurant> restaurants;
  final String locationLabel;
  final bool usedFallbackLocation;
}

Future<
  ({
    double latitude,
    double longitude,
    String locationLabel,
    bool usedFallbackLocation,
  })
>
_currentLocationForNearby() async {
  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).timeout(const Duration(seconds: 6));
    return (
      latitude: position.latitude,
      longitude: position.longitude,
      locationLabel: 'your current location',
      usedFallbackLocation: false,
    );
  } on TimeoutException {
    if (kDebugMode && !kIsWeb) {
      return (
        latitude: _debugIndiranagarLocation.latitude,
        longitude: _debugIndiranagarLocation.longitude,
        locationLabel: 'Indiranagar demo location',
        usedFallbackLocation: true,
      );
    }
    rethrow;
  }
}

const _debugIndiranagarLocation = (latitude: 12.9784, longitude: 77.6408);

class NearbyRestaurantsScreen extends ConsumerWidget {
  const NearbyRestaurantsScreen({super.key, this.appBackRoute = '/app/home'});

  final String? appBackRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyState = ref.watch(nearbyRestaurantsControllerProvider);

    return CustomerShell(
      restaurantId: AppConstants.demoRestaurantId,
      branchId: AppConstants.demoBranchId,
      showBottomNav: false,
      appBackRoute: appBackRoute,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nearby restaurants',
              style: TextStyle(
                color: AppColors.navyText,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Signed-up EZQ restaurants within 2 km of your location.',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            nearbyState.when(
              loading: () => const _LoadingNearbyCard(),
              error: (error, _) => _NearbyErrorCard(error: error),
              data: (result) {
                final restaurants = result.restaurants;
                if (restaurants.isEmpty) {
                  return _EmptyNearbyCard(locationLabel: result.locationLabel);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NearbySummary(
                      count: restaurants.length,
                      locationLabel: result.locationLabel,
                      usedFallbackLocation: result.usedFallbackLocation,
                      onRefresh: () =>
                          ref.invalidate(nearbyRestaurantsControllerProvider),
                    ),
                    const SizedBox(height: 12),
                    for (final restaurant in restaurants) ...[
                      _NearbyRestaurantCard(restaurant: restaurant),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyRestaurantCard extends StatelessWidget {
  const _NearbyRestaurantCard({required this.restaurant});

  final NearbyRestaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final branch = restaurant.branch;
    final restaurantName = branch.restaurantName ?? branch.name;
    final restaurantId = branch.restaurantId ?? AppConstants.demoRestaurantId;
    final distanceLabel = restaurant.distanceKm < 1
        ? '${restaurant.distanceMeters.round()} m'
        : '${restaurant.distanceKm.toStringAsFixed(1)} km';
    final waitLabel = restaurant.approximateWaitMinutes == 0
        ? 'No wait'
        : '~${restaurant.approximateWaitMinutes} min wait';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1ABDC8D0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1012A9DC),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9FBFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x5534D5ED)),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: AppColors.deepTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurantName,
                      style: const TextStyle(
                        color: AppColors.navyText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (branch.cuisine != null) branch.cuisine,
                        branch.name,
                      ].whereType<String>().join(' - '),
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _DistancePill(label: distanceLabel),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(
                icon: Icons.schedule_rounded,
                label: waitLabel,
                emphasized: true,
              ),
              _MetaPill(
                icon: Icons.groups_rounded,
                label: '${restaurant.waitingCount} waiting',
              ),
              if (restaurant.usesAssumedWait)
                const _MetaPill(
                  icon: Icons.auto_graph_rounded,
                  label: 'Assumed',
                ),
              const _MetaPill(
                icon: Icons.verified_rounded,
                label: 'EZQ signed up',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            branch.address,
            style: const TextStyle(
              color: Color(0xFF44515B),
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          EzqButton(
            label: 'Join Queue',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => context.go('/customer/$restaurantId/${branch.id}'),
          ),
        ],
      ),
    );
  }
}

class _NearbySummary extends StatelessWidget {
  const _NearbySummary({
    required this.count,
    required this.locationLabel,
    required this.usedFallbackLocation,
    required this.onRefresh,
  });

  final int count;
  final String locationLabel;
  final bool usedFallbackLocation;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: usedFallbackLocation
            ? const Color(0xFFFFF8E8)
            : const Color(0xFFEFFAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: usedFallbackLocation
              ? const Color(0x55F59E0B)
              : const Color(0x553DD6C6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            usedFallbackLocation
                ? Icons.location_searching_rounded
                : Icons.near_me_rounded,
            color: usedFallbackLocation
                ? AppColors.warningOrange
                : AppColors.deepTeal,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count ${count == 1 ? 'restaurant' : 'restaurants'} near $locationLabel',
              style: const TextStyle(
                color: AppColors.navyText,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh nearby restaurants',
            color: AppColors.deepTeal,
          ),
        ],
      ),
    );
  }
}

class _DistancePill extends StatelessWidget {
  const _DistancePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFAF8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x553DD6C6)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.deepTeal,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1ABDC8D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: emphasized ? AppColors.warningOrange : AppColors.deepTeal,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingNearbyCard extends StatelessWidget {
  const _LoadingNearbyCard();

  @override
  Widget build(BuildContext context) {
    return const _StateCard(
      icon: Icons.my_location_rounded,
      title: 'Finding restaurants',
      message: 'Checking your location and loading signed-up restaurants.',
      child: Padding(
        padding: EdgeInsets.only(top: 18),
        child: LinearProgressIndicator(minHeight: 5),
      ),
    );
  }
}

class _EmptyNearbyCard extends StatelessWidget {
  const _EmptyNearbyCard({required this.locationLabel});

  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      icon: Icons.location_off_rounded,
      title: 'No restaurants nearby',
      message:
          'There are no active EZQ restaurant branches within 2 km of $locationLabel yet.',
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: EzqButton(
          label: 'Join demo queue',
          icon: Icons.arrow_forward_rounded,
          onPressed: () => context.go(
            '/customer/${AppConstants.demoRestaurantId}/${AppConstants.demoBranchId}',
          ),
        ),
      ),
    );
  }
}

class _NearbyErrorCard extends ConsumerWidget {
  const _NearbyErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (
      :title,
      :message,
      :primaryLabel,
      :primaryIcon,
      :primaryAction,
    ) = switch (error) {
      LocationServiceDisabledException() => (
        title: 'Location is off',
        message:
            'Turn on location services to see signed-up restaurants within 2 km.',
        primaryLabel: 'Open Location Settings',
        primaryIcon: Icons.settings_rounded,
        primaryAction: Geolocator.openLocationSettings,
      ),
      PermissionDeniedException() => (
        title: 'Location permission needed',
        message:
            'Allow location access to find restaurants near you. You can change this in app settings.',
        primaryLabel: 'Open App Settings',
        primaryIcon: Icons.app_settings_alt_rounded,
        primaryAction: Geolocator.openAppSettings,
      ),
      TimeoutException() => (
        title: 'Location took too long',
        message:
            'We could not get your current location. Check simulator/device location and try again.',
        primaryLabel: 'Try Again',
        primaryIcon: Icons.refresh_rounded,
        primaryAction: () async => true,
      ),
      _ => (
        title: 'Could not load nearby restaurants',
        message:
            'Something went wrong while loading signed-up restaurants near you.',
        primaryLabel: 'Try Again',
        primaryIcon: Icons.refresh_rounded,
        primaryAction: () async => true,
      ),
    };

    return _StateCard(
      icon: Icons.near_me_disabled_rounded,
      title: title,
      message: message,
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          children: [
            EzqButton(
              label: primaryLabel,
              icon: primaryIcon,
              onPressed: () async {
                await primaryAction();
                ref.invalidate(nearbyRestaurantsControllerProvider);
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () =>
                    ref.invalidate(nearbyRestaurantsControllerProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.child,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1ABDC8D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.deepTeal, size: 28),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navyText,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}
