import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../data/branch_identity_repository.dart';
import '../data/menu_repository.dart';
import '../domain/menu_document.dart';
import '../domain/restaurant_branch_identity.dart';
import 'customer_restaurant_identity.dart';
import 'customer_shell.dart';
import 'pdf_menu_viewer.dart';

class CustomerMenuScreen extends ConsumerWidget {
  const CustomerMenuScreen({
    super.key,
    required this.restaurantBranchId,
    this.queueEntryId,
  });

  final String restaurantBranchId;
  final String? queueEntryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuDocumentProvider(restaurantBranchId));
    final branch = ref.watch(customerBranchLinkProvider(restaurantBranchId));
    final identity = branch.maybeWhen(
      data: (link) => link.identity,
      orElse: () => CustomerBranchLink.fallback(restaurantBranchId).identity,
    );

    return CustomerShell(
      restaurantBranchId: restaurantBranchId,
      activeTab: CustomerTab.menu,
      queueEntryId: queueEntryId,
      appBackRoute: queueEntryId == null
          ? '/app/home'
          : '/customer/$restaurantBranchId/status/$queueEntryId',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: menu.when(
          data: (document) =>
              _MenuPdfCard(identity: identity, document: document),
          loading: () => _MenuLoadingCard(identity: identity),
          error: (_, _) => _MenuUnavailableCard(
            identity: identity,
            title: 'Menu is unavailable',
            message: 'Please ask the host for the menu while we reconnect.',
            onRetry: () =>
                ref.invalidate(menuDocumentProvider(restaurantBranchId)),
          ),
        ),
      ),
    );
  }
}

class _MenuPdfCard extends StatelessWidget {
  const _MenuPdfCard({required this.identity, required this.document});

  final RestaurantBranchIdentity identity;
  final MenuDocument document;

  @override
  Widget build(BuildContext context) {
    final pdfUri = resolveCustomerMenuUri(document.pdfUrl);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: CustomerRestaurantIdentityView(identity: identity)),
          const SizedBox(height: 18),
          const Text(
            'Menu',
            style: TextStyle(
              color: AppColors.navyText,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (pdfUri == null)
            _MenuUnavailableCard(
              identity: identity,
              title: 'Menu PDF pending',
              message: 'The restaurant has not uploaded a menu PDF yet.',
              nested: true,
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 620,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PdfMenuViewer(uri: pdfUri),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuLoadingCard extends StatelessWidget {
  const _MenuLoadingCard({required this.identity});

  final RestaurantBranchIdentity identity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CustomerRestaurantIdentityView(identity: identity),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class _MenuUnavailableCard extends StatelessWidget {
  const _MenuUnavailableCard({
    required this.identity,
    required this.title,
    required this.message,
    this.nested = false,
    this.onRetry,
  });

  final RestaurantBranchIdentity identity;
  final String title;
  final String message;
  final bool nested;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.picture_as_pdf, color: AppColors.deepTeal, size: 42),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.navyText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ],
    );

    if (nested) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
        decoration: BoxDecoration(
          color: AppColors.softerSurface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CustomerRestaurantIdentityView(identity: identity),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
