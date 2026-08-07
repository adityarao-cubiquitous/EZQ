import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/ezq_button.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/branch_identity_repository.dart';
import 'customer_restaurant_identity.dart';
import 'customer_shell.dart';

const customerJoinRadiusMeters = 2000.0;

bool isWithinCustomerJoinRadius({
  required double distanceMeters,
  double radiusMeters = customerJoinRadiusMeters,
}) {
  return distanceMeters <= radiusMeters;
}

String customerJoinDistanceLabel(double distanceMeters) {
  if (distanceMeters < 1000) return '${distanceMeters.round()} m';
  return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
}

final customerJoinVicinityVerifierProvider =
    Provider<CustomerJoinVicinityVerifier>((ref) {
      return const GeolocatorCustomerJoinVicinityVerifier();
    });

enum CustomerJoinVicinityFailureType {
  branchLocationMissing,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  locationUnavailable,
  outsideRadius,
}

class CustomerJoinVicinityResult {
  const CustomerJoinVicinityResult.allowed({this.distanceMeters})
    : failureType = null;

  const CustomerJoinVicinityResult.blocked({
    required this.failureType,
    this.distanceMeters,
  });

  final CustomerJoinVicinityFailureType? failureType;
  final double? distanceMeters;

  bool get isAllowed => failureType == null;
}

abstract class CustomerJoinVicinityVerifier {
  Future<CustomerJoinVicinityResult> verify(CustomerBranchLink branchLink);
}

class GeolocatorCustomerJoinVicinityVerifier
    implements CustomerJoinVicinityVerifier {
  const GeolocatorCustomerJoinVicinityVerifier();

  @override
  Future<CustomerJoinVicinityResult> verify(
    CustomerBranchLink branchLink,
  ) async {
    if (kIsWeb) {
      return const CustomerJoinVicinityResult.allowed();
    }

    final branch = branchLink.branch;
    if (!branch.hasLocation) {
      return const CustomerJoinVicinityResult.blocked(
        failureType: CustomerJoinVicinityFailureType.branchLocationMissing,
      );
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const CustomerJoinVicinityResult.blocked(
          failureType: CustomerJoinVicinityFailureType.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const CustomerJoinVicinityResult.blocked(
          failureType: CustomerJoinVicinityFailureType.permissionDenied,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const CustomerJoinVicinityResult.blocked(
          failureType: CustomerJoinVicinityFailureType.permissionDeniedForever,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).timeout(const Duration(seconds: 8));
      final distanceMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        branch.latitude!,
        branch.longitude!,
      );
      if (!isWithinCustomerJoinRadius(distanceMeters: distanceMeters)) {
        return CustomerJoinVicinityResult.blocked(
          failureType: CustomerJoinVicinityFailureType.outsideRadius,
          distanceMeters: distanceMeters,
        );
      }
      return CustomerJoinVicinityResult.allowed(distanceMeters: distanceMeters);
    } on TimeoutException {
      return const CustomerJoinVicinityResult.blocked(
        failureType: CustomerJoinVicinityFailureType.locationUnavailable,
      );
    } catch (_) {
      return const CustomerJoinVicinityResult.blocked(
        failureType: CustomerJoinVicinityFailureType.locationUnavailable,
      );
    }
  }
}

class CustomerJoinLocationGate extends ConsumerStatefulWidget {
  const CustomerJoinLocationGate({
    super.key,
    required this.branchLink,
    required this.child,
  });

  final CustomerBranchLink branchLink;
  final Widget child;

  @override
  ConsumerState<CustomerJoinLocationGate> createState() =>
      _CustomerJoinLocationGateState();
}

class _CustomerJoinLocationGateState
    extends ConsumerState<CustomerJoinLocationGate> {
  late Future<CustomerJoinVicinityResult> _check;

  @override
  void initState() {
    super.initState();
    _check = _verify();
  }

  @override
  void didUpdateWidget(CustomerJoinLocationGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchLink.restaurantBranchId !=
        widget.branchLink.restaurantBranchId) {
      _check = _verify();
    }
  }

  Future<CustomerJoinVicinityResult> _verify() {
    return ref
        .read(customerJoinVicinityVerifierProvider)
        .verify(widget.branchLink);
  }

  void _retry() {
    setState(() {
      _check = _verify();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return widget.child;

    return FutureBuilder<CustomerJoinVicinityResult>(
      future: _check,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }

        final result = snapshot.data;
        if (result?.isAllowed == true) return widget.child;

        return _JoinLocationBlockedScreen(
          branchLink: widget.branchLink,
          result:
              result ??
              const CustomerJoinVicinityResult.blocked(
                failureType:
                    CustomerJoinVicinityFailureType.locationUnavailable,
              ),
          onRetry: _retry,
        );
      },
    );
  }
}

class _JoinLocationBlockedScreen extends StatelessWidget {
  const _JoinLocationBlockedScreen({
    required this.branchLink,
    required this.result,
    required this.onRetry,
  });

  final CustomerBranchLink branchLink;
  final CustomerJoinVicinityResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = _JoinLocationBlockedCopy.from(result);
    final canOpenSettings =
        result.failureType ==
        CustomerJoinVicinityFailureType.permissionDeniedForever;
    final canOpenLocationSettings =
        result.failureType == CustomerJoinVicinityFailureType.serviceDisabled;

    return CustomerShell(
      restaurantBranchId: branchLink.restaurantBranchId,
      activeTab: CustomerTab.join,
      showBottomNav: false,
      appBackRoute: '/app/nearby',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 64, 20, 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x1ABDC8D0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1712A9DC),
                blurRadius: 26,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              CustomerRestaurantIdentityView(
                identity: branchLink.identity,
                layout: CustomerRestaurantIdentityLayout.compact,
              ),
              const SizedBox(height: 18),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.softSurface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(copy.icon, color: AppColors.deepTeal, size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                copy.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.navyText,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                copy.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              EzqButton(
                label: 'Check location again',
                icon: Icons.my_location_rounded,
                onPressed: onRetry,
              ),
              if (canOpenSettings || canOpenLocationSettings) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (canOpenLocationSettings) {
                        Geolocator.openLocationSettings();
                      } else {
                        Geolocator.openAppSettings();
                      }
                    },
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: Text(
                      canOpenLocationSettings
                          ? 'Open Location Settings'
                          : 'Open App Settings',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepTeal,
                      side: const BorderSide(color: Color(0x5534D5ED)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinLocationBlockedCopy {
  const _JoinLocationBlockedCopy({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  factory _JoinLocationBlockedCopy.from(CustomerJoinVicinityResult result) {
    return switch (result.failureType) {
      CustomerJoinVicinityFailureType.branchLocationMissing =>
        const _JoinLocationBlockedCopy(
          title: 'Location check unavailable',
          message:
              'This restaurant has not added its map location yet. Please ask the host to help you join the queue.',
          icon: Icons.location_off_rounded,
        ),
      CustomerJoinVicinityFailureType.serviceDisabled =>
        const _JoinLocationBlockedCopy(
          title: 'Turn on location',
          message:
              'We need your current location to confirm you are near the restaurant before joining the queue.',
          icon: Icons.location_disabled_rounded,
        ),
      CustomerJoinVicinityFailureType.permissionDenied =>
        const _JoinLocationBlockedCopy(
          title: 'Allow location access',
          message:
              'Please allow location access so EZQ can confirm you are within 2 km of this restaurant.',
          icon: Icons.location_on_outlined,
        ),
      CustomerJoinVicinityFailureType.permissionDeniedForever =>
        const _JoinLocationBlockedCopy(
          title: 'Location permission is off',
          message:
              'Location access is disabled for EZQ. Turn it on in app settings, then come back and check again.',
          icon: Icons.settings_rounded,
        ),
      CustomerJoinVicinityFailureType.outsideRadius => _JoinLocationBlockedCopy(
        title: 'You are too far away',
        message:
            'You need to be within 2 km of this restaurant to join its queue. You are about ${customerJoinDistanceLabel(result.distanceMeters ?? 0)} away.',
        icon: Icons.near_me_disabled_rounded,
      ),
      CustomerJoinVicinityFailureType.locationUnavailable ||
      null => const _JoinLocationBlockedCopy(
        title: 'Could not check location',
        message:
            'We could not get your current location right now. Please check your signal and try again.',
        icon: Icons.my_location_rounded,
      ),
    };
  }
}
