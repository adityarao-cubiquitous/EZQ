import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';

class PdfMenuViewer extends StatefulWidget {
  const PdfMenuViewer({super.key, required this.uri});

  final Uri uri;

  @override
  State<PdfMenuViewer> createState() => _PdfMenuViewerState();
}

class _PdfMenuViewerState extends State<PdfMenuViewer> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  Uri get _viewerUri => Uri.https('docs.google.com', '/gview', {
    'embedded': '1',
    'url': widget.uri.toString(),
  });

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..setBackgroundColor(AppColors.softerSurface)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _failed = false;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true || !mounted) return;
            setState(() {
              _loading = false;
              _failed = true;
            });
          },
        ),
      )
      ..loadRequest(_viewerUri);
  }

  @override
  void didUpdateWidget(covariant PdfMenuViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _controller.loadRequest(_viewerUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return _PdfLoadFailure(
        onRetry: () => _controller.loadRequest(_viewerUri),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const ColoredBox(
            color: AppColors.softerSurface,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _PdfLoadFailure extends StatelessWidget {
  const _PdfLoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.softerSurface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.warningOrange,
                size: 44,
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not load the menu',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navyText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
