import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class PdfMenuViewer extends StatelessWidget {
  const PdfMenuViewer({super.key, required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.softerSurface,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, color: AppColors.deepTeal, size: 48),
          const SizedBox(height: 14),
          const Text(
            'Menu PDF is ready',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navyText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            uri.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
