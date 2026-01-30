import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../chat/chat_screen.dart';
import '../core/app_enums.dart';
import '../knowledge_base/knowledge_hub_screen.dart';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ---------------------------
/// Category store + dialog (used by Upload Knowledge)
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
    final exists =
    _categories.any((c) => c.toLowerCase() == cleaned.toLowerCase());
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

Future<String?> showCategoryPickerDialog({
  required BuildContext context,
  required KnowledgeCategoryStore store,
}) async {
  String? selected = store.categories.isNotEmpty ? store.categories.first : null;
  final controller = TextEditingController();

  return showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Choose a category'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                        const Text(
                          'Existing categories',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        if (store.categories.isEmpty)
                          const Text(
                            'No categories yet. Create one below.',
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFFDA29B)
                                          : const Color(0xFFE5E7EB),
                                    ),
                                    color: isSelected
                                        ? const Color(0xFFFEE4E2)
                                        : Colors.white,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        c,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () {
                                          store.delete(c);
                                          if (selected == c) {
                                            selected = store.categories.isNotEmpty
                                                ? store.categories.first
                                                : null;
                                          }
                                          setState(() {});
                                        },
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Create new category
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'New category name',
                            hintText: 'e.g. Quality, Safety, Vendor Contracts',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          final name = controller.text;
                          store.add(name);
                          controller.clear();
                          if (selected == null && store.categories.isNotEmpty) {
                            selected = store.categories.first;
                          }
                          setState(() {});
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tip: Tap a category to select it. Click ✕ to delete it.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed:
                selected == null ? null : () => Navigator.pop(ctx, selected),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    },
  );
}

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
            if (isWide) _Sidebar(onOpenChat: _openChat, onOpenKnowledge: _openKnowledgeHub),
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

  void _openKnowledgeHub() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => KnowledgeHubScreen()),
    );
  }
}

/// ---------------------------
/// Sidebar
/// ---------------------------
class _Sidebar extends StatelessWidget {
  final VoidCallback onOpenChat;
  final VoidCallback onOpenKnowledge;

  const _Sidebar({required this.onOpenChat, required this.onOpenKnowledge});

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
                  child: Icon(
                    LucideIcons.shield,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  "CrisisAssist AI",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
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
              onTap: onOpenKnowledge,
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
                  CircleAvatar(
                    radius: 16,
                    child: Icon(LucideIcons.user, size: 16),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Employee (Supply)\nOnline",
                      style: TextStyle(fontSize: 12),
                    ),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
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
                  child: Text(
                    "Active Crisis Context",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
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
              "Tip: Choosing a crisis context makes AI answers faster and more accurate (less back-and-forth).",
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
            items: items
                .map(
                  (e) => DropdownMenuItem<T>(value: e, child: Text(label(e))),
            )
                .toList(),
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
            const Text(
              "Quick Crisis Actions",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
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
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                  ),
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
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
  });

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
                Text(
                  title,
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
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
            Text("Recent Activity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
            _PlaybookTile(
              title: "Supplier Failure – Alternate Vendor Protocol",
              meta: "SOP • Updated 2 weeks ago",
            ),
            _PlaybookTile(
              title: "Emergency Production Change – Safety Checklist",
              meta: "Checklist • Updated 1 month ago",
            ),
            _PlaybookTile(
              title: "System Outage – Offline Operations Guide",
              meta: "Guide • Updated 3 days ago",
            ),
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
              "AI answers will cite these sources (reduces hallucinations + improves trust).",
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            _EvidenceTile(
              title: "SOP-014: Emergency Production Change",
              meta: "SOP • Updated 2025-11-28 • Confidence: 0.86",
            ),
            _EvidenceTile(
              title: "Supplier DB: Resin Category – Tier 1 Vendors",
              meta: "Database • Updated 2025-12-01 • Confidence: 0.79",
            ),
            _EvidenceTile(
              title: "Training: New Process Line Setup",
              meta: "Training • Updated 2025-10-12 • Confidence: 0.74",
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        // 1) choose category
                        final category = await showCategoryPickerDialog(
                          context: context,
                          store: categoryStore,
                        );
                        if (category == null) return;

                        // 2) pick pdf
                        final picked = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: const ['pdf'],
                          withData: true, // required for web
                        );
                        if (picked == null || picked.files.isEmpty) return;

                        final file = picked.files.first;

                        final bytes = file.bytes;
                        if (bytes == null) {
                          throw Exception('No bytes. Ensure withData: true.');
                        }

                        final originalName = file.name;
                        final safeName = originalName.replaceAll(
                          RegExp(r'[^a-zA-Z0-9._-]'),
                          '_',
                        );

                        // 3) upload to Storage
                        final storagePath =
                            'knowledge/$category/${DateTime.now().millisecondsSinceEpoch}_$safeName';

                        final ref = FirebaseStorage.instance.ref().child(storagePath);

                        await ref.putData(
                          bytes,
                          SettableMetadata(
                            contentType: 'application/pdf',
                            customMetadata: {
                              'originalName': originalName,
                              'category': category,
                              'platform': kIsWeb ? 'web' : 'mobile',
                            },
                          ),
                        );

                        // 4) get download url
                        final url = await ref.getDownloadURL();

                        // 5) write to Firestore (database)
                        await FirebaseFirestore.instance.collection('knowledge').add({
                          'name': originalName,
                          'safeName': safeName,
                          'category': category,
                          'storagePath': storagePath,
                          'url': url,
                          'uploadedAt': FieldValue.serverTimestamp(),
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Uploaded ✅ $originalName to "$category"')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Upload failed: $e')),
                        );
                      }
                    },
                    icon: const Icon(LucideIcons.upload, size: 18),
                    label: const Text("Upload Knowledge"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(LucideIcons.shieldAlert, size: 18),
                    label: const Text("Risk Notes"),
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

class _EvidenceTile extends StatelessWidget {
  final String title;
  final String meta;
  const _EvidenceTile({required this.title, required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        color: Colors.white,
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFFEE4E2),
            child: Icon(LucideIcons.bookMarked, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(meta, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}