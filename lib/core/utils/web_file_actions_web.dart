// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> downloadWebBytes({
  required Uint8List bytes,
  required String mimeType,
  required String fileName,
}) async {
  _downloadBlob(html.Blob([bytes], mimeType), fileName);
}

Future<void> downloadWebText({
  required String content,
  required String mimeType,
  required String fileName,
}) async {
  _downloadBlob(html.Blob([content], mimeType), fileName);
}

void _downloadBlob(html.Blob blob, String fileName) {
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: objectUrl)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(objectUrl);
}

Future<void> printQrSheet({
  required String qrSvg,
  required String customerUrl,
  required String restaurantName,
  required String branchName,
  String? restaurantLogoUrl,
}) async {
  final escapedUrl = const HtmlEscape().convert(customerUrl);
  final escapedRestaurant = const HtmlEscape().convert(restaurantName);
  final escapedBranch = const HtmlEscape().convert(branchName);
  final ezqLogo = const HtmlEscape().convert(
    Uri.base.resolve('/assets/assets/brand/ezq_logo.png').toString(),
  );
  final restaurantLogo = restaurantLogoUrl == null
      ? ''
      : '''<img class="restaurant-logo" src="${const HtmlEscape().convert(_resolveUrl(restaurantLogoUrl))}" alt="">''';
  final page =
      '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Print QR</title>
    <style>
      @page { margin: 18mm; }
      * { box-sizing: border-box; }
      body { margin: 0; color: #0D1F2D; font-family: Arial, sans-serif; }
      .sheet { min-height: calc(100vh - 36mm); display: grid; place-items: center; text-align: center; }
      .card { width: min(100%, 620px); padding: 32px; border: 1px solid #dbe4e8; border-radius: 20px; }
      .logos { display: flex; align-items: center; justify-content: center; gap: 18px; margin-bottom: 20px; }
      .ezq-logo, .restaurant-logo { width: 64px; height: 64px; object-fit: contain; border-radius: 14px; }
      h1 { margin: 0; font-size: 28px; }
      .branch { margin: 6px 0 22px; color: #52646f; font-size: 18px; }
      .qr { width: min(78vw, 390px); margin: 0 auto; }
      .qr svg { display: block; width: 100%; height: auto; }
      h2 { margin: 22px 0 10px; font-size: 23px; }
      .url { overflow-wrap: anywhere; color: #52646f; font-size: 13px; line-height: 1.45; }
    </style>
  </head>
  <body>
    <main class="sheet">
      <section class="card">
        <div class="logos"><img class="ezq-logo" src="$ezqLogo" alt="EZQ">$restaurantLogo</div>
        <h1>$escapedRestaurant</h1>
        <div class="branch">$escapedBranch</div>
        <div class="qr">$qrSvg</div>
        <h2>Scan to Join Queue</h2>
        <div class="url">$escapedUrl</div>
      </section>
    </main>
    <script>
      window.addEventListener('load', async () => {
        const images = Array.from(document.images);
        await Promise.all(images.map((image) => image.complete
          ? Promise.resolve()
          : new Promise((resolve) => {
              image.addEventListener('load', resolve, { once: true });
              image.addEventListener('error', resolve, { once: true });
            })));
        if (document.fonts && document.fonts.ready) await document.fonts.ready;
        await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
        window.focus();
        window.print();
        setTimeout(() => window.close(), 250);
      });
      window.addEventListener('afterprint', () => window.close());
    </script>
  </body>
</html>
''';
  final blobUrl = html.Url.createObjectUrlFromBlob(
    html.Blob([page], 'text/html;charset=utf-8'),
  );
  html.window.open(blobUrl, '_blank');
  Timer(const Duration(minutes: 2), () => html.Url.revokeObjectUrl(blobUrl));
}

Future<bool> shareWebFile({
  required String title,
  required String text,
  required String url,
}) async {
  try {
    final data = web.ShareData(title: title, text: text, url: url);
    await web.window.navigator.share(data).toDart;
    return true;
  } catch (_) {
    return false;
  }
}

String _resolveUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null && uri.hasScheme) return url;
  if (url.startsWith('/')) return Uri.base.resolve(url).toString();
  return Uri.base.resolve('/assets/$url').toString();
}
