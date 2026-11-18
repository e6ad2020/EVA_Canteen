import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

enum SocketConnectionPhase { connecting, connected, reconnecting }

class WsIncomingEvent {
  const WsIncomingEvent({required this.type, this.payload});

  final String type;
  final dynamic payload;
}

class EvaSocketClient {
  EvaSocketClient({this.customHttpOrigin, this.enableNetwork = true})
      : _phase = enableNetwork
            ? SocketConnectionPhase.connecting
            : SocketConnectionPhase.connected;

  String? customHttpOrigin;
  final bool enableNetwork;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  int _attempt = 0;
  bool _disposed = false;
  String? _authToken;

  final _eventsController = StreamController<WsIncomingEvent>.broadcast();
  final _phaseController = StreamController<SocketConnectionPhase>.broadcast();
  SocketConnectionPhase _phase;

  Stream<WsIncomingEvent> get events => _eventsController.stream;
  Stream<SocketConnectionPhase> get phaseStream => _phaseController.stream;
  SocketConnectionPhase get currentPhase => _phase;
  bool get isConnected => _phase == SocketConnectionPhase.connected;

  static const String defaultOrigin =
      'https://eva-canteen-backend.onrender.com';

  String get httpBaseUrl {
    final override = customHttpOrigin?.trim();
    if (override != null && override.isNotEmpty) {
      return override.endsWith('/')
          ? override.substring(0, override.length - 1)
          : override;
    }
    if (kIsWeb) {
      final base = Uri.base;
      if (base.scheme == 'http' || base.scheme == 'https') {
        final host = base.host.toLowerCase();
        final isStaticHost =
            host.endsWith('github.io') ||
            host.endsWith('pages.dev') ||
            host.endsWith('netlify.app') ||
            host.endsWith('vercel.app');
        if (!isStaticHost) {
          return '${base.scheme}://${base.authority}';
        }
      }
    }
    return defaultOrigin;
  }

  Uri get wsUri {
    final httpUri = Uri.parse(httpBaseUrl);
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return httpUri.replace(scheme: scheme, path: '');
  }

  String resolveMediaUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:')) {
      return trimmed;
    }
    final slashPrefixed = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$httpBaseUrl$slashPrefixed';
  }

  void setAuthToken(String? token) {
    _authToken = token;
    if (token != null && token.isNotEmpty && isConnected) {
      send('authenticate_session', {'token': token});
    }
  }

  void updateServerOrigin(String? newOrigin) {
    final cleaned = newOrigin?.trim();
    if (cleaned == customHttpOrigin) return;
    customHttpOrigin = (cleaned == null || cleaned.isEmpty) ? null : cleaned;
    reconnectNow();
  }

  /// Injects a synthetic server event in offline unit/widget tests.
  void injectTestEvent(String type, [dynamic payload]) {
    if (!_eventsController.isClosed) {
      _eventsController.add(WsIncomingEvent(type: type, payload: payload));
    }
  }

  void connect() {
    if (_disposed || !enableNetwork) return;
    _reconnectTimer?.cancel();
    _closeActiveChannel();

    _setPhase(
      _attempt == 0
          ? SocketConnectionPhase.connecting
          : SocketConnectionPhase.reconnecting,
    );

    try {
      final channel = WebSocketChannel.connect(wsUri);
      _channel = channel;

      channel.ready.then((_) {
        if (_disposed || _channel != channel) return;
        _attempt = 0;
        _setPhase(SocketConnectionPhase.connected);
        if (_authToken != null && _authToken!.isNotEmpty) {
          send('authenticate_session', {'token': _authToken});
        }
      }).catchError((_) {
        if (_disposed || _channel != channel) return;
        _scheduleReconnect();
      });

      _subscription = channel.stream.listen(
        (raw) {
          if (_phase != SocketConnectionPhase.connected) {
            _attempt = 0;
            _setPhase(SocketConnectionPhase.connected);
          }
          _handleRawMessage(raw);
        },
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void reconnectNow() {
    _attempt = 0;
    connect();
  }

  bool send(String type, [dynamic payload]) {
    final ch = _channel;
    if (ch == null || _phase != SocketConnectionPhase.connected) {
      return false;
    }
    try {
      final map = <String, dynamic>{
        'type': type,
        'payload': ?payload,
      };
      ch.sink.add(jsonEncode(map));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> uploadProductImage({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final token = _authToken;
    if (token == null || token.isEmpty) return null;

    final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
    final response = await http.post(
      Uri.parse('$httpBaseUrl/api/upload-image'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'dataUrl': dataUrl}),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['url'] as String?;
    }
    return null;
  }

  void _handleRawMessage(dynamic raw) {
    try {
      final text = raw is String ? raw : utf8.decode(raw as List<int>);
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type']?.toString();
        if (type != null && type.isNotEmpty) {
          _eventsController.add(
            WsIncomingEvent(type: type, payload: decoded['payload']),
          );
        }
      }
    } catch (_) {
      // Ignore malformed frames safely.
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _closeActiveChannel();
    _setPhase(SocketConnectionPhase.reconnecting);
    _reconnectTimer?.cancel();
    _attempt = (_attempt + 1).clamp(1, 5);
    final delaySeconds = switch (_attempt) {
      1 => 1,
      2 => 2,
      3 => 4,
      4 => 7,
      _ => 10,
    };
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), connect);
  }

  void _setPhase(SocketConnectionPhase next) {
    if (_phase == next) return;
    _phase = next;
    if (!_phaseController.isClosed) {
      _phaseController.add(next);
    }
  }

  void _closeActiveChannel() {
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _closeActiveChannel();
    _eventsController.close();
    _phaseController.close();
  }
}
