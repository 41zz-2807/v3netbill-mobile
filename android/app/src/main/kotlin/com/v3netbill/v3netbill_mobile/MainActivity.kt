package com.v3netbill.v3netbill_mobile

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Pasang APK hasil unduhan, untuk fitur pembaruan diri.
 *
 * Kenapa ditulis sendiri dan bukan memakai paket `install_plugin`: manifest
 * paket itu masih memakai atribut `package="com.example.installplugin"`, yang
 * adalah ERROR KERAS sejak Android Gradle Plugin 8, sedangkan project ini
 * memakai AGP 9.0.1. Paket itu juga masih `compileSdk 28` tanpa `namespace`.
 * Menulis sendiri berarti tidak ada dependensi yang bisa rusak, dan seluruh
 * kodenya bisa dikompilasi di CI.
 *
 * Alur:
 *  1. Android 8+ meminta izin "pasang aplikasi tidak dikenal". Kalau belum,
 *     buka Pengaturan. Setelah pengguna kembali, izin dicek ULANG lalu lanjut.
 *  2. Izin sudah ada -> berkas diserahkan ke installer Android.
 *
 * PENTING: `resultCode` dari layar Pengaturan TIDAK dipakai untuk memutuskan
 * apakah izin diberikan. Android mengembalikan `RESULT_CANCELED` baik saat
 * pengguna menyalakan izin maupun menolaknya, jadi satu-satunya sumber
 * kebenaran adalah `canRequestPackageInstalls()`.
 *
 * Catatan API: `registerForActivityResult` TIDAK bisa dipakai di sini karena
 * `FlutterActivity` extends `Activity`, bukan `ComponentActivity`. Karena itu
 * memakai `startActivityForResult` + `onActivityResult`.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "v3netbill/install"
        const val CHANNEL_NOTIF = "v3netbill/notifikasi"
        const val REQ_IZIN = 9101
        const val REQ_PASANG = 9102
        const val REQ_IZIN_NOTIF = 9103

        // WAJIB sama dengan CHANNEL_ID di backend
        // (`src/notifikasi/notifikasi.service.ts`). Kalau berbeda, FCM tetap
        // membalas berhasil, tapi Android memakai channel bawaannya yang
        // importance-nya rendah: notifikasi muncul tanpa suara dan getaran.
        const val ID_CHANNEL_NOTIF = "sesi_dimulai"
        const val NAMA_CHANNEL_NOTIF = "Sesi dimulai"

        // Nilai status ini dibaca sisi Dart di `lib/core/apk/apk_installer.dart`.
        // Kalau diubah, ubah juga di sana.
        const val S_DITERIMA = "diterima"
        const val S_DIBATALKAN = "dibatalkan"
        const val S_IZIN_DITOLAK = "izin_ditolak"
        const val S_GAGAL = "gagal"
    }

    private var hasilMenunggu: MethodChannel.Result? = null
    private var berkasMenunggu: String? = null
    private var hasilNotifMenunggu: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Channel notifikasi terpisah dari channel installer. Keduanya memakai
        // `startActivityForResult`, jadi keduanya harus ditangani di
        // `onActivityResult` yang sama.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NOTIF)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "siapkanChannel" -> {
                        siapkanChannelNotifikasi()
                        result.success(true)
                    }
                    "izin" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                            // Android 12 ke bawah tidak ada izin notifikasi
                            // runtime, jadi selalu dianggap diberikan.
                            result.success(mapOf("status" to "diberi"))
                            return@setMethodCallHandler
                        }
                        if (hasIzinNotifikasi()) {
                            result.success(mapOf("status" to "diberi"))
                            return@setMethodCallHandler
                        }
                        if (hasilNotifMenunggu != null) {
                            result.success(mapOf("status" to "gagal", "pesan" to "Sudah ada permintaan izin yang berjalan."))
                            return@setMethodCallHandler
                        }
                        hasilNotifMenunggu = result
                        @Suppress("DEPRECATION")
                        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), REQ_IZIN_NOTIF)
                    }
                    "statusIzin" -> {
                        result.success(
                            mapOf("status" to if (hasIzinNotifikasi()) "diberi" else "belum"),
                        )
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "pasang") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path.isNullOrEmpty()) {
                    result.success(
                        mapOf(
                            "status" to S_GAGAL,
                            "pesan" to "Lokasi berkas APK tidak diterima.",
                        ),
                    )
                    return@setMethodCallHandler
                }
                if (hasilMenunggu != null) {
                    result.success(
                        mapOf(
                            "status" to S_GAGAL,
                            "pesan" to "Sudah ada pemasangan yang sedang berjalan.",
                        ),
                    )
                    return@setMethodCallHandler
                }
                hasilMenunggu = result
                berkasMenunggu = path
                lanjutkanKalauBoleh()
            }
    }

    private fun bolehPasang(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    private fun hasIzinNotifikasi(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

    /**
     * Buat channel notifikasi dengan importance TINGGI.
     *
     * PENTING: kalau channel tidak dibuat, FCM memakai channel bawaannya yang
     * importance-nya rendah. Notifikasi tetap muncul, tapi tanpa suara dan
     * tanpa getaran — dan itu justru bagian yang paling dibutuhkan di warnet,
     * karena kasir harus tahu ada pelanggan yang masuk dari kamar sebelah.
     */
    private fun siapkanChannelNotifikasi() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(android.app.NotificationManager::class.java) ?: return
        val channel = android.app.NotificationChannel(
            ID_CHANNEL_NOTIF,
            NAMA_CHANNEL_NOTIF,
            android.app.NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Pemberitahuan saat pelanggan memulai sesi di komputer warnet"
            enableLights(true)
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    private fun lanjutkanKalauBoleh() {
        val hasil = hasilMenunggu
        val path = berkasMenunggu
        if (hasil == null || path == null) return

        if (!bolehPasang()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                )
                @Suppress("DEPRECATION")
                startActivityForResult(intent, REQ_IZIN)
            } else {
                kirimGagal(hasil, "Izin pasang aplikasi belum diberikan.", S_IZIN_DITOLAK)
            }
            return
        }

        val berkas = File(path)
        if (!berkas.exists()) {
            kirimGagal(hasil, "Berkas APK tidak ditemukan, mungkin sudah terhapus.")
            return
        }

        val uri: Uri = try {
            FileProvider.getUriForFile(this, "$packageName.fileprovider", berkas)
        } catch (e: IllegalArgumentException) {
            // Means the file is outside cache-path / files-path, see file_paths.xml.
            kirimGagal(
                hasil,
                "Lokasi APK di luar folder yang diizinkan aplikasi: ${e.message}",
            )
            return
        }

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQ_PASANG)
    }

    private fun kirimGagal(hasil: MethodChannel.Result, pesan: String, status: String = S_GAGAL) {
        hasilMenunggu = null
        berkasMenunggu = null
        hasil.success(mapOf("status" to status, "pesan" to pesan))
    }

    @Deprecated("FlutterActivity bukan ComponentActivity, jadi API baru tidak tersedia")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val hasil = hasilMenunggu
        if (hasil == null) return

        when (requestCode) {
            REQ_IZIN -> {
                // Jangan percaya resultCode: Android memakai RESULT_CANCELED
                // untuk "izin dinyalakan" maupun "izin ditolak".
                lanjutkanKalauBoleh()
            }
            REQ_PASANG -> {
                hasilMenunggu = null
                berkasMenunggu = null
                if (resultCode == Activity.RESULT_OK) {
                    hasil.success(mapOf("status" to S_DITERIMA))
                } else {
                    // Pengguna menekan Batal atau tombol back di installer. Itu
                    // pilihan, bukan kegagalan, dan dialog unduhan harus punya
                    // jalan keluar dari sini.
                    hasil.success(mapOf("status" to S_DIBATALKAN))
                }
            }
        }
    }

    /**
     * Balasan dari `requestPermissions` untuk izin notifikasi.
     *
     * Sengaja method terpisah dari `onActivityResult`: permintaan izin lewat
     * `requestPermissions` diteruskan ke sini, bukan ke sana. Kalau ini
     * diletakkan di `onActivityResult`, hasilnya tidak pernah sampai.
     *
     * Sama seperti izin pasang aplikasi, `grantResults` dicek langsung dan
     * bukan dari `resultCode`, karena Android tidak memakai resultCode untuk
     * Ini. Pemeriksaan dilakukan ulang lewat `hasIzinNotifikasi()` supaya
     * sumber kebenaran tetap satu.
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQ_IZIN_NOTIF) return
        val hasil = hasilNotifMenunggu ?: return
        hasilNotifMenunggu = null
        hasil.success(
            mapOf("status" to if (hasIzinNotifikasi()) "diberi" else "ditolak"),
        )
    }

    override fun onDestroy() {
        // Jangan tinggalkan MethodChannel.Result yang menggantung: kalau
        // aplikasi ditutup saat installer terbuka, sisi Dart menunggu
        // selamanya dan tidak pernah menampilkan apa pun lagi.
        hasilMenunggu?.success(mapOf("status" to S_DIBATALKAN))
        hasilMenunggu = null
        berkasMenunggu = null
        // Sama untuk izin notifikasi: kalau proses mati saat dialog izin
        // tampil, sisi Dart akan menunggu selamanya.
        hasilNotifMenunggu?.success(mapOf("status" to "dibatalkan"))
        hasilNotifMenunggu = null
        super.onDestroy()
    }
}
