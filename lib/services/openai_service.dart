import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  // ⚠️ DO NOT ship keys in client apps. Use a backend for production.
  static const String apiKey = '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';

  // Good default for your app (fast + cheap)
  static const String model = 'gpt-5-mini';

  static String modelName() => model;

  static final Uri _url = Uri.parse('https://api.openai.com/v1/responses');

  /// ✅ Minimal + compatible request (NO temperature)
  static Future<String> sendMessage(
      String prompt, {
        int maxOutputTokens = 600,
      }) async {
    final payload = {
      "model": model,
      "input": [
        {"role": "user", "content": prompt}
      ],
      "max_output_tokens": maxOutputTokens,
      "text": {
        "format": {"type": "text"}
      }
    };

    final res = await http.post(
      _url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('OpenAI API error (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    return _extractText(decoded);
  }

  /// Response parsing for Dart (since output_text is SDK-only convenience)
  static String _extractText(dynamic decoded) {
    final output = decoded['output'];
    if (output is! List) return 'No output returned.';

    final buffer = StringBuffer();

    for (final item in output) {
      if (item is Map && item['type'] == 'message') {
        final content = item['content'];
        if (content is List) {
          for (final c in content) {
            if (c is Map && c['type'] == 'output_text') {
              buffer.write(c['text'] ?? '');
            }
          }
        }
      }
    }

    final text = buffer.toString().trim();
    return text.isEmpty ? 'No text returned.' : text;
  }
}