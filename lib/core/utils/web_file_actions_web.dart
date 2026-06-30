// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

Future<void> downloadWebFile({
  required String url,
  required String fileName,
}) async {
  html.AnchorElement(href: _resolveAssetUrl(url))
    ..download = fileName
    ..style.display = 'none'
    ..click();
}

Future<void> printWebFile({required String url}) async {
  final escapedUrl = const HtmlEscape().convert(_resolveAssetUrl(url));
  final page =
      '''
<!doctype html>
<html>
  <head>
    <title>Print QR</title>
    <style>
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        font-family: Arial, sans-serif;
      }
      img {
        width: min(70vw, 560px);
        height: auto;
      }
    </style>
  </head>
  <body>
    <img src="$escapedUrl" alt="EZQ QR code" onload="window.focus(); window.print();">
  </body>
</html>
''';
  final dataUrl = 'data:text/html;charset=utf-8,${Uri.encodeComponent(page)}';
  html.window.open(dataUrl, '_blank');
}

Future<bool> shareWebFile({
  required String title,
  required String text,
  required String url,
}) async {
  final subject = Uri.encodeComponent(title);
  final body = Uri.encodeComponent('$text\n\n$url');
  html.window.open('mailto:?subject=$subject&body=$body', '_blank');
  return true;
}

String _resolveAssetUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null && uri.hasScheme) return url;
  if (url.startsWith('/')) return url;
  return Uri.base.resolve('/assets/$url').toString();
}
