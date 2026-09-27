/// Jenis akun. Sesuai enum `AccountType` di backend.
enum AccountType {
  voucher,
  member;

  String get wire => this == AccountType.voucher ? 'VOUCHER' : 'MEMBER';
  String get label => this == AccountType.voucher ? 'Voucher' : 'Member';

  static AccountType fromWire(String? value) => value?.toUpperCase() == 'MEMBER'
      ? AccountType.member
      : AccountType.voucher;
}

/// Status akun. Sesuai enum `AccountStatus` di backend.
enum AccountStatus {
  active,
  revoked,
  expired;

  String get wire => switch (this) {
        AccountStatus.active => 'ACTIVE',
        AccountStatus.revoked => 'REVOKED',
        AccountStatus.expired => 'EXPIRED',
      };

  String get label => switch (this) {
        AccountStatus.active => 'Aktif',
        AccountStatus.revoked => 'Nonaktif',
        AccountStatus.expired => 'Kedaluwarsa',
      };

  static AccountStatus fromWire(String? value) {
    switch (value?.toUpperCase()) {
      case 'REVOKED':
        return AccountStatus.revoked;
      case 'EXPIRED':
        return AccountStatus.expired;
      default:
        return AccountStatus.active;
    }
  }
}

/// Data satu voucher atau member.
class Account {
  const Account({
    required this.id,
    required this.tipe,
    required this.status,
    this.kodeUnik,
    this.nama,
    this.sisaWaktuDetik = 0,
    this.createdAt,
    this.lastUsedAt,
  });

  final String id;
  final AccountType tipe;
  final AccountStatus status;
  final String? kodeUnik;
  final String? nama;
  final int sisaWaktuDetik;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;

  /// Nama yang ditampilkan di daftar: kode untuk voucher, nama untuk member.
  String get displayName {
    if (tipe == AccountType.member) {
      return (nama?.isNotEmpty ?? false) ? nama! : (kodeUnik ?? '-');
    }
    return kodeUnik ?? (nama ?? '-');
  }

  /// Sisa waktu habis tapi status masih aktif. Ini voucher yang waktunya sudah
  /// dipakai habis, bukan voucher invalid, jadi ditampilkan sebagai "Habis".
  bool get isHabis => sisaWaktuDetik == 0;

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id']?.toString() ?? '',
      tipe: AccountType.fromWire(json['tipe']?.toString()),
      status: AccountStatus.fromWire(json['status']?.toString()),
      kodeUnik: json['kodeUnik']?.toString(),
      nama: json['nama']?.toString(),
      sisaWaktuDetik: (json['sisaWaktuDetik'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      lastUsedAt: DateTime.tryParse(json['lastUsedAt']?.toString() ?? ''),
    );
  }
}
