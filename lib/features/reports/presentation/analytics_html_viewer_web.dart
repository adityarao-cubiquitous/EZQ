import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class AnalyticsHtmlViewer extends StatefulWidget {
  const AnalyticsHtmlViewer({super.key, required this.assetPath});

  final String assetPath;

  @override
  State<AnalyticsHtmlViewer> createState() => _AnalyticsHtmlViewerState();
}

class _AnalyticsHtmlViewerState extends State<AnalyticsHtmlViewer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'ezq-analytics-html-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final source = Uri.base.resolve('/assets/${widget.assetPath}').toString();
      return web.HTMLIFrameElement()
        ..src = source
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.backgroundColor = 'transparent';
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
