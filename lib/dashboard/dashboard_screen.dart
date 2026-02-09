import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:crisis_assist_ai/core/app_enums.dart';
import 'package:crisis_assist_ai/chat/chat_screen.dart';
import 'package:crisis_assist_ai/knowledge_base/knowledge_hub_screen.dart';

/// ---------------------------
/// Category store
/// ---------------------------
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

/// ---------------------------
/// Single dialog model
/// ---------------------------
class KnowledgeUploadInfo {
  final String category;
  final String name;
  final String department;
  final String phone;
  final String email;
  final String reportingHead;

  KnowledgeUploadInfo({
    required this.category,
    required this.name,
    required this.department,
    required this.phone,
    required this.email,
    required this.reportingHead,
  });
}

/// ---------------------------
/// Single dialog: category + owner info
/// ---------------------------
Future<KnowledgeUploadInfo?> showKnowledgeUploadDialog({
  required BuildContext context,
  required KnowledgeCategoryStore store,
}) async {
  final nameCtrl = TextEditingController();
  final deptCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final headCtrl = TextEditingController();
  final newCatCtrl = TextEditingController();

  String? selectedCategory = store.categories.isNotEmpty ? store.categories.first : null;

  bool validEmail(String v) => RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim());

  return showDialog<KnowledgeUploadInfo?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      String? error;

      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text("Upload Knowledge"),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category selector + add category
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Category",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),

                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            items: store.categories
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) => setState(() => selectedCategory = v),
                            decoration: const InputDecoration(
                              labelText: "Select category",
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: newCatCtrl,
                                  decoration: const InputDecoration(
                                    labelText: "New category (optional)",
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () {
                                  final name = newCatCtrl.text.trim();
                                  if (name.isEmpty) return;
                                  store.add(name);
                                  newCatCtrl.clear();
                                  setState(() {
                                    selectedCategory = name;
                                  });
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text("Add"),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          const Text(
                            "Tip: You can add a new category, then select it.",
                            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Owner fields
                    _inputField(nameCtrl, "Owner Name"),
                    const SizedBox(height: 10),
                    _inputField(deptCtrl, "Department"),
                    const SizedBox(height: 10),
                    _inputField(phoneCtrl, "Phone"),
                    const SizedBox(height: 10),
                    _inputField(emailCtrl, "Email"),
                    const SizedBox(height: 10),
                    _inputField(headCtrl, "Reporting Head"),

                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: Colors.red)),
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
                  final cat = selectedCategory?.trim() ?? "";
                  final name = nameCtrl.text.trim();
                  final dept = deptCtrl.text.trim();
                  final phone = phoneCtrl.text.trim();
                  final email = emailCtrl.text.trim();
                  final head = headCtrl.text.trim();

                  if (cat.isEmpty ||
                      name.isEmpty ||
                      dept.isEmpty ||
                      phone.isEmpty ||
                      email.isEmpty ||
                      head.isEmpty) {
                    setState(() => error = "All fields are required.");
                    return;
                  }
                  if (!validEmail(email)) {
                    setState(() => error = "Please enter a valid email.");
                    return;
                  }

                  Navigator.pop(
                    ctx,
                    KnowledgeUploadInfo(
                      category: cat,
                      name: name,
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

Widget _inputField(TextEditingController c, String label) {
  return TextField(
    controller: c,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );
}

/// ---------------------------
/// Dashboard Screen
/// ---------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  CrisisType _crisis = CrisisType.supplierFailure;
  Severity _severity = Severity.high;

  final KnowledgeCategoryStore _categoryStore = KnowledgeCategoryStore();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 1100;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (isWide) _Sidebar(onOpenChat: _openChat),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: isWide ? _wideLayout(context) : _narrowLayout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wideLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Column(
            children: [
              _TopBar(isWide: true, onOpenChat: _openChat),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _CrisisHeader(
                        crisis: _crisis,
                        severity: _severity,
                        onCrisisChanged: (c) => setState(() => _crisis = c),
                        onSeverityChanged: (s) => setState(() => _severity = s),
                        onOpenChat: _openChat,
                      ),
                      const SizedBox(height: 14),
                      _QuickActions(
                        onSelect: (c) {
                          setState(() => _crisis = c);
                          _openChat();
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: const [
                          Expanded(
                            child: _KpiCard(
                              title: "Avg Response",
                              value: "4.2s",
                              icon: LucideIcons.timer,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _KpiCard(
                              title: "Sources Used",
                              value: "12",
                              icon: LucideIcons.bookOpen,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _KpiCard(
                              title: "Open Incidents",
                              value: "3",
                              icon: LucideIcons.alertTriangle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Expanded(flex: 6, child: _RecentActivity()),
                          SizedBox(width: 12),
                          Expanded(flex: 4, child: _RecommendedPlaybooks()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: _RightPanelEvidence(categoryStore: _categoryStore),
        ),
      ],
    );
  }

  Widget _narrowLayout(BuildContext context) {
    return Column(
      children: [
        _TopBar(isWide: false, onOpenChat: _openChat),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _CrisisHeader(
                  crisis: _crisis,
                  severity: _severity,
                  onCrisisChanged: (c) => setState(() => _crisis = c),
                  onSeverityChanged: (s) => setState(() => _severity = s),
                  onOpenChat: _openChat,
                ),
                const SizedBox(height: 14),
                _QuickActions(
                  onSelect: (c) {
                    setState(() => _crisis = c);
                    _openChat();
                  },
                ),
                const SizedBox(height: 14),
                _RightPanelEvidence(categoryStore: _categoryStore),
                const SizedBox(height: 14),
                const _RecentActivity(),
                const SizedBox(height: 14),
                const _RecommendedPlaybooks(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(initialCrisis: _crisis, initialSeverity: _severity),
      ),
    );
  }
}

/// ---------------------------
/// Sidebar
/// ---------------------------
class _Sidebar extends StatelessWidget {
  final VoidCallback onOpenChat;
  const _Sidebar({required this.onOpenChat});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFB42318),
                  child: Icon(LucideIcons.shield, color: Colors.white, size: 18),
                ),
                SizedBox(width: 10),
                Text("CrisisAssist AI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 18),

            _NavItem(
              icon: LucideIcons.layoutDashboard,
              label: "Dashboard",
              selected: true,
              onTap: () {},
            ),

            _NavItem(
              icon: LucideIcons.messageSquare,
              label: "AI Chat",
              selected: false,
              onTap: onOpenChat,
            ),

            _NavItem(
              icon: LucideIcons.bookOpen,
              label: "Knowledge Hub",
              selected: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => KnowledgeHubScreen(), // ✅ no const
                  ),
                );
              },
            ),

            _NavItem(
              icon: LucideIcons.settings,
              label: "Settings",
              selected: false,
              onTap: () {},
            ),

            const Spacer(),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFFF7F8FA),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: const [
                  CircleAvatar(radius: 16, child: Icon(LucideIcons.user, size: 16)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text("Employee (Supply)\nOnline", style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? const Color(0xFFFEE4E2) : Colors.transparent,
          border: Border.all(
            color: selected ? const Color(0xFFFDA29B) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool isWide;
  final VoidCallback onOpenChat;
  const _TopBar({required this.isWide, required this.onOpenChat});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!isWide)
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFB42318),
            child: Icon(LucideIcons.shield, color: Colors.white, size: 18),
          ),
        if (!isWide) const SizedBox(width: 10),

        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search SOPs, suppliers, incidents...",
              prefixIcon: const Icon(LucideIcons.search),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),

        const SizedBox(width: 12),

        OutlinedButton.icon(
          onPressed: onOpenChat,
          icon: const Icon(LucideIcons.messageSquare, size: 18),
          label: const Text("Open AI Chat"),
        ),
      ],
    );
  }
}

/// ---------------------------
/// Cards / Panels
/// ---------------------------
class _CrisisHeader extends StatelessWidget {
  final CrisisType crisis;
  final Severity severity;
  final ValueChanged<CrisisType> onCrisisChanged;
  final ValueChanged<Severity> onSeverityChanged;
  final VoidCallback onOpenChat;

  const _CrisisHeader({
    required this.crisis,
    required this.severity,
    required this.onCrisisChanged,
    required this.onSeverityChanged,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.alertCircle),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text("Active Crisis Context",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                ElevatedButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(LucideIcons.sparkles, size: 18),
                  label: const Text("Ask AI with this context"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DropdownCard<CrisisType>(
                    title: "Crisis Type",
                    value: crisis,
                    items: CrisisType.values,
                    label: (c) => switch (c) {
                      CrisisType.supplierFailure => "Supplier Failure",
                      CrisisType.productionHalt => "Production Halt",
                      CrisisType.systemOutage => "System Outage",
                      CrisisType.emergencySop => "Emergency SOP",
                    },
                    onChanged: onCrisisChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DropdownCard<Severity>(
                    title: "Severity",
                    value: severity,
                    items: Severity.values,
                    label: (s) => switch (s) {
                      Severity.low => "Low",
                      Severity.medium => "Medium",
                      Severity.high => "High",
                      Severity.critical => "Critical",
                    },
                    onChanged: onSeverityChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Tip: Choosing a crisis context makes AI answers faster and more accurate.",
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownCard<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _DropdownCard({
    required this.title,
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF7F8FA),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<T>(
            initialValue: value,
            items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(label(e)))).toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            decoration: const InputDecoration(isDense: true),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final ValueChanged<CrisisType> onSelect;
  const _QuickActions({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Quick Crisis Actions",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ActionChip(
                  icon: LucideIcons.truck,
                  title: "Supplier Failure",
                  subtitle: "Find alternates + steps",
                  onTap: () => onSelect(CrisisType.supplierFailure),
                ),
                _ActionChip(
                  icon: LucideIcons.factory,
                  title: "Production Halt",
                  subtitle: "Restart plan + contacts",
                  onTap: () => onSelect(CrisisType.productionHalt),
                ),
                _ActionChip(
                  icon: LucideIcons.server,
                  title: "System Outage",
                  subtitle: "Workarounds + IT SOP",
                  onTap: () => onSelect(CrisisType.systemOutage),
                ),
                _ActionChip(
                  icon: LucideIcons.fileText,
                  title: "Emergency SOP",
                  subtitle: "Retrieve latest SOP",
                  onTap: () => onSelect(CrisisType.emergencySop),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          color: Colors.white,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFFEE4E2),
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 18),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _KpiCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFF7F8FA),
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("Recent Activity",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            SizedBox(height: 12),
            _ActivityRow(title: "Asked: alternate suppliers for resin X12", time: "2m ago"),
            _ActivityRow(title: "Opened: SOP - Emergency Production Change", time: "18m ago"),
            _ActivityRow(title: "Resolved: IT Outage workaround checklist", time: "1h ago"),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String title;
  final String time;
  const _ActivityRow({required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(LucideIcons.dot, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(time, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ],
      ),
    );
  }
}

class _RecommendedPlaybooks extends StatelessWidget {
  const _RecommendedPlaybooks();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Recommended Playbooks",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _PlaybookTile(title: "Supplier Failure – Alternate Vendor Protocol", meta: "SOP • Updated 2 weeks ago"),
            _PlaybookTile(title: "Emergency Production Change – Safety Checklist", meta: "Checklist • Updated 1 month ago"),
            _PlaybookTile(title: "System Outage – Offline Operations Guide", meta: "Guide • Updated 3 days ago"),
          ],
        ),
      ),
    );
  }
}

class _PlaybookTile extends StatelessWidget {
  final String title;
  final String meta;
  const _PlaybookTile({required this.title, required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFEFF6FF),
            child: Icon(LucideIcons.fileText, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(meta, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, size: 18),
        ],
      ),
    );
  }
}

/// ---------------------------
/// Right Panel with Upload Knowledge button
/// ---------------------------
class _RightPanelEvidence extends StatelessWidget {
  final KnowledgeCategoryStore categoryStore;
  const _RightPanelEvidence({required this.categoryStore});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Evidence & Trust Panel",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              "Upload PDFs to build your knowledge base.",
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),

            const Divider(),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(LucideIcons.upload, size: 18),
                    label: const Text("Upload Knowledge"),
                    onPressed: () async {
                      try {
                        // 1) Open SINGLE dialog for category + metadata
                        final info = await showKnowledgeUploadDialog(
                          context: context,
                          store: categoryStore,
                        );
                        if (info == null) return;

                        // 2) Pick PDF
                        final picked = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: const ['pdf'],
                          withData: true, // web needs bytes
                        );
                        if (picked == null || picked.files.isEmpty) return;

                        final file = picked.files.first;
                        final bytes = file.bytes;
                        if (bytes == null) {
                          throw Exception('No file bytes found. Use withData: true.');
                        }

                        final originalName = file.name;
                        final safeName = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

                        // 3) Generate fileId (same for Storage + Firestore)
                        final fileId = FirebaseFirestore.instance.collection('knowledge').doc().id;

                        // 4) Storage path
                        final storagePath = 'knowledge/${info.category}/${fileId}_$safeName';
                        final ref = FirebaseStorage.instance.ref(storagePath);

                        // If you have auth, replace with FirebaseAuth user email/name
                        final uploadedBy = "unknown"; // TODO: set from FirebaseAuth

                        // 5) Upload to Storage (store metadata here too)
                        await ref.putData(
                          bytes,
                          SettableMetadata(
                            contentType: 'application/pdf',
                            customMetadata: {
                              'fileId': fileId,
                              'category': info.category,
                              'ownerName': info.name,
                              'department': info.department,
                              'phone': info.phone,
                              'email': info.email,
                              'reportingHead': info.reportingHead,
                              'uploadedAt': DateTime.now().toIso8601String(),
                              'uploadedBy': uploadedBy,
                              'platform': kIsWeb ? 'web' : 'mobile',
                              'originalName': originalName,
                            },
                          ),
                        );

                        // 6) Firestore doc
                        final url = await ref.getDownloadURL();

                        await FirebaseFirestore.instance
                            .collection('knowledge')
                            .doc(fileId)
                            .set({
                          'fileId': fileId,
                          'name': originalName,
                          'safeName': safeName,
                          'category': info.category,
                          'storagePath': storagePath,
                          'url': url,
                          'owner': {
                            'name': info.name,
                            'department': info.department,
                            'phone': info.phone,
                            'email': info.email,
                            'reportingHead': info.reportingHead,
                          },
                          'uploadedAt': FieldValue.serverTimestamp(),
                          'uploadedBy': uploadedBy,
                          'platform': kIsWeb ? 'web' : 'mobile',
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Uploaded ✅ $originalName')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Upload failed: $e')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}