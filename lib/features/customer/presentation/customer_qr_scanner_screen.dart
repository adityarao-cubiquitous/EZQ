import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/ezq_button.dart';
import '../data/customer_qr_repository.dart';
import 'customer_shell.dart';

class CustomerQrScannerScreen extends ConsumerStatefulWidget {
  const CustomerQrScannerScreen({super.key, this.appBackRoute});

  final String? appBackRoute;

  @override
  ConsumerState<CustomerQrScannerScreen> createState() =>
      _CustomerQrScannerScreenState();
}

class _CustomerQrScannerScreenState
    extends ConsumerState<CustomerQrScannerScreen> {
  MobileScannerController? _scannerController;
  final TextEditingController _manualCodeController = TextEditingController();
  bool _isResolving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        formats: const [BarcodeFormat.qrCode],
      );
    }
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_isResolving) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        await _resolveAndOpen(value);
        return;
      }
    }
  }

  Future<void> _resolveManualCode() async {
    final value = _manualCodeController.text.trim();
    if (value.isEmpty) {
      setState(() => _message = 'Enter the QR code or restaurant link.');
      return;
    }
    await _resolveAndOpen(value);
  }

  Future<void> _resolveAndOpen(String rawValue) async {
    setState(() {
      _isResolving = true;
      _message = null;
    });

    try {
      final route = await ref
          .read(customerQrRepositoryProvider)
          .customerRouteForQrValue(rawValue);
      if (!mounted) return;
      if (route == null) {
        setState(() {
          _message =
              'This QR does not match an active EZQ restaurant. Try another code.';
          _isResolving = false;
        });
        return;
      }
      context.go(route);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Could not verify this QR right now. Check your connection.';
        _isResolving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomerShell(
      restaurantId: AppConstants.demoRestaurantId,
      branchId: AppConstants.demoBranchId,
      showBottomNav: false,
      appBackRoute: widget.appBackRoute,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ScannerHeader(),
            const SizedBox(height: 18),
            _ScannerFrame(
              controller: _scannerController,
              isResolving: _isResolving,
              onDetect: _handleCapture,
            ),
            const SizedBox(height: 14),
            _ManualQrEntry(
              controller: _manualCodeController,
              isResolving: _isResolving,
              onSubmit: _resolveManualCode,
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              _StatusMessage(message: _message!),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isResolving
                    ? null
                    : () => context.go('/app/nearby'),
                icon: const Icon(Icons.near_me_rounded),
                label: const Text('Find nearby restaurants'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerHeader extends StatelessWidget {
  const _ScannerHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x33BDEAF8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1012A9DC),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Center(child: BrandMark(size: 30)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EZQ Camera Lens',
                style: TextStyle(
                  color: AppColors.navyText,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Scan an EZQ restaurant QR to join the right queue.',
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame({
    required this.controller,
    required this.isResolving,
    required this.onDetect,
  });

  final MobileScannerController? controller;
  final bool isResolving;
  final void Function(BarcodeCapture capture) onDetect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (controller == null)
                const _CameraFallback()
              else
                MobileScanner(
                  controller: controller!,
                  onDetect: onDetect,
                  errorBuilder: (context, error) => _CameraErrorState(
                    error: error,
                    onRetry: () async {
                      try {
                        await controller!.start();
                      } catch (_) {
                        // The error panel stays visible until access is granted.
                      }
                    },
                    onOpenSettings: AppSettings.openAppSettings,
                  ),
                ),
              if (controller != null) const _ScanOverlay(),
              if (isResolving)
                const ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraErrorState extends StatelessWidget {
  const _CameraErrorState({
    required this.error,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final MobileScannerException error;
  final Future<void> Function() onRetry;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    final title = permissionDenied
        ? 'Camera access is turned off'
        : 'Camera is unavailable';
    final description = permissionDenied
        ? 'Allow camera access in Settings to scan restaurant QR codes. You can still enter the code below.'
        : 'We could not start the camera. Try again or enter the restaurant code below.';

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEFFAFF), Color(0xFFF8FBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                permissionDenied
                    ? Icons.no_photography_outlined
                    : Icons.camera_alt_outlined,
                size: 52,
                color: AppColors.deepTeal,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.navyText,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                  if (permissionDenied)
                    FilledButton.icon(
                      onPressed: onOpenSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Open Settings'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraFallback extends StatelessWidget {
  const _CameraFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEFFAFF), Color(0xFFF8FBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x332CB3E4)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A12A9DC),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: AppColors.deepTeal,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera scan is mobile-only',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navyText,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Paste an EZQ link or QR code below to open the queue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ScanOverlayPainter());
  }
}

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()..color = const Color(0x55000000);
    final cutout = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.72,
        height: size.height * 0.72,
      ),
      const Radius.circular(22),
    );
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(cutout)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, shade);

    final gridPaint = Paint()
      ..color = AppColors.tracuraCyan.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = cutout.left + step; x < cutout.right; x += step) {
      canvas.drawLine(
        Offset(x, cutout.top),
        Offset(x, cutout.bottom),
        gridPaint,
      );
    }
    for (var y = cutout.top + step; y < cutout.bottom; y += step) {
      canvas.drawLine(
        Offset(cutout.left, y),
        Offset(cutout.right, y),
        gridPaint,
      );
    }

    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    const length = 42.0;
    final rect = cutout.outerRect;
    canvas
      ..drawLine(
        rect.topLeft,
        rect.topLeft + const Offset(length, 0),
        cornerPaint,
      )
      ..drawLine(
        rect.topLeft,
        rect.topLeft + const Offset(0, length),
        cornerPaint,
      )
      ..drawLine(
        rect.topRight,
        rect.topRight - const Offset(length, 0),
        cornerPaint,
      )
      ..drawLine(
        rect.topRight,
        rect.topRight + const Offset(0, length),
        cornerPaint,
      )
      ..drawLine(
        rect.bottomLeft,
        rect.bottomLeft + const Offset(length, 0),
        cornerPaint,
      )
      ..drawLine(
        rect.bottomLeft,
        rect.bottomLeft - const Offset(0, length),
        cornerPaint,
      )
      ..drawLine(
        rect.bottomRight,
        rect.bottomRight - const Offset(length, 0),
        cornerPaint,
      )
      ..drawLine(
        rect.bottomRight,
        rect.bottomRight - const Offset(0, length),
        cornerPaint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ManualQrEntry extends StatelessWidget {
  const _ManualQrEntry({
    required this.controller,
    required this.isResolving,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isResolving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1ABDC8D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            enabled: !isResolving,
            textInputAction: TextInputAction.go,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'QR code or EZQ link',
              prefixIcon: Icon(Icons.qr_code_2_rounded),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 12),
          EzqButton(
            label: isResolving ? 'Opening queue' : 'Open queue',
            icon: Icons.arrow_forward_rounded,
            large: true,
            onPressed: isResolving ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x44F59E0B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warningOrange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.navyText,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
