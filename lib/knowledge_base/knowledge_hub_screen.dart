import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

// If you don't have url_launcher, add it in pubspec.yaml:
// url_launcher: ^6.2.6
import 'package:url_launcher/url_launcher.dart';

/// ===============================
/// DATA MODEL (from Firebase Storage)
/// ===============================
class KnowledgeDoc {
  final String fullPath; // e.g. knowledge/SOP/abc_file.pdf
  final String name; // file name
  final String category; // SOP / Supplier / safety / test ...
  final String url; // download url
  final Map<String, String> meta; // customMetadata
  final DateTime? uploadedAt;

  KnowledgeDoc({
    required this.fullPath,
    required this.name,
    required this.category,
    required this.url,
    required this.meta,
    required this.uploadedAt,
  });
}

/// ===============================
/// CATEGORY STORE (used only for upload dialog chips)
/// NOTE: listing screen categories come from Firebase Storage dynamically
/// ===============================
class KnowledgeCategoryStore extends ChangeNotifier {
  KnowledgeCategoryStore();

  final List<String> _categories = <String>[
    'SOP',
    'Supplier',
    'Training',
    'Incidents',
    'Safety',
  ];

  List<String> get categories => List.unmodifiable(_categories);

  void add(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return;
    final exists = _categories.any((c) => c.toLowerCase() == cleaned.toLowerCase());
    if (exists) return;
    _categories.add(cleaned);
    _categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    notifyListeners();
  }

  void delete(String name) {
    _categories.removeWhere((c) => c.toLowerCase() == name.toLowerCase());
    notifyListeners();
  }
}

/// ===============================
/// Upload dialog result model
/// ===============================
class KnowledgeUploadInfo {
  final String category;
  final String ownerName;
  final String department;
  final String phone;
  final String email;
  final String reportingHead;

  KnowledgeUploadInfo({
    required this.category,
    required this.ownerName,
    required this.department,
    required this.phone,
    required this.email,
    required this.reportingHead,
  });
}

/// ===============================
/// ONE dialog: category + owner fields
/// ===============================
Future<KnowledgeUploadInfo?> showUploadInfoDialog({
  required BuildContext context,
  required KnowledgeCategoryStore store,
}) async {
  String? selected = store.categories.isNotEmpty ? store.categories.first : null;
  final newCategoryCtrl = TextEditingController();

  final ownerCtrl = TextEditingController();
  final deptCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final headCtrl = TextEditingController();

  bool validEmail(String v) => RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim());

  return showDialog<KnowledgeUploadInfo?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          String? error;

          void setError(String? msg) => setState(() => error = msg);

          return AlertDialog(
            title: const Text("Upload Knowledge (Category + Owner Info)"),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "1) Select category",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Existing categories
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (store.categories.isEmpty)
                            const Text(
                              "No categories yet. Create one below.",
                              style: TextStyle(color: Color(0xFF6B7280)),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: store.categories.map((c) {
                                final isSelected = selected == c;
                                return InkWell(
                                  onTap: () => setState(() => selected = c),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFFFDA29B) : const Color(0xFFE5E7EB),
                                      ),
                                      color: isSelected ? const Color(0xFFFEE4E2) : Colors.white,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(c, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () {
                                            store.delete(c);
                                            if (selected == c) {
                                              selected = store.categories.isNotEmpty ? store.categories.first : null;
                                            }
                                            setState(() {});
                                          },
                                          child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 10),

                          // Create new category
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: newCategoryCtrl,
                                  decoration: const InputDecoration(
                                    labelText: "New category name",
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () {
                                  final name = newCategoryCtrl.text.trim();
                                  if (name.isEmpty) return;
                                  store.add(name);
                                  newCategoryCtrl.clear();
                                  selected ??= store.categories.first;
                                  setState(() {});
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text("Add"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "2) Owner / Document info",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),

                    _dialogField(ownerCtrl, "Owner Name"),
                    const SizedBox(height: 10),
                    _dialogField(deptCtrl, "Department"),
                    const SizedBox(height: 10),
                    _dialogField(phoneCtrl, "Phone"),
                    const SizedBox(height: 10),
                    _dialogField(emailCtrl, "Email"),
                    const SizedBox(height: 10),
                    _dialogField(headCtrl, "Reporting Head"),

                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(error!, style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  final category = selected?.trim() ?? "";
                  final owner = ownerCtrl.text.trim();
                  final dept = deptCtrl.text.trim();
                  final phone = phoneCtrl.text.trim();
                  final email = emailCtrl.text.trim();
                  final head = headCtrl.text.trim();

                  if (category.isEmpty) {
                    setError("Please select a category.");
                    return;
                  }
                  if ([owner, dept, phone, email, head].any((v) => v.isEmpty)) {
                    setError("All fields are required.");
                    return;
                  }
                  if (!validEmail(email)) {
                    setError("Please enter a valid email.");
                    return;
                  }

                  Navigator.pop(
                    ctx,
                    KnowledgeUploadInfo(
                      category: category,
                      ownerName: owner,
                      department: dept,
                      phone: phone,
                      email: email,
                      reportingHead: head,
                    ),
                  );
                },
                child: const Text("Continue"),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _dialogField(TextEditingController c, String label) {
  return TextField(
    controller: c,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );
}

/// ===============================
/// SERVICE: Read EVERYTHING from Firebase Storage
/// ===============================
class KnowledgeStorageService {
  final FirebaseStorage storage;

  KnowledgeStorageService({FirebaseStorage? storage}) : storage = storage ?? FirebaseStorage.instance;

  /// Recursively reads:
  /// gs://bucket/knowledge/<category>/<files...>
  Future<List<KnowledgeDoc>> fetchAllDocs() async {
    final root = storage.ref('knowledge');
    final List<KnowledgeDoc> docs = [];

    // Walk folder tree
    Future<void> walk(Reference ref, {String? topCategory}) async {
      final result = await ref.listAll();

      // Items (files)
      for (final item in result.items) {
        // category = topCategory if known else the immediate folder name
        final category = topCategory ?? ref.name;

        final md = await item.getMetadata();
        final url = await item.getDownloadURL();
        final custom = (md.customMetadata ?? {}).map((k, v) => MapEntry(k, v ?? ''));

        DateTime? uploadedAt;
        final uploadedAtStr = custom['uploadedAt'];
        if (uploadedAtStr != null && uploadedAtStr.trim().isNotEmpty) {
          try {
            uploadedAt = DateTime.parse(uploadedAtStr.trim());
          } catch (_) {
            uploadedAt = null;
          }
        }

        docs.add(
          KnowledgeDoc(
            fullPath: item.fullPath,
            name: item.name,
            category: category,
            url: url,
            meta: custom,
            uploadedAt: uploadedAt,
          ),
        );
      }

      // Prefixes (folders)
      for (final p in result.prefixes) {
        // If we're directly under /knowledge, then p.name is the category folder.
        final nextTop = topCategory ?? p.name;
        await walk(p, topCategory: nextTop);
      }
    }

    await walk(root);

    // newest first if uploadedAt exists
    docs.sort((a, b) {
      final da = a.uploadedAt;
      final db = b.uploadedAt;
      if (da == null && db == null) return a.name.compareTo(b.name);
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    return docs;
  }

  Future<void> uploadPdf({
    required KnowledgeUploadInfo info,
    required PlatformFile file,
  }) async {
    // Always request bytes to keep it simple across platforms
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      throw Exception("File bytes are null. Ensure pickFiles(withData: true).");
    }

    final originalName = file.name;
    final safeName = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    // Use timestamp+random-ish id
    final fileId = DateTime.now().millisecondsSinceEpoch.toString();

    final storagePath = 'knowledge/${info.category}/${fileId}_$safeName';
    final ref = storage.ref(storagePath);

    final uploadedAtIso = DateTime.now().toIso8601String();

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          // Keep keys simple and consistent:
          'originalName': originalName,
          'category': info.category,
          'ownerName': info.ownerName,
          'department': info.department,
          'phone': info.phone,
          'email': info.email,
          'reportingHead': info.reportingHead,
          'uploadedAt': uploadedAtIso,
          'uploadedBy': info.email,
          'platform': kIsWeb ? 'web' : 'mobile',
        },
      ),
    );
  }
}

/// ===============================
/// UI SCREEN: KnowledgeHubScreen
/// ===============================
class KnowledgeHubScreen extends StatefulWidget {
  const KnowledgeHubScreen({super.key});

  @override
  State<KnowledgeHubScreen> createState() => _KnowledgeHubScreenState();
}

class _KnowledgeHubScreenState extends State<KnowledgeHubScreen> {
  final _service = KnowledgeStorageService();
  final _uploadStore = KnowledgeCategoryStore();

  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String _selectedCategory = 'All';

  List<KnowledgeDoc> _all = [];
  List<KnowledgeDoc> _filtered = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilters);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final docs = await _service.fetchAllDocs();
      _all = docs;
      _applyFilters();
    } catch (e) {
      _all = [];
      _filtered = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load from Storage: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  List<String> get _categoriesFromStorage {
    final set = <String>{};
    for (final d in _all) {
      if (d.category.trim().isNotEmpty) set.add(d.category.trim());
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...list];
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();

    List<KnowledgeDoc> items = List.of(_all);

    // category filter
    if (_selectedCategory != 'All') {
      items = items.where((d) => d.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
    }

    // search filter (file name + custom metadata values)
    if (q.isNotEmpty) {
      items = items.where((d) {
        final hay = StringBuffer()
          ..write(d.name.toLowerCase())
          ..write(' ')
          ..write(d.category.toLowerCase());
        for (final e in d.meta.entries) {
          hay.write(' ${e.key.toLowerCase()}: ${e.value.toLowerCase()}');
        }
        return hay.toString().contains(q);
      }).toList();
    }

    setState(() => _filtered = items);
  }

  Future<void> _upload() async {
    try {
      final info = await showUploadInfoDialog(context: context, store: _uploadStore);
      if (info == null) return;

      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      await _service.uploadPdf(info: info, file: picked.files.first);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploaded ✅')),
      );

      // refresh list
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not open PDF link.");
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied ✅')));
  }

  @override
  Widget build(BuildContext context) {
    final cats = _categoriesFromStorage;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Knowledge Hub"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
              onPressed: _upload,
              icon: const Icon(LucideIcons.upload, size: 18),
              label: const Text("Upload PDF"),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // Search
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Search file, owner, dept, email, phone...",
                prefixIcon: const Icon(LucideIcons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Category chips (from Storage folders)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: cats.map((c) {
                  final selected = _selectedCategory.toLowerCase() == c.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedCategory = c);
                        _applyFilters();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                  ? Center(
                child: Text(
                  _all.isEmpty
                      ? "No documents found in Firebase Storage path: /knowledge"
                      : "No documents match your filters.",
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              )
                  : ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _KnowledgeCard(
                  doc: _filtered[i],
                  onView: () => _openPdf(_filtered[i].url),
                  onCopy: () => _copy(_filtered[i].url),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// Card UI
/// ===============================
class _KnowledgeCard extends StatelessWidget {
  final KnowledgeDoc doc;
  final VoidCallback onView;
  final VoidCallback onCopy;

  const _KnowledgeCard({
    required this.doc,
    required this.onView,
    required this.onCopy,
  });

  String metaVal(String key) => (doc.meta[key] ?? '').trim().isEmpty ? '—' : doc.meta[key]!.trim();

  @override
  Widget build(BuildContext context) {
    final owner = metaVal('ownerName');
    final dept = metaVal('department');
    final phone = metaVal('phone');
    final email = metaVal('email');
    final head = metaVal('reportingHead');
    final uploadedBy = metaVal('uploadedBy');
    final uploadedAt = doc.uploadedAt == null ? '—' : doc.uploadedAt!.toLocal().toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                const Icon(LucideIcons.fileText, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    doc.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(doc.category),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metadata grid
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetaBox(label: "Owner", value: owner),
                _MetaBox(label: "Department", value: dept),
                _MetaBox(label: "Phone", value: phone),
                _MetaBox(label: "Email", value: email),
                _MetaBox(label: "Reporting Head", value: head),
                _MetaBox(label: "Uploaded At", value: uploadedAt),
                _MetaBox(label: "Uploaded By", value: uploadedBy),
              ],
            ),
            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onView,
                  icon: const Icon(LucideIcons.externalLink, size: 18),
                  label: const Text("View PDF"),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(LucideIcons.copy, size: 18),
                  label: const Text("Copy Link"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaBox extends StatelessWidget {
  final String label;
  final String value;

  const _MetaBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}