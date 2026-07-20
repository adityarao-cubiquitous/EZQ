import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _errorCorrectionLevel = QrErrorCorrectLevel.M;

QrPainter qrPainterFor(String data) => QrPainter(
  data: data,
  version: QrVersions.auto,
  errorCorrectionLevel: _errorCorrectionLevel,
  gapless: true,
);

Future<Uint8List> generateQrPng(String data) async {
  const imageSize = 1024.0;
  const quietZone = 64.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, imageSize, imageSize),
      Paint()..color = Colors.white,
    )
    ..translate(quietZone, quietZone);
  qrPainterFor(
    data,
  ).paint(canvas, const Size.square(imageSize - (quietZone * 2)));
  final image = await recorder.endRecording().toImage(
    imageSize.toInt(),
    imageSize.toInt(),
  );
  final imageData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (imageData == null) {
    throw StateError('Could not render the QR code.');
  }
  return imageData.buffer.asUint8List(
    imageData.offsetInBytes,
    imageData.lengthInBytes,
  );
}

String generateQrSvg(String data) {
  final code = QrCode.fromData(
    data: data,
    errorCorrectLevel: _errorCorrectionLevel,
  );
  final image = QrImage(code);
  const quietZone = 4;
  final viewBoxSize = image.moduleCount + (quietZone * 2);
  final paths = StringBuffer();
  for (var row = 0; row < image.moduleCount; row++) {
    for (var column = 0; column < image.moduleCount; column++) {
      if (image.isDark(row, column)) {
        paths.write('M${column + quietZone} ${row + quietZone}h1v1h-1z');
      }
    }
  }
  return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $viewBoxSize $viewBoxSize" shape-rendering="crispEdges"><rect width="100%" height="100%" fill="#fff"/><path d="$paths" fill="#000"/></svg>''';
}
