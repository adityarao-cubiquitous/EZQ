import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/restaurant_logo.dart';
import '../domain/restaurant_branch_identity.dart';

enum CustomerRestaurantIdentityLayout { centered, compact }

const customerIdentityLogoSize = 64.0;
const customerIdentityCompactLogoSize = 44.0;

class CustomerRestaurantIdentityView extends StatelessWidget {
  const CustomerRestaurantIdentityView({
    super.key,
    required this.identity,
    this.layout = CustomerRestaurantIdentityLayout.centered,
    this.showAddress = true,
  });

  final RestaurantBranchIdentity identity;
  final CustomerRestaurantIdentityLayout layout;
  final bool showAddress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: [
        identity.restaurantName,
        identity.branchLabel,
        if (showAddress) identity.addressLabel,
      ].join(', '),
      child: layout == CustomerRestaurantIdentityLayout.compact
          ? _CompactRestaurantIdentity(
              identity: identity,
              showAddress: showAddress,
            )
          : _CenteredRestaurantIdentity(
              identity: identity,
              showAddress: showAddress,
            ),
    );
  }
}

class _CenteredRestaurantIdentity extends StatelessWidget {
  const _CenteredRestaurantIdentity({
    required this.identity,
    required this.showAddress,
  });

  final RestaurantBranchIdentity identity;
  final bool showAddress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RestaurantLogo(
          restaurantBranchId: identity.restaurantBranchId,
          restaurantName: identity.restaurantName,
          logoUrl: identity.logoUrl,
          size: customerIdentityLogoSize,
        ),
        const SizedBox(height: 12),
        Text(
          identity.restaurantName,
          key: const ValueKey('customer-identity-restaurant-name'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.navyText,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          identity.branchLabel,
          key: const ValueKey('customer-identity-branch-name'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.deepTeal,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (showAddress) ...[
          const SizedBox(height: 7),
          _AddressLine(identity: identity, centered: true),
        ],
      ],
    );
  }
}

class _CompactRestaurantIdentity extends StatelessWidget {
  const _CompactRestaurantIdentity({
    required this.identity,
    required this.showAddress,
  });

  final RestaurantBranchIdentity identity;
  final bool showAddress;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RestaurantLogo(
          restaurantBranchId: identity.restaurantBranchId,
          restaurantName: identity.restaurantName,
          logoUrl: identity.logoUrl,
          size: customerIdentityCompactLogoSize,
          showShadow: false,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                identity.restaurantName,
                key: const ValueKey('customer-identity-restaurant-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navyText,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                identity.branchLabel,
                key: const ValueKey('customer-identity-branch-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showAddress) ...[
                const SizedBox(height: 4),
                _AddressLine(identity: identity),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({required this.identity, this.centered = false});

  final RestaurantBranchIdentity identity;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.location_on_outlined,
            size: 14,
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            identity.addressLabel,
            key: const ValueKey('customer-identity-address'),
            maxLines: centered ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
