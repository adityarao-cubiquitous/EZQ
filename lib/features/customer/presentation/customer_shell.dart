import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../auth/data/auth_repository.dart';

enum CustomerTab { join, status, menu, support }

class CustomerShell extends StatelessWidget {
  const CustomerShell({
    super.key,
    required this.child,
    required this.restaurantId,
    required this.branchId,
    this.activeTab = CustomerTab.join,
    this.queueEntryId,
    this.showBottomNav = true,
    this.footer,
    this.appBackRoute,
  });

  final Widget child;
  final String restaurantId;
  final String branchId;
  final CustomerTab activeTab;
  final String? queueEntryId;
  final bool showBottomNav;
  final Widget? footer;
  final String? appBackRoute;

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactPhone = screenWidth < 430;
    final shellWidth = isCompactPhone ? screenWidth : 390.0;
    final horizontalInset = isCompactPhone ? 6.0 : 0.0;

    return Scaffold(
      body: ColoredBox(
        color: const Color(0xFF1E1E1E),
        child: Center(
          child: SizedBox(
            width: shellWidth,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFF4FBFF),
                          Color(0xFFF9FAFF),
                          Color(0xFFFFFFFF),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        const _CustomerBackdrop(),
                        SingleChildScrollView(
                          padding: EdgeInsets.only(top: safePadding.top + 86),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalInset,
                            ),
                            child: Column(
                              children: [
                                child,
                                ?footer,
                                SizedBox(
                                  height: showBottomNav
                                      ? safePadding.bottom + 128
                                      : 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                        _CustomerTopBar(
                          restaurantId: restaurantId,
                          branchId: branchId,
                          topInset: safePadding.top,
                          horizontalInset: horizontalInset,
                          appBackRoute: appBackRoute,
                        ),
                        if (showBottomNav)
                          _BottomNavBar(
                            restaurantId: restaurantId,
                            branchId: branchId,
                            activeTab: activeTab,
                            queueEntryId: queueEntryId,
                            bottomInset: safePadding.bottom,
                            horizontalInset: horizontalInset,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerFooter extends StatelessWidget {
  const CustomerFooter({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFECF4FF),
      padding: EdgeInsets.fromLTRB(
        24,
        compact ? 16 : 24,
        24,
        compact ? 16 : 24,
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                width: compact ? 26 : 32,
                height: compact ? 26 : 32,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF).withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0x66D8EAFE)),
                ),
                child: Image.asset(
                  'assets/brand/cubiquitous.png',
                  fit: BoxFit.contain,
                ),
              ),
              Text(
                'Powered by ',
                style: TextStyle(
                  color: const Color(0xFF3E484F),
                  fontSize: compact ? 14 : 16,
                ),
              ),
              Text(
                AppConstants.parentBrand,
                style: TextStyle(
                  color: AppColors.deepTeal,
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 8,
            children: [
              Text(
                'Privacy Policy',
                style: TextStyle(color: Color(0xFF3E484F)),
              ),
              Text(
                'Terms of Service',
                style: TextStyle(color: Color(0xFF3E484F)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerTopBar extends ConsumerWidget {
  const _CustomerTopBar({
    required this.restaurantId,
    required this.branchId,
    required this.topInset,
    required this.horizontalInset,
    required this.appBackRoute,
  });

  final String restaurantId;
  final String branchId;
  final double topInset;
  final double horizontalInset;
  final String? appBackRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(customerAuthStateProvider).asData?.value;
    final persistedDebugPhone = ref.watch(persistedDebugCustomerPhoneProvider);
    final debugPhone =
        ref.watch(debugCustomerPhoneSessionProvider).value ??
        persistedDebugPhone.asData?.value;
    final showLogout = !kIsWeb && (authUser != null || debugPhone != null);
    final installReturnTo = restaurantId.isEmpty || branchId.isEmpty
        ? null
        : '/customer/$restaurantId/$branchId';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: topInset + 64,
            padding: EdgeInsets.fromLTRB(
              22 + horizontalInset,
              topInset,
              22 + horizontalInset,
              0,
            ),
            decoration: const BoxDecoration(
              color: Color(0xCCF7FBFF),
              border: Border(bottom: BorderSide(color: Color(0x1AD8EAFE))),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F006687),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (!kIsWeb && appBackRoute != null) ...[
                      _AppBackButton(route: appBackRoute!),
                      const SizedBox(width: 8),
                    ],
                    const BrandMark(size: 25),
                    const SizedBox(width: 8),
                    const Text(
                      'EZQ',
                      style: TextStyle(
                        color: AppColors.navyText,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (kIsWeb)
                  _InstallAppButton(returnTo: installReturnTo)
                else if (showLogout)
                  _AppLogoutButton(
                    onPressed: () async {
                      ref.read(debugCustomerPhoneSessionProvider).value = null;
                      await ref
                          .read(debugCustomerSessionStoreProvider)
                          .clearPhone();
                      ref.invalidate(persistedDebugCustomerPhoneProvider);
                      await ref
                          .read(customerPhoneAuthRepositoryProvider)
                          .signOut();
                      if (!context.mounted) return;
                      context.go('/app/login');
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppLogoutButton extends StatelessWidget {
  const _AppLogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Log out',
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: const Icon(Icons.logout_rounded),
        color: AppColors.deepTeal,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.82),
          fixedSize: const Size(40, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0x33BDEAF8)),
          ),
        ),
      ),
    );
  }
}

class _AppBackButton extends StatelessWidget {
  const _AppBackButton({required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x33BDEAF8)),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.deepTeal,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _InstallAppButton extends StatelessWidget {
  const _InstallAppButton({required this.returnTo});

  final String? returnTo;

  @override
  Widget build(BuildContext context) {
    final installRoute = Uri(
      path: '/customer/install',
      queryParameters: returnTo == null ? null : {'returnTo': returnTo!},
    ).toString();

    return Semantics(
      button: true,
      label: 'Download the EZQ app',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(installRoute),
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x33BDEAF8)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14006687),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.file_download_outlined,
                  color: AppColors.deepTeal,
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  'Get app',
                  style: TextStyle(
                    color: AppColors.deepTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.restaurantId,
    required this.branchId,
    required this.activeTab,
    required this.queueEntryId,
    required this.bottomInset,
    required this.horizontalInset,
  });

  final String restaurantId;
  final String branchId;
  final CustomerTab activeTab;
  final String? queueEntryId;
  final double bottomInset;
  final double horizontalInset;

  String _withQueueEntry(String path) {
    final id = queueEntryId;
    if (id == null || id.isEmpty) return path;
    return '$path?queueEntryId=$id';
  }

  @override
  Widget build(BuildContext context) {
    final customerBase = '/customer/$restaurantId/$branchId';
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 81 + bottomInset,
            margin: EdgeInsets.symmetric(horizontal: horizontalInset),
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: const BoxDecoration(
              color: Color(0xB3F7F9FF),
              border: Border(top: BorderSide(color: Color(0x33BDC8D0))),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1412A9DC),
                  blurRadius: 24,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.group_add_outlined,
                  label: 'Join\nQueue',
                  active: activeTab == CustomerTab.join,
                  onTap: queueEntryId == null
                      ? () => context.go(customerBase)
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('You are already in the queue.'),
                          ),
                        ),
                ),
                _NavItem(
                  icon: Icons.hourglass_empty,
                  label: 'My\nStatus',
                  active: activeTab == CustomerTab.status,
                  onTap: queueEntryId == null
                      ? () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Join the queue to see your status.'),
                          ),
                        )
                      : () => context.go('$customerBase/status/$queueEntryId'),
                ),
                _NavItem(
                  icon: Icons.restaurant_menu,
                  label: 'Menu',
                  active: activeTab == CustomerTab.menu,
                  onTap: () =>
                      context.go(_withQueueEntry('$customerBase/menu')),
                ),
                _NavItem(
                  icon: Icons.support_agent,
                  label: 'Support',
                  active: activeTab == CustomerTab.support,
                  onTap: () =>
                      context.go(_withQueueEntry('$customerBase/support')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.deepTeal : const Color(0xFF3E484F);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 82,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: active ? 22 : 20),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 12,
                height: 1.1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerBackdrop extends StatelessWidget {
  const _CustomerBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF5FBFF),
                    Color(0xFFFAFBFF),
                    Color(0xFFFFFFFF),
                  ],
                ),
              ),
              child: SizedBox.expand(),
            ),
            Positioned(
              top: 74,
              right: -54,
              child: _FluidShape(
                width: 184,
                height: 132,
                color: AppColors.primaryTeal.withValues(alpha: 0.09),
              ),
            ),
            Positioned(
              top: 328,
              left: -72,
              child: _FluidShape(
                width: 210,
                height: 162,
                color: AppColors.accentPurple.withValues(alpha: 0.07),
              ),
            ),
            Positioned(
              bottom: 112,
              right: -86,
              child: _FluidShape(
                width: 238,
                height: 174,
                color: AppColors.primaryTeal.withValues(alpha: 0.06),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FluidShape extends StatelessWidget {
  const _FluidShape({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
