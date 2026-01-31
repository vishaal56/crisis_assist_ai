import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class GeminiService {
  // ✅ Put your key here for testing only (move to backend for production).
  static const String _apiKey = 'AIzaSyAI1qnKhIfzPRgTrCkouZOlRZZMsLqutz8';

  // ✅ Fallback order: if first model is overloaded (503), try the next one.
  // IMPORTANT: Model availability varies by key/region.
  // If one doesn't work for you, run listModels() and replace with valid ones.
  static const List<String> _modelFallbacks = <String>[
    'gemini-3-flash-preview',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
  ];

  static Uri _generateUrl(String model) => Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey',
  );

  static bool _shouldRetryStatus(int code) =>
      code == 503 || code == 429 || code == 500 || code == 502 || code == 504;

  /// ✅ Call like:
  /// final reply = await GeminiService.sendMessage(prompt);
  static Future<String> sendMessage(
      String message, {
        String? systemContext,
        double temperature = 0.4,
        int maxOutputTokens = 512,
        int maxRetriesPerModel = 3,
      }) async {
    final textToSend = (systemContext == null || systemContext.trim().isEmpty)
        ? message
        : "$systemContext\n\nUser:\n$message";

    final payload = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": textToSend}
          ]
        }
      ],
      "generationConfig": {
        "temperature": temperature,
        "maxOutputTokens": maxOutputTokens,
      }
    };

    Exception? lastError;

    // Try each model in fallback list
    for (final model in _modelFallbacks) {
      for (int attempt = 0; attempt < maxRetriesPerModel; attempt++) {
        try {
          final res = await http.post(
            _generateUrl(model),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );

          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body);
            final text = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (text == null) {
              throw Exception('Gemini returned unexpected format: ${res.body}');
            }
            return text.toString().trim();
          }

          // Non-200
          if (_shouldRetryStatus(res.statusCode)) {
            // Exponential backoff + jitter
            final backoffMs = _backoffWithJitterMs(attempt);
            await Future.delayed(Duration(milliseconds: backoffMs));
            continue; // retry same model
          }

          // If it's a hard error (401/403/404 etc), stop this model and try next
          lastError = Exception('Gemini API error (${res.statusCode}) on $model: ${res.body}');
          break;
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          // retry with backoff
          final backoffMs = _backoffWithJitterMs(attempt);
          await Future.delayed(Duration(milliseconds: backoffMs));
        }
      }
    }

    // If we got here, every model failed
    return "⚠️ Gemini is busy right now (server overloaded). Please try again in a few seconds.";
  }

  static int _backoffWithJitterMs(int attempt) {
    // base: 600ms, exponential up to ~6s, plus small random jitter
    final base = 600 * pow(2, attempt).toInt();
    final capped = min(base, 6000);
    final jitter = Random().nextInt(250);
    return capped + jitter;
  }

  /// ✅ Debug helper: shows which models your API key can access.
  static Future<List<String>> listModels() async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models?key=$_apiKey',
    );

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception('ListModels error (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final models = decoded['models'] as List<dynamic>? ?? [];

    return models
        .map((m) => (m['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toList();
  }
}