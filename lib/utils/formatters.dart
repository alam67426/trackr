import 'package:intl/intl.dart';

final _currency =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _date = DateFormat('dd MMM yyyy');
final _time = DateFormat('hh:mm a');
final _month = DateFormat('MMMM yyyy');

String money(num value) => _currency.format(value);
String shortDate(DateTime value) => _date.format(value);
String shortTime(DateTime value) => _time.format(value);
String formatDateTime(DateTime value) => '${shortDate(value)} ${shortTime(value)}';
String monthLabel(DateTime value) => _month.format(value);
