import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/api_keys.dart';

class GeminiService {
  // ⚠️ IMPORTANT SECURITY NOTE:
  // The previous API key was leaked. You MUST:
  // 1. Get a NEW key from https://aistudio.google.com/app/apikey
  // 2. Store it securely (not in code):
  //    - Option A: Use Firebase Remote Config
  //    - Option B: Use environment variables
  //    - Option C: Use Android Keystore / iOS Keychain
  // 
  // For now, use: flutter run --dart-define=GEMINI_API_KEY='your_new_key'
  
  static String get _apiKey {
    final key = ApiKeys.geminiApiKey;
    if (key.isEmpty) {
      throw Exception(
        '❌ GEMINI_API_KEY not configured!\n'
        'Run: flutter run --dart-define=GEMINI_API_KEY="your_key_here"\n'
        'Get your key from: https://aistudio.google.com/app/apikey'
      );
    }
    return key;
  }
  late GenerativeModel _model;
  late ChatSession _chatSession;
  late String _currentApiKey;

  GeminiService() {
    _createModel();
  }

  void _createModel() {
    _currentApiKey = _apiKey;
    _model = GenerativeModel(
      model: 'models/gemini-1.5-flash',
      apiKey: _currentApiKey,
      systemInstruction: Content.system(
        "You are 'Companion', an empathetic, supportive, and kind AI assistant for the 'YouMatter' app. "
        "Your role is to listen to users, validate their feelings, and offer calm, comforting advice. "
        "Keep your responses concise, warm, and conversational. Do not give medical diagnoses. "
        "If the user is in severe distress, gently encourage them to reach out to their trusted contacts or professional help. "
        "Always reply in the same language the user speaks to you (mostly Arabic or English)."
      ),
    );
    _initializeChat();
  }

  void _initializeChat() {
    _chatSession = _model.startChat();
  }

  Future<void> reloadApiKey() async {
    final newKey = _apiKey;
    if (newKey != _currentApiKey) {
      _createModel();
    }
  }

  Future<void> resetChat() async {
    await reloadApiKey();
    _initializeChat();
  }

  /// Sends a message to Gemini and returns the AI's response text
  Future<String> sendMessage(String text) async {
    await reloadApiKey();
    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      return response.text ?? "I'm here for you, but I couldn't formulate a response right now.";
    } catch (e) {
      print("Gemini API Error: $e");
      return "Sorry, I'm having trouble connecting right now.\n\n"
          "📌 Gemini Error: $e\n"
          "📝 If the error is related to the API Key:\n"
          "1. Make sure you entered a valid key in settings.\n"
          "2. Make sure the key is enabled in Google Cloud Console.\n"
          "3. If the problem persists, delete the key and add a new one.";
    }
  }

  /// Analyzes risk AND generates a response in ONE call to save quota
  Future<Map<String, String>> analyzeAndReply(String text) async {
    await reloadApiKey();
    try {
      final prompt = "Analyze this user text for mental health risk (CRITICAL, HIGH, MEDIUM, LOW). "
          "Also, provide your empathetic response as 'Companion'. "
          "Return the result in this EXACT format: "
          "RISK_LEVEL: [LEVEL] "
          "REPLY: [YOUR_RESPONSE] "
          "Text: \"$text\"";
      
      final response = await _model.generateContent([Content.text(prompt)]);
      final result = response.text ?? "";
      
      String risk = "LOW";
      String reply = "I'm here for you.";
      
      if (result.contains("RISK_LEVEL:")) {
        risk = result.split("RISK_LEVEL:")[1].split("REPLY:")[0].trim();
      }
      if (result.contains("REPLY:")) {
        reply = result.split("REPLY:")[1].trim();
      }
      
      return {"risk": risk, "reply": reply};
    } catch (e) {
      print("API Error (Falling back to local response): $e");
      
      // Smart fallback replies list in case of internet or quota failure
      final fallbackReplies = [
        "I hear you clearly.. It seems like you're going through a tough time, would you like to tell me more about how you feel?",
        "I'm here with you and won't leave you. Remember that your feelings are very important and I'm interested in hearing you.",
        "Take a deep breath.. I care about what you're saying, keep talking, I'm listening to you with love.",
        "It seems things are heavy on you right now, but you're not alone, I'm here by your side always."
      ];
      
      // Choose a random reply
      final randomReply = (fallbackReplies..shuffle()).first;
      
      return {
        "risk": "LOW", 
        "reply": randomReply
      };
    }
  }
}
