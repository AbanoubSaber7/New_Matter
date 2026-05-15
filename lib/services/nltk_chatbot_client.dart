import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/chatbot_config.dart';

/// Real-time chat over WebSocket to the Python NLTK FAQ server, with optional HTTP fallback.
class NltkChatbotClient {
  NltkChatbotClient({String? wsUrl, String? httpBase})
      : _wsUrl = (wsUrl ?? ChatbotConfig.wsUrl).trim(),
        _httpBase = (httpBase ?? ChatbotConfig.httpBaseUrl).trim();

  final String _wsUrl;
  final String _httpBase;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final Map<String, Completer<String>> _pending = {};
  bool _listening = false;

  Future<void> connect() async {
    if (_wsUrl.isEmpty) return;
    await disconnect();
    _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
    _listen();
  }

  void _listen() {
    if (_listening || _channel == null) return;
    _listening = true;
    _subscription = _channel!.stream.listen(
      (dynamic data) {
        try {
          final raw = data is String ? data : utf8.decode(data as List<int>);
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final type = map['type'] as String?;
          if (type == 'reply' || type == 'error') {
            final id = map['id'] as String?;
            final text = map['text'] as String? ?? '';
            if (id != null) {
              final c = _pending.remove(id);
              if (c != null && !c.isCompleted) {
                if (type == 'error') {
                  c.completeError(Exception(text.isEmpty ? 'Server error' : text));
                } else {
                  c.complete(text);
                }
              }
            }
          }
        } catch (_) {
          // ignore malformed frames
        }
      },
      onError: (Object e) {
        for (final c in _pending.values) {
          if (!c.isCompleted) {
            c.completeError(e);
          }
        }
        _pending.clear();
      },
      onDone: () {
        for (final c in _pending.values) {
          if (!c.isCompleted) {
            c.completeError(StateError('WebSocket closed'));
          }
        }
        _pending.clear();
        _listening = false;
      },
    );
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    _listening = false;
    await _channel?.sink.close();
    _channel = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(StateError('Disconnected'));
      }
    }
    _pending.clear();
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}';

  Future<String> _httpChat(String text) async {
    final base = _httpBase.endsWith('/')
        ? _httpBase.substring(0, _httpBase.length - 1)
        : _httpBase;
    final uri = Uri.parse('$base/chat');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': text}),
        )
        .timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return map['reply'] as String? ?? '';
  }

  /// Sends [text] and waits for the matching server reply (same [id] over WS).
  Future<String> sendChat(String text) async {
    Object? wsError;
    if (_wsUrl.isNotEmpty) {
      try {
        if (_channel == null) {
          await connect();
        }
        final id = _newId();
        final completer = Completer<String>();
        _pending[id] = completer;
        _channel!.sink.add(jsonEncode({'type': 'chat', 'id': id, 'text': text}));
        return await completer.future.timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            _pending.remove(id);
            throw TimeoutException('No reply from chatbot server');
          },
        );
      } catch (e) {
        wsError = e;
        await disconnect();
      }
    }

    if (_httpBase.isNotEmpty) {
      try {
        return await _httpChat(text);
      } catch (e) {
        if (wsError != null) {
          throw Exception('WebSocket failed ($wsError). HTTP failed ($e)');
        }
        rethrow;
      }
    }

    if (wsError != null) {
      throw Exception('WebSocket failed: $wsError');
    }

    throw StateError('No CHATBOT_WS_URL or CHATBOT_HTTP_BASE configured');
  }
}
