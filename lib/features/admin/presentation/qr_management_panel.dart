import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/web_file_actions.dart' as file_actions;
import '../data/qr_management_repository.dart';

typedef BranchQrArgs = ({String restaurantId, String branchId});

final branchQrInfoProvider = StreamProvider.family<BranchQrInfo, BranchQrArgs>((
  ref,
  args,
) {
  return ref
      .watch(qrManagementRepositoryProvider)
      .watchBranchQrInfo(
        restaurantId: args.restaurantId,
        branchSlug: args.branchId,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QrPreview(info: info),
                const SizedBox(width: 16),
                Expanded(child: _QrDetails(info: info)),
              ],
            ),
            const SizedBox(height: 14),
            _QrActions(
              onCopy: () => _copyQueueUrl(context, info),
              onDownloadPng: () => file_actions.downloadWebFile(
                url: info.pngAssetPath,
                fileName: info.pngFileName,
              ),
              onDownloadSvg: () => file_actions.downloadWebFile(
                url: info.svgAssetPath,
                fileName: info.svgFileName,
              ),
              onShare: () => _share(context, info),
              onPrint: () => file_actions.printWebFile(url: info.pngAssetPath),
            ),
          ],
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
      title: '${info.branchName} EZQ QR',
      text: 'Open this EZQ queue link for ${info.branchName}.',
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
  const _QrPreview({required this.info});

  final BranchQrInfo info;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(info.pngAssetPath);
    final isNetworkImage = uri != null && uri.hasScheme;
    return Container(
      width: 112,
      height: 112,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.softerSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1ABDC8D0)),
      ),
      child: isNetworkImage
          ? Image.network(
              info.pngAssetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.qr_code_2,
                color: AppColors.deepTeal,
                size: 52,
              ),
            )
          : Image.asset(
              info.pngAssetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.qr_code_2,
                color: AppColors.deepTeal,
                size: 52,
              ),
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
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QrBadge(label: 'v${info.qrVersion}'),
            if (generatedAt != null) _QrBadge(label: generatedAt),
          ],
        ),
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
