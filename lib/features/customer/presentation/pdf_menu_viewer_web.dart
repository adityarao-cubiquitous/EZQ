import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class PdfMenuViewer extends StatefulWidget {
  const PdfMenuViewer({super.key, required this.uri});

  final Uri uri;

  @override
  State<PdfMenuViewer> createState() => _PdfMenuViewerState();
}

class _PdfMenuViewerState extends State<PdfMenuViewer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType =
        'ezq-menu-pdf-${widget.uri.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final object = web.HTMLObjectElement()
        ..data = widget.uri.toString()
        ..type = 'application/pdf'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'auto';

      final link = web.HTMLAnchorElement()
        ..href = widget.uri.toString()
        ..text = 'Open menu PDF'
        ..target = '_blank'
        ..style.display = 'block'
        ..style.padding = '24px'
        ..style.fontFamily = 'Arial, sans-serif'
        ..style.color = '#006687';
      object.append(link);
      return object;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
