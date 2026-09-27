import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import '../storage/secure_store.dart';

/// Hasil satu perintah socket.
class SocketResult {
  const SocketResult({required this.success, this.message});

  final bool success;
  final String? message;
}

/// Koneksi Socket.IO ke backend.
///
/// Backend memverifikasi JWT pada handshake lewat `auth.token`, dan hanya
/// menerima role ADMIN atau KASIR. Socket yang tidak terautentikasi tetap
/// terhubung, tetapi semua perintah aksi akan ditolak.
///
/// One [io.Socket] dipakai bersama untuk seluruh aplikasi agar tidak membuka
/// banyak koneksi sekaligus.
class SocketService {
  SocketService(this._store);

  final SecureStore _store;

  io.Socket? _socket;
  bool _connecting = false;
  Completer<void>? _connectedGate;

  /// Dipanggil saat PC atas connecting/terputus, untuk indikator di header.
  void Function(bool)? onConnectionChange;

  /// Data PC terbaru dari room dashboard.
  void Function(List<Map<String, dynamic>>)? onPcUpdate;

  bool get isConnected => _socket?.connected ?? false;

  /// Hubungkan ke server. Aman dipanggil berkali-kali.
  Future<void> connect() async {
    if (_socket != null) return;
    if (_connecting) return await _connectedGate?.future;
    _connecting = true;

    final gate = Completer<void>();
    _connectedGate = gate;

    final token = await _store.readToken();
    if (token == null || token.isEmpty) {
      _connecting = false;
      gate.complete();
      return;
    }

    final socket = io.io(
      ApiConfig.wsOrigin,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .enableForceNew()
          .build(),
    );

    socket.onConnect((_) {
      _connecting = false;
      onConnectionChange?.call(true);
      // Room dashboard menerima pembaruan status PC.
      socket.emit('dashboard:subscribe');
      if (!gate.isCompleted) gate.complete();
    });

    socket.onDisconnect((_) {
      _connecting = false;
      onConnectionChange?.call(false);
    });

    socket.onConnectError((_) {
      _connecting = false;
      onConnectionChange?.call(false);
      if (!gate.isCompleted) gate.complete();
    });

    socket.on('dashboard:pc_update', (data) {
      if (onPcUpdate == null) return;
      final payload = data is Map ? data : null;
      final pcs = payload?['pcs'];
      if (pcs is List) {
        onPcUpdate!(
          pcs
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
      }
    });

    _socket = socket;
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connecting = false;
    onConnectionChange?.call(false);
  }

  /// Kirik perintah yang expects balasan acknowledgement.
  ///
  /// Backend membalas dengan objek `{ success, message }`. Timeout 12 detik
  /// supaya tombol tidak menggantung kalau PC sedang offline.
  Future<SocketResult> emitWithAck(
    String event,
    Map<String, dynamic> data,
  ) async {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return const SocketResult(
        success: false,
        message: 'Belum terhubung ke server',
      );
    }

    final completer = Completer<dynamic>();
    try {
      socket.emitWithAck(
        event,
        data,
        ack: (dynamic res) {
          if (!completer.isCompleted) completer.complete(res);
        },
      );
      final res = await completer.future.timeout(const Duration(seconds: 12));
      if (res is Map) {
        return SocketResult(
          success: res['success'] == true,
          message: res['message']?.toString(),
        );
      }
      return const SocketResult(
          success: false, message: 'Balasan tidak dikenali');
    } on TimeoutException {
      return const SocketResult(
        success: false,
        message: 'Server tidak menjawab. PC mungkin sedang offline.',
      );
    } catch (e) {
      return SocketResult(success: false, message: e.toString());
    }
  }

  // --- Perintah PC ---

  Future<SocketResult> startPc({
    required String pcId,
    required String kode,
  }) {
    return emitWithAck('dashboard:start_pc', {'pcId': pcId, 'kode': kode});
  }

  Future<SocketResult> lockPc(String pcId) {
    return emitWithAck('dashboard:lock_pc', {'pcId': pcId});
  }

  Future<SocketResult> shutdownPc(String pcId) {
    return emitWithAck('dashboard:shutdown_pc', {'pcId': pcId});
  }
}
