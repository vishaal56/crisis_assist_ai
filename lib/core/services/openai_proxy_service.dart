import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIProxyService {
  static const String functionUrl =
      "https://us-west1-crisis-assist-ai.cloudfunctions.net/openaiChat";

  Future<String> sendMessage({
    required String message,
    String? crisisType,
    String? severity,
  }) async {
    final res = await http.post(
      Uri.parse(functionUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "message": message,
        "crisisType": crisisType ?? "general",
        "severity": severity ?? "medium",
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("Function error ${res.statusCode}: ${res.body}");
    }

    final data = jsonDecode(res.body);
    return (data["reply"] ?? "").toString();
  }
}