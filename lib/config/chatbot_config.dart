/// Remote NLTK-style chatbot (WebSocket). When empty, app uses Gemini instead.
///
/// Android emulator → host machine:
/// `--dart-define=CHATBOT_WS_URL=ws://10.0.2.2:8765/ws`
///
/// Windows / iOS simulator on same machine as server:
/// `--dart-define=CHATBOT_WS_URL=ws://127.0.0.1:8765/ws`
///
/// Physical device → use your PC LAN IP, e.g. `ws://192.168.1.5:8765/ws`
class ChatbotConfig {
  ChatbotConfig._();

  static const String wsUrl = String.fromEnvironment(
    'CHATBOT_WS_URL',
    defaultValue: '',
  );

  /// HTTP base URL for same host (optional fallback). Example: `http://10.0.2.2:8765`
  static const String httpBaseUrl = String.fromEnvironment(
    'CHATBOT_HTTP_BASE',
    defaultValue: '',
  );

  static bool get useRemoteChatbot => wsUrl.trim().isNotEmpty;

  static bool get httpFallbackAvailable =>
      httpBaseUrl.trim().isNotEmpty;
}
