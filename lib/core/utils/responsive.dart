import 'package:flutter/widgets.dart';

class Responsive {
  const Responsive._();

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 700;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 700 && width < 1100;
  }

  static double customerWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < 448 ? width : 390;
  }
}
