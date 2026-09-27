import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Satu baris transaksi.
class Transaction {
  const Transaction({
    required this.id,
    required this.jenis,
    required this.nominal,
    this.kodeUnik,
    this.nama,
    this.createdAt,
  });

  final String id;
  final String jenis;
  final int nominal;
  final String? kodeUnik;
  final String? nama;
  final DateTime? createdAt;

  /// Nama yang ditampilkan: kode voucher atau nama member.
  String get displayName => kodeUnik ?? nama ?? '-';

  /// Nominal negatif berarti koreksi, bukan pemasukan.
  bool get isKoreksi => nominal < 0;

  /// `BELI_BARU` atau `TOPUP`.
  String get jenisLabel => jenis.toUpperCase() == 'TOPUP' ? 'Topup' : 'Beli';

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id']?.toString() ?? '',
      jenis: json['jenis']?.toString() ?? '',
      nominal: (json['nominal'] as num?)?.toInt() ?? 0,
      kodeUnik: json['kodeUnik']?.toString(),
      nama: json['nama']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

/// Sumber data riwayat transaksi.
class TransactionsRepository {
  TransactionsRepository(this._api);

  final ApiClient _api;

  /// Ambil riwayat transaksi terbaru.
  ///
  /// PERLU DIKONFIRMASI: batas `limit` dan nama field belum dicek langsung ke
  /// backend. Field yang dipakai di sini mengikuti bentuk yang terlihat di
  /// aplikasi web.
  Future<List<Transaction>> fetchRecent({int limit = 100}) async {
    final data = await _api.get(
      ApiConfig.transactions,
      query: {'limit': limit},
    );
    if (data is! List) {
      throw ApiException('Format jawaban transaksi tidak dikenali.');
    }
    return data
        .whereType<Map>()
        .map((e) => Transaction.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}
