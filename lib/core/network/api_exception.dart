/// Error yang sudah diterjemahkan ke pesan yang layak ditampilkan ke user.
///
/// Repository melempar [ApiException] supaya widget tidak perlu tahu
/// detail Dio maupun HTTP.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.path});

  final String message;
  final int? statusCode;
  final String? path;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  /// Pesan yang aman ditampilkan ke pengguna.
  String get displayMessage {
    if (isUnauthorized) {
      return 'Sesi berakhir. Silakan login kembali.';
    }
    if (isForbidden) {
      return 'Akses ditolak. Akun ini bukan admin.';
    }
    return message;
  }

  @override
  String toString() => 'ApiException($statusCode, $path): $message';
}
