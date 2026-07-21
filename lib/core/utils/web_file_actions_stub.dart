import 'dart:typed_data';

Future<void> downloadWebBytes({
  required Uint8List bytes,
  required String mimeType,
  required String fileName,
}) async {}

Future<void> downloadWebText({
  required String content,
  required String mimeType,
  required String fileName,
}) async {}

Future<void> printQrSheet({
  required String qrSvg,
  required String customerUrl,
  required String restaurantName,
  required String branchName,
  String? restaurantLogoUrl,
}) async {}

Future<bool> shareWebFile({
  required String title,
  required String text,
  required String url,
}) async {
  return false;
}
