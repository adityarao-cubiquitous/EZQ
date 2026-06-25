import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/ezq_button.dart';
import 'customer_shell.dart';

class CustomerQrScannerScreen extends StatelessWidget {
  const CustomerQrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomerShell(
      restaurantId: AppConstants.demoRestaurantId,
      branchId: AppConstants.demoBranchId,
      showBottomNav: false,
      appBackRoute: '/app/login',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan restaurant QR',
              style: TextStyle(
                color: AppColors.navyText,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Point your camera at the EZQ code shown at the restaurant.',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            const _ScannerFrame(),
            const SizedBox(height: 16),
            EzqButton(
              label: 'Use demo QR code',
              icon: Icons.arrow_forward_rounded,
              large: true,
              onPressed: () => context.go(
                '/customer/${AppConstants.demoRestaurantId}/${AppConstants.demoBranchId}',
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => context.go('/app/nearby'),
                icon: const Icon(Icons.near_me_rounded),
                label: const Text('Find nearby restaurants instead'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1ABDC8D0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1412A9DC),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFEFF8FC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x5534D5ED)),
              ),
              child: Stack(
                children: const [
                  Positioned.fill(child: _ScanGrid()),
                  Center(
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.deepTeal,
                      size: 72,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera scanner coming next. For now, use the demo QR code to continue as a guest.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanGrid extends StatelessWidget {
  const _ScanGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ScanGridPainter());
  }
}

class _ScanGridPainter extends CustomPainter {
  const _ScanGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryTeal.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final cornerPaint = Paint()
      ..color = AppColors.deepTeal
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    const inset = 18.0;
    const length = 42.0;
    final maxX = size.width - inset;
    final maxY = size.height - inset;
    canvas
      ..drawLine(
        const Offset(inset, inset),
        const Offset(inset + length, inset),
        cornerPaint,
      )
      ..drawLine(
        const Offset(inset, inset),
        const Offset(inset, inset + length),
        cornerPaint,
      )
      ..drawLine(Offset(maxX, inset), Offset(maxX - length, inset), cornerPaint)
      ..drawLine(Offset(maxX, inset), Offset(maxX, inset + length), cornerPaint)
      ..drawLine(Offset(inset, maxY), Offset(inset + length, maxY), cornerPaint)
      ..drawLine(Offset(inset, maxY), Offset(inset, maxY - length), cornerPaint)
      ..drawLine(Offset(maxX, maxY), Offset(maxX - length, maxY), cornerPaint)
      ..drawLine(Offset(maxX, maxY), Offset(maxX, maxY - length), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
