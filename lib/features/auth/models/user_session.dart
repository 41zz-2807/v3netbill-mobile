/// Sesi pengguna yang sedang login.
class UserSession {
  const UserSession({
    required this.token,
    required this.role,
    required this.username,
  });

  final String token;
  final String role;
  final String username;

  bool get isAdmin => role.toUpperCase() == 'ADMIN';
  bool get isKasir => !isAdmin;

  String get roleLabel => isAdmin ? 'Admin' : 'Kasir';
}
