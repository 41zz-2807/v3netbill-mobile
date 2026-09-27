/// Status PC. Mengikuti enum `PcStatus` di backend.
enum PcStatus {
  active,
  idle,
  offline;

  /// Nilai yang disimpan backend (`IDLE`, `ACTIVE`, `OFFLINE`).
  String get wire => switch (this) {
        PcStatus.active => 'ACTIVE',
        PcStatus.idle => 'IDLE',
        PcStatus.offline => 'OFFLINE',
      };

  String get label => switch (this) {
        PcStatus.active => 'Aktif',
        PcStatus.idle => 'Idle',
        PcStatus.offline => 'Offline',
      };

  /// PC offline tidak punya sesi, jadi tidak bisa dikunci atau dimatikan.
  bool get canOperate => this != PcStatus.offline;

  static PcStatus fromWire(String? value) {
    switch (value?.toUpperCase()) {
      case 'ACTIVE':
        return PcStatus.active;
      case 'OFFLINE':
        return PcStatus.offline;
      default:
        return PcStatus.idle;
    }
  }
}

/// Sesi yang sedang berjalan di sebuah PC.
///
/// Datanya dikirim backend lewat `dashboard:pc_update` dan endpoint
/// `GET /pcs` (yang lebih sederhana, tanpa `session`).
class PcSession {
  const PcSession({
    this.kodeUnik,
    this.nama,
    this.tipe,
    this.sisaDetik = 0,
  });

  final String? kodeUnik;
  final String? nama;
  final String? tipe;
  final int sisaDetik;

  /// Nama akun yang dipakai sesi ini.
  String get displayName {
    if (nama != null && nama!.isNotEmpty) return nama!;
    if (kodeUnik != null && kodeUnik!.isNotEmpty) return kodeUnik!;
    return '-';
  }

  factory PcSession.fromJson(Map<String, dynamic> json) {
    return PcSession(
      kodeUnik: json['kodeUnik']?.toString(),
      nama: json['nama']?.toString(),
      tipe: json['tipe']?.toString(),
      sisaDetik: (json['sisaDetik'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Data satu PC.
class Pc {
  const Pc({
    required this.id,
    required this.namaPc,
    required this.status,
    this.ipClient,
    this.lastHeartbeatAt,
    this.session,
  });

  final String id;
  final String namaPc;
  final PcStatus status;

  /// Hanya data tampilan, bukan identitas PC.
  final String? ipClient;
  final DateTime? lastHeartbeatAt;
  final PcSession? session;

  bool get hasSession => session != null;

  /// Berapa detik sejak heartbeat terakhir, atau null kalau tidak pernah.
  int? get detikSejakHeartbeat {
    final t = lastHeartbeatAt;
    if (t == null) return null;
    final d = DateTime.now().difference(t.toLocal()).inSeconds;
    return d < 0 ? 0 : d;
  }

  /// Ambang heartbeat yang masih dianggap sehat.
  ///
  /// Agent PC mengirim heartbeat secara berkala, jadi 30 detik tanpa satu pun
  /// heartbeat berarti koneksi sudah tidak sehat walau status di server masih
  ///bilang IDLE.
  static const ambangSehatDetik = 30;

  /// Icon heartbeat hijau kalau agent masih sehat koneksinya.
  bool get heartbeatSehat {
    final d = detikSejakHeartbeat;
    return d != null && d < ambangSehatDetik;
  }

  factory Pc.fromJson(Map<String, dynamic> json) {
    final sess = json['session'];
    return Pc(
      id: json['id']?.toString() ?? '',
      namaPc: json['namaPc']?.toString() ?? json['nama']?.toString() ?? '-',
      status: PcStatus.fromWire(json['status']?.toString()),
      ipClient: json['ipClient']?.toString(),
      lastHeartbeatAt: DateTime.tryParse(
        json['lastHeartbeatAt']?.toString() ?? '',
      ),
      session: sess is Map
          ? PcSession.fromJson(Map<String, dynamic>.from(sess))
          : null,
    );
  }

  /// `agentToken` sengaja tidak pernah dibaca ke model ini walaupun backend
  /// mengirimkannya. Token itu rahasia milik agent, aplikasi operator tidak
  /// membutuhkannya.
  Map<String, dynamic> toJson() => {
        'id': id,
        'namaPc': namaPc,
        'status': status.wire,
        'ipClient': ipClient,
        'lastHeartbeatAt': lastHeartbeatAt?.toIso8601String(),
      };
}
