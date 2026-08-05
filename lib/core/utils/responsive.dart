import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class Responsive {
  const Responsive._();

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 700;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 700 && width < 1100;
  }

  static bool isPhone(BuildContext context) {
    final platformIsMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return platformIsMobile && MediaQuery.sizeOf(context).shortestSide < 600;
  }

  static bool isPhoneLandscape(BuildContext context) =>
      isPhone(context) &&
      MediaQuery.orientationOf(context) == Orientation.landscape;

  static double customerWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < 448 ? width : 390;
  }
}
