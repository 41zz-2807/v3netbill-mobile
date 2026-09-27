import 'package:intl/intl.dart';

/// Format angka dan waktu untuk ditampilkan ke operator.
class Formatters {
  const Formatters._();

  static final _rp = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final _date = DateFormat('d MMM yyyy', 'id_ID');
  static final _dateShort = DateFormat('d MMM', 'id_ID');
  static final _time = DateFormat('HH:mm', 'id_ID');

  /// `1234567` -> `Rp 1.234.567`
  static String rupiah(num value) => _rp.format(value);

  /// Sisa waktu dalam detik.
  ///
  /// Di bawah satu jam: `MM:SS`. Satu jam ke atas: jam didahulukan seperti
  /// `2j 00:00`, bukan `2:00:00`, karena bentuk `H:MM:SS` terlihat seperti
  /// format jam-menit biasa sehingga dalam satu kolom terbaca seperti dua
  /// format berbeda.
  static String duration(int detik) {
    final d = detik <= 0 ? 0 : detik;
    final jam = d ~/ 3600;
    final menit = (d % 3600) ~/ 60;
    final detikSisa = d % 60;
    final mm = menit.toString().padLeft(2, '0');
    final ss = detikSisa.toString().padLeft(2, '0');
    if (jam > 0) {
      return '${jam}j $mm:$ss';
    }
    return '$mm:$ss';
  }

  static String date(DateTime? d) =>
      d == null ? '-' : _date.format(d.toLocal());
  static String dateShort(DateTime? d) =>
      d == null ? '-' : _dateShort.format(d.toLocal());
  static String time(DateTime? d) =>
      d == null ? '-' : _time.format(d.toLocal());
}
