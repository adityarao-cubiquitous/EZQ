import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../data/menu_repository.dart';
import '../domain/menu_document.dart';
import 'customer_shell.dart';
import 'pdf_menu_viewer.dart';
import 'restaurant_logo.dart';

class CustomerMenuScreen extends ConsumerWidget {
  const CustomerMenuScreen({
    super.key,
    required this.restaurantId,
    required this.branchId,
    this.queueEntryId,
  });

  final String restaurantId;
  final String branchId;
  final String? queueEntryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(
      menuDocumentProvider((restaurantId: restaurantId, branchId: branchId)),
    );

    return CustomerShell(
      restaurantId: restaurantId,
      branchId: branchId,
      activeTab: CustomerTab.menu,
      queueEntryId: queueEntryId,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: menu.when(
          data: (document) => _MenuPdfCard(document: document),
          loading: () => const _MenuLoadingCard(),
          error: (_, _) => const _MenuUnavailableCard(
            title: 'Menu is unavailable',
            message: 'Please ask the host for the menu while we reconnect.',
          ),
        ),
      ),
    );
  }
}

class _MenuPdfCard extends StatelessWidget {
  const _MenuPdfCard({required this.document});

  final MenuDocument document;

  @override
  Widget build(BuildContext context) {
    final pdfUrl = document.pdfUrl?.trim();
    final previewImageUrl = document.previewImageUrl?.trim();

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
          const Center(child: RestaurantLogo()),
          const SizedBox(height: 18),
          Text(
            '${document.restaurantName} Menu',
            style: const TextStyle(
              color: AppColors.navyText,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            document.branchName,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          if (pdfUrl == null || pdfUrl.isEmpty)
            const _MenuUnavailableCard(
              title: 'Menu PDF pending',
              message: 'The restaurant has not uploaded a menu PDF yet.',
              nested: true,
            )
          else if (previewImageUrl != null && previewImageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 620,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Image.network(
                    previewImageUrl,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    errorBuilder: (context, error, stackTrace) {
                      return SizedBox(
                        height: 620,
                        child: PdfMenuViewer(uri: Uri.parse(pdfUrl)),
                      );
                    },
                  ),
                ),
              ),
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
                child: PdfMenuViewer(uri: Uri.parse(pdfUrl)),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuLoadingCard extends StatelessWidget {
  const _MenuLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          RestaurantLogo(),
          SizedBox(height: 24),
          CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class _MenuUnavailableCard extends StatelessWidget {
  const _MenuUnavailableCard({
    required this.title,
    required this.message,
    this.nested = false,
  });

  final String title;
  final String message;
  final bool nested;

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
        children: [const RestaurantLogo(), const SizedBox(height: 24), child],
      ),
    );
  }
}
