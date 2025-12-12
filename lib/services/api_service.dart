import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:file_picker/file_picker.dart';
import '../models/chat_models.dart';

class ApiService {
  // For Flutter web, localhost is fine if backend runs on same machine.
  // If you run on phone emulator later, we’ll change this.
  static const String baseUrl = "http://127.0.0.1:8000";

  static Future<ChatResponse> sendChat({
    required String message,
    required String crisisType,
    required String severity,
  }) async {
    final url = Uri.parse("$baseUrl/chat");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "message": message,
        "crisis_type": crisisType,
        "severity": severity,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("API error: ${res.statusCode} ${res.body}");
    }

    return ChatResponse.fromJson(jsonDecode(res.body));
  }

  static Future<Map<String, dynamic>> uploadPdf(PlatformFile file) async {
    final url = Uri.parse("$baseUrl/upload");
    final req = http.MultipartRequest("POST", url);

    req.files.add(
      http.MultipartFile.fromBytes(
        "file",
        file.bytes!,
        filename: file.name,
      ),
    );

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      throw Exception("Upload failed: ${res.statusCode} ${res.body}");
    }
    return jsonDecode(res.body);
  }
}