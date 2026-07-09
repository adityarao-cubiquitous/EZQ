import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AnalyticsHtmlViewer extends StatefulWidget {
  const AnalyticsHtmlViewer({super.key, required this.assetPath});

  final String assetPath;

  @override
  State<AnalyticsHtmlViewer> createState() => _AnalyticsHtmlViewerState();
}

class _AnalyticsHtmlViewerState extends State<AnalyticsHtmlViewer> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadFlutterAsset(widget.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
