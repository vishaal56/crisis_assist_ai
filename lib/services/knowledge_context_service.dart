import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class KnowledgeContextService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Fetch all .txt files under:
  /// knowledge/<category>/*.txt
  Future<String> buildContextForCategory(String category) async {
    final buffer = StringBuffer();

    final categoryRef = _storage.ref('knowledge/$category');

    final listResult = await categoryRef.listAll();

    for (final item in listResult.items) {
      if (!item.name.toLowerCase().endsWith('.txt')) continue;

      // limit each file to 200 KB (safe)
      final Uint8List? data = await item.getData(200 * 1024);
      if (data == null) continue;

      final text = String.fromCharCodes(data).trim();
      if (text.isEmpty) continue;

      buffer.writeln('--- SOURCE: ${item.name} ---');
      buffer.writeln(text);
      buffer.writeln();
    }

    return buffer.toString().trim();
  }
}