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
        const val REQ_IZIN = 9101
        const val REQ_PASANG = 9102

        // Nilai status ini dibaca sisi Dart di `lib/core/apk/apk_installer.dart`.
        // Kalau diubah, ubah juga di sana.
        const val S_DITERIMA = "diterima"
        const val S_DIBATALKAN = "dibatalkan"
        const val S_IZIN_DITOLAK = "izin_ditolak"
        const val S_GAGAL = "gagal"
    }

    private var hasilMenunggu: MethodChannel.Result? = null
    private var berkasMenunggu: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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

    override fun onDestroy() {
        // Jangan tinggalkan MethodChannel.Result yang menggantung: kalau
        // aplikasi ditutup saat installer terbuka, sisi Dart menunggu
        // selamanya dan tidak pernah menampilkan apa pun lagi.
        hasilMenunggu?.success(mapOf("status" to S_DIBATALKAN))
        hasilMenunggu = null
        berkasMenunggu = null
        super.onDestroy()
    }
}
