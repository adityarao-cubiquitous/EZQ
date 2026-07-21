import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/qr_generation.dart';
import '../../../core/utils/web_file_actions.dart' as file_actions;
import '../data/qr_management_repository.dart';

typedef BranchQrArgs = ({String restaurantId, String branchId});

double qrPreviewSizeFor({required double maxWidth, required Size viewport}) {
  final resizeForLandscape =
      viewport.width >= 700 && viewport.width > viewport.height;
  final heightAwareSize = !resizeForLandscape
      ? 220.0
      : viewport.height < 600
      ? 132.0
      : viewport.height < 760
      ? 168.0
      : 220.0;
  return math.min(maxWidth, heightAwareSize);
}

final branchQrInfoProvider = StreamProvider.family<BranchQrInfo, BranchQrArgs>((
  ref,
  args,
) {
  return ref
      .watch(qrManagementRepositoryProvider)
      .watchBranchQrInfo(
        restaurantId: args.restaurantId,
        branchId: args.branchId,
      );
});

class QrManagementPanel extends ConsumerStatefulWidget {
  const QrManagementPanel({
    super.key,
    required this.restaurantId,
    required this.branchId,
  });

  final String restaurantId;
  final String branchId;

  @override
  ConsumerState<QrManagementPanel> createState() => _QrManagementPanelState();
}

class _QrManagementPanelState extends ConsumerState<QrManagementPanel> {
  @override
  Widget build(BuildContext context) {
    final qrInfo = ref.watch(
      branchQrInfoProvider((
        restaurantId: widget.restaurantId,
        branchId: widget.branchId,
      )),
    );

    return qrInfo.when(
      loading: () => const _QrPanelFrame(
        child: SizedBox(
          height: 164,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => _QrPanelFrame(
        child: SizedBox(
          height: 164,
          child: Center(
            child: Text(
              'QR details unavailable',
              style: TextStyle(color: AppColors.mutedText),
            ),
          ),
        ),
      ),
      data: (info) => _QrPanelFrame(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackContent = constraints.maxWidth < 560;
            final viewport = MediaQuery.sizeOf(context);
            final previewSize = qrPreviewSizeFor(
              maxWidth: constraints.maxWidth,
              viewport: viewport,
            );
            final actions = _QrActions(
              onCopy: () => _copyQueueUrl(context, info),
              onDownloadPng: () async => file_actions.downloadWebBytes(
                bytes: await generateQrPng(info.queueUrl),
                mimeType: 'image/png',
                fileName: info.pngFileName,
              ),
              onDownloadSvg: () => file_actions.downloadWebText(
                content: generateQrSvg(info.queueUrl),
                mimeType: 'image/svg+xml;charset=utf-8',
                fileName: info.svgFileName,
              ),
              onShare: () => _share(context, info),
              onPrint: () => file_actions.printQrSheet(
                qrSvg: generateQrSvg(info.queueUrl),
                customerUrl: info.queueUrl,
                restaurantName: info.restaurantName,
                branchName: info.branchName,
                restaurantLogoUrl: info.restaurantLogoUrl,
              ),
            );
            final details = _QrDetails(info: info);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stackContent) ...[
                  Center(
                    child: _QrPreview(info: info, size: previewSize),
                  ),
                  const SizedBox(height: 16),
                  details,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _QrPreview(info: info, size: previewSize),
                      const SizedBox(width: 20),
                      Expanded(child: details),
                    ],
                  ),
                const SizedBox(height: 14),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _copyQueueUrl(BuildContext context, BranchQrInfo info) async {
    await Clipboard.setData(ClipboardData(text: info.queueUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Queue URL copied')));
  }

  Future<void> _share(BuildContext context, BranchQrInfo info) async {
    final shared = await file_actions.shareWebFile(
      title: '${info.restaurantName} · ${info.branchName}',
      text: 'Join the queue at ${info.restaurantName}, ${info.branchName}.',
      url: info.queueUrl,
    );
    if (!shared && context.mounted) {
      await _copyQueueUrl(context, info);
    }
  }
}

class _QrPanelFrame extends StatelessWidget {
  const _QrPanelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1ABDC8D0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12006687),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _QrPreview extends StatelessWidget {
  const _QrPreview({required this.info, required this.size});

  final BranchQrInfo info;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size < 180 ? 6 : 10),
      decoration: BoxDecoration(
        color: AppColors.softerSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1ABDC8D0)),
      ),
      child: QrImageView(
        data: info.queueUrl,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
      ),
    );
  }
}

class _QrDetails extends StatelessWidget {
  const _QrDetails({required this.info});

  final BranchQrInfo info;

  @override
  Widget build(BuildContext context) {
    final generatedAt = info.generatedAt == null
        ? null
        : DateFormat('d MMM, h:mm a').format(info.generatedAt!.toLocal());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QR Management',
          style: TextStyle(
            color: AppColors.navyText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          info.branchName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepTeal,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          info.queueUrl,
          maxLines: 2,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        if (generatedAt != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [_QrBadge(label: generatedAt)],
          ),
        ],
      ],
    );
  }
}

class _QrBadge extends StatelessWidget {
  const _QrBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.deepTeal,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _QrActions extends StatelessWidget {
  const _QrActions({
    required this.onCopy,
    required this.onDownloadPng,
    required this.onDownloadSvg,
    required this.onShare,
    required this.onPrint,
  });

  final VoidCallback onCopy;
  final VoidCallback onDownloadPng;
  final VoidCallback onDownloadSvg;
  final VoidCallback onShare;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _QrActionButton(
          tooltip: 'Download PNG',
          icon: Icons.download,
          label: 'PNG',
          onPressed: onDownloadPng,
        ),
        _QrActionButton(
          tooltip: 'Download SVG',
          icon: Icons.file_download_outlined,
          label: 'SVG',
          onPressed: onDownloadSvg,
        ),
        _QrActionButton(
          tooltip: 'Copy queue URL',
          icon: Icons.link,
          label: 'Copy',
          onPressed: onCopy,
        ),
        _QrActionButton(
          tooltip: 'Share QR link',
          icon: Icons.ios_share,
          label: 'Share',
          onPressed: onShare,
        ),
        _QrActionButton(
          tooltip: 'Print QR',
          icon: Icons.print,
          label: 'Print',
          onPressed: onPrint,
        ),
      ],
    );
  }
}

class _QrActionButton extends StatelessWidget {
  const _QrActionButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepTeal,
          side: const BorderSide(color: AppColors.primaryTeal),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
