import 'package:intl/intl.dart';

class Formatters {
  static final _date = DateFormat('yyyy-MM-dd');
  static final _dateShort = DateFormat('dd/MM');

  static final _money = NumberFormat('#,##0.##');

  static String date(DateTime? value) =>
      value == null ? '-' : _date.format(value);
  static String dateShort(DateTime? value) =>
      value == null ? '-' : _dateShort.format(value);
  static String time(DateTime? value) {
    if (value == null) return '-';
    final h = value.hour;
    final m = value.minute.toString().padLeft(2, '0');
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final period = h < 12 ? 'ص' : 'م';
    return '$h12:$m $period';
  }

  static String money(num value, {String currency = ''}) =>
      '${_money.format(value)} $currency'.trim();

  static String minutesToHours(int minutes) {
    final sign = minutes < 0 ? '-' : '';
    final abs = minutes.abs();
    final h = abs ~/ 60;
    final m = abs % 60;
    if (h == 0) return '$sign$m د';
    if (m == 0) return '$sign$h س';
    return '$sign$h س و $m د';
  }
}
