import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RealtimeSyncService {
  RealtimeSyncService._();
  static final RealtimeSyncService instance = RealtimeSyncService._();

  static const String _kServerUrl = 'pos_pro_server_url';
  static const String _kPendingQueue = 'pos_pro_pending_sync_queue';
  static const String defaultServerUrl = 'http://127.0.0.1:8085';

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(false);
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  String _serverUrl = defaultServerUrl;
  String get serverUrl => _serverUrl;

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _started = false;
  bool _flushing = false;

  Future<void> Function()? onRemoteDataApplied;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final savedUrl = p.getString(_kServerUrl);
    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      _serverUrl = _normalizeUrl(savedUrl);
    } else if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
        _serverUrl = 'http://$host:8085';
      }
    }
    await _updatePendingCount();
    if (!_started) {
      _started = true;
      unawaited(connectAndPull());
    }
  }

  String _normalizeUrl(String raw) {
    var url = raw.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Future<void> setServerUrl(String newUrl) async {
    final p = await SharedPreferences.getInstance();
    _serverUrl = _normalizeUrl(newUrl);
    await p.setString(_kServerUrl, _serverUrl);
    _disconnectWs();
    await connectAndPull();
  }

  Uri _wsUri() {
    final httpUri = Uri.parse(_serverUrl);
    final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return httpUri.replace(
      scheme: wsScheme,
      path: '${httpUri.path}/ws',
    );
  }

  Future<void> connectAndPull() async {
    await flushQueue();
    await pullInitialState();
    _connectWs();
  }

  void _connectWs() {
    _disconnectWs();
    try {
      final channel = WebSocketChannel.connect(_wsUri());
      _channel = channel;

      channel.stream.listen(
        (event) async {
          if (!isOnline.value) {
            isOnline.value = true;
            unawaited(flushQueue());
          }
          if (event == 'pong') return;
          try {
            final decoded = jsonDecode(event.toString());
            if (decoded is Map<String, dynamic> &&
                decoded['type'] == 'collection_updated') {
              final col = decoded['collection'] as String?;
              final data = decoded['data'];
              if (col != null && data != null) {
                final p = await SharedPreferences.getInstance();
                await p.setString(col, jsonEncode(data));
                if (onRemoteDataApplied != null) {
                  await onRemoteDataApplied!();
                }
              }
            }
          } catch (_) {}
        },
        onError: (_) {
          isOnline.value = false;
          _scheduleReconnect();
        },
        onDone: () {
          isOnline.value = false;
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        try {
          _channel?.sink.add('ping');
        } catch (_) {
          isOnline.value = false;
          _channel = null;
          _scheduleReconnect();
        }
      });
    } catch (_) {
      isOnline.value = false;
      _scheduleReconnect();
    }
  }

  void _disconnectWs() {
    _pingTimer?.cancel();
    _pingTimer = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connectAndPull();
    });
  }

  Future<void> pullInitialState() async {
    try {
      final res = await http
          .get(Uri.parse('$_serverUrl/api/state'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        isOnline.value = true;
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final collections = body['collections'] as Map<String, dynamic>? ?? {};
        if (collections.isNotEmpty) {
          final p = await SharedPreferences.getInstance();
          final pending = await _loadPendingMap();
          bool changed = false;
          for (final entry in collections.entries) {
            if (pending.containsKey(entry.key)) continue;
            final val = entry.value as Map<String, dynamic>;
            final data = val['data'];
            if (data != null) {
              await p.setString(entry.key, jsonEncode(data));
              changed = true;
            }
          }
          if (changed && onRemoteDataApplied != null) {
            await onRemoteDataApplied!();
          }
        }
      } else {
        isOnline.value = false;
      }
    } catch (_) {
      isOnline.value = false;
    }
  }

  Future<void> pushCollection(String collectionKey, dynamic dataObject) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_serverUrl/api/state/$collectionKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'data': dataObject,
              ' updated_at': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        isOnline.value = true;
        await _removeFromPending(collectionKey);
        if (pendingCount.value > 0) {
          unawaited(flushQueue());
        }
        return;
      }
    } catch (_) {}

    isOnline.value = false;
    await _enqueuePending(collectionKey, dataObject);
  }

  Future<Map<String, dynamic>> _loadPendingMap() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPendingQueue);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _savePendingMap(Map<String, dynamic> map) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPendingQueue, jsonEncode(map));
    pendingCount.value = map.length;
  }

  Future<void> _updatePendingCount() async {
    final map = await _loadPendingMap();
    pendingCount.value = map.length;
  }

  Future<void> _enqueuePending(String key, dynamic data) async {
    final map = await _loadPendingMap();
    map[key] = data;
    await _savePendingMap(map);
  }

  Future<void> _removeFromPending(String key) async {
    final map = await _loadPendingMap();
    if (map.remove(key) != null) {
      await _savePendingMap(map);
    }
  }

  Future<void> flushQueue() async {
    if (_flushing) return;
    final pending = await _loadPendingMap();
    if (pending.isEmpty) return;

    _flushing = true;
    try {
      final res = await http
          .post(
            Uri.parse('$_serverUrl/api/sync-batch'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(pending),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        isOnline.value = true;
        await _savePendingMap({});
      }
    } catch (_) {
      isOnline.value = false;
    } finally {
      _flushing = false;
    }
  }
}
