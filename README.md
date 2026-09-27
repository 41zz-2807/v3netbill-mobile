# v3Netbill Mobile

Aplikasi operator warnet untuk Android. Native Flutter, **bukan** WebView, dan
terhubung langsung ke REST API backend v3Netbill yang sudah berjalan.

Base URL backend: `https://v3netbill.bilmary.my.id`

## Fitur

| Layar | Isi |
|---|---|
| Login | Username + password, token disimpan aman di `flutter_secure_storage` |
| Dashboard (Home) | Ringkasan PC Aktif / Idle / Offline, daftar PC, aksi Mulai Sesi / Kunci / Stop / Matikan |
| PC | Daftar PC dengan aksi per unit, tanpa card ringkasan |
| Realtime | Status PC dimuat ulang otomatis tiap 10 detik (polling REST) |
| Voucher & Member | Tab switcher, pencarian, daftar + badge status, tombol Buat, bar aksi Topup / Tarik / Revoke untuk yang dipilih |
| Transaksi | Riwayat transaksi, total, koreksi, pencarian |
| Profile | Identitas user, ringkasan cepat, keluar |

## Desain

- Dark mode: latar `#0B1120`, card `#151D2E` (sedikit lebih terang)
- Warna utama biru `#2563EB` dengan gradient biru-ungu
- Status: Aktif/Start hijau, Idle/Stop oranye, Offline/Shutdown/Revoke merah
- Logo memakai `assets/images/logo-v3netbill.png` (PNG transparan)

## Arsitektur

```
lib/
├── core/
│   ├── config/api_config.dart     # semua URL di satu tempat
│   ├── network/api_client.dart    # Dio + interceptor Bearer token
│   ├── network/api_exception.dart # error siap tampil ke user
│   ├── router/app_shell.dart      # login gate + bottom navigation
│   ├── storage/secure_store.dart  # token
│   └── theme/                     # warna + tema dark
├── shared/
│   ├── utils/formatters.dart      # rupiah, durasi, waktu relatif
│   └── widgets/common.dart        # StatusBadge, EmptyState, StatCard
└── features/
    ├── auth/      data / models / providers / view
    ├── pcs/       data / models / providers / view (+ widgets/pc_card.dart)
    ├── accounts/  data / models / providers / view
    ├── transactions/ view
    └── profile/   view
```

State management memakai **Provider** (dipilih karena lebih sederhana untuk
jumlah layar sekarang; Riverpod bisa ditambahkan nanti kalau state antar layar makin
kompleks).

## Konfigurasi

Base URL bisa dioverride saat build:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://v3netbill.bilmary.my.id/api \
  --dart-define=API_WS_URL=wss://v3netbill.bilmary.my.id/socket.io
```

Kalau tidak diisi, `lib/core/config/api_config.dart` memakai nilai default yang
sudah bawaan.

## Build APK

Otomatis lewat GitHub Actions:

- Trigger: push ke `main`/`master`, pull request, atau jalan manual
  (`workflow_dispatch`)
- Hasilnya diunggah sebagai artifact bernama `v3Netbill-apk` di tab **Actions**
- APK release, split per-ABI (arm64-v8a, armeabi-v7a, x86_64)

File workflow: `.github/workflows/build-apk.yml`

Manual:

```bash
flutter pub get
flutter build apk --release
```

## Endpoint yang belum terkonfirmasi

Bagian ini **perlu dicek ke backend** sebelum dipakai penuh. Semua sudah
diberi komentar `PERLU DIKONFIRMASI` di file repository masing-masing, dan
seluruhnya terpusat di `features/*/data/` sehingga tidak menyentuh widget.

| Yang | Status | Catatan |
|---|---|---|
| `POST /auth/login` | **Terverifikasi** | Bentuk jawaban sudah dicek langsung ke server |
| `GET /pcs` | **Terverifikasi** | Field `id, namaPc, ipClient, status, lastHeartbeatAt` sudah dicek |
| `GET /accounts` | **Terverifikasi** | Field `id, tipe, kodeUnik, nama, sisaWaktuDetik, status` sudah dicek |
| `GET /transactions` | **Perlu dicek** | Bentuk field diambil dari aplikasi web, belum diverifikasi langsung |
| Aksi PC (kunci/stop/matikan) | **Perlu dicek** | Aplikasi web memakai WebSocket (`dashboard:lock_pc`, `dashboard:shutdown_pc`), bukan REST. Repo ini memakai REST lebih dulu. |
| `POST /accounts` (buat) | **Perlu dicek** | Nama field `nominal` dan `nama` belum dipastikan |
| Topup / tarik / revoke | **Perlu dicek** | Nama endpoint dan body belum dipastikan |
| Nama parameter pencarian | **Perlu dicek** | Kandidat `q` atau `search`; pencarian juga difilter di sisi klien sebagai cadangan |

Kalau ternyata backend hanya menyediakan aksi PC lewat WebSocket, yang perlu
diubah hanya `PcRepository`: Logicanya sudah dipisah dari widget.

## Catatan keamanan

- `agentToken` yang dikirim backend **tidak pernah** dimasuki ke model `Pc`.
  Token itu rahasia milik agent Windows, aplikasi operator tidak membutuhkannya.
- Token disimpan dengan `flutter_secure_storage`
  (`EncryptedSharedPreferences` di Android), bukan plain text.
- `ApiClient` otomatis memasang header `Authorization: Bearer` dan
  membersihkan sesi saat server membalas 401.

## Nama karangan karakter

Repository ini **tidak terkait** dengan repo web v3netbill maupun project MSI
agent Windows. Yang dipakai hanya endpoint REST backend yang sama.

## Status build

- Flutter 3.44.4 (stable)
- `flutter analyze` bersih, 11 test lulus
- `flutter build apk --release` berhasil, APK sekitar 52 MB
- Workflow GitHub Actions memakai Flutter 3.44.4 agar sama dengan yang
  sudah diverifikasi secara lokal
