import 'package:intl/intl.dart';

class DateTimeUtils {
  const DateTimeUtils._();

  static String businessDate([DateTime? date]) {
    return DateFormat('yyyy-MM-dd').format(date ?? DateTime.now());
  }

  static String shortTime(DateTime date) => DateFormat('h:mm a').format(date);
}
