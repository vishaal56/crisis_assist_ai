import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIProxyService {
  static const String functionUrl =
      "https://us-west1-crisis-assist-ai.cloudfunctions.net/openaiChat";

  /// Pass [previousResponseId] to get continuous chat memory
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    required String crisisType,
    required String severity,
    String? previousResponseId,
  }) async {
    final res = await http.post(
      Uri.parse(functionUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "message": message,
        "crisisType": crisisType,
        "severity": severity,
        "previousResponseId": previousResponseId,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("Function error ${res.statusCode}: ${res.body}");
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}