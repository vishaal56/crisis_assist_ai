import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:crisis_assist_ai/core/app_enums.dart';
import '../services/openai_proxy_service.dart';

/// Evidence panel items are simple maps so it never breaks types.
final ValueNotifier<List<Map<String, String>>> evidenceNotifier =
ValueNotifier<List<Map<String, String>>>([]);

class ChatScreen extends StatelessWidget {
  final CrisisType initialCrisis;
  final Severity initialSeverity;

  const ChatScreen({
    super.key,
    required this.initialCrisis,
    required this.initialSeverity,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 1100;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Row(
          children: [
            if (isWide)
              const SizedBox(
                width: 280,
                child: ChatHistoryPanel(),
              ),
            Expanded(
              child: ChatMainPanel(
                initialCrisis: initialCrisis,
                initialSeverity: initialSeverity,
              ),
            ),
            if (isWide)
              const SizedBox(
                width: 340,
                child: ChatEvidencePanel(),
              ),
          ],
        ),
      ),
    );
  }
}

/// -------------------- LEFT: HISTORY --------------------

class ChatHistoryPanel extends StatelessWidget {
  const ChatHistoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Conversations",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const HistoryTile(
              title: "Supplier Failure – Resin X12",
              time: "2m ago",
            ),
            const HistoryTile(
              title: "System Outage – ERP Down",
              time: "1h ago",
            ),
            const HistoryTile(
              title: "Emergency SOP – Line Change",
              time: "Yesterday",
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text("New Chat"),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryTile extends StatelessWidget {
  final String title;
  final String time;

  const HistoryTile({
    super.key,
    required this.title,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF7F8FA),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

/// -------------------- CENTER: CHAT --------------------

class ChatMainPanel extends StatefulWidget {
  final CrisisType initialCrisis;
  final Severity initialSeverity;

  const ChatMainPanel({
    super.key,
    required this.initialCrisis,
    required this.initialSeverity,
  });

  @override
  State<ChatMainPanel> createState() => _ChatMainPanelState();
}

class _ChatMainPanelState extends State<ChatMainPanel> {
  bool _loading = false;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final OpenAIProxyService _openAI = OpenAIProxyService();

  /// ✅ stores the last OpenAI response id (memory pointer)
  String? _previousResponseId;

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      isUser: false,
      text:
      "Hi! I’m CrisisAssist AI.\n\nAsk me anything about SOPs, suppliers, incidents, or immediate next steps.",
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _crisisLabel(CrisisType c) {
    switch (c) {
      case CrisisType.supplierFailure:
        return "Supplier Failure";
      case CrisisType.productionHalt:
        return "Production Halt";
      case CrisisType.systemOutage:
        return "System Outage";
      case CrisisType.emergencySop:
        return "Emergency SOP";
    }
  }

  String _severityLabel(Severity s) {
    switch (s) {
      case Severity.low:
        return "Low";
      case Severity.medium:
        return "Medium";
      case Severity.high:
        return "High";
      case Severity.critical:
        return "Critical";
    }
  }

  // ✅ backend keys
  String _crisisKey(CrisisType c) {
    switch (c) {
      case CrisisType.supplierFailure:
        return "supplierFailure";
      case CrisisType.productionHalt:
        return "productionHalt";
      case CrisisType.systemOutage:
        return "systemOutage";
      case CrisisType.emergencySop:
        return "emergencySop";
    }
  }

  String _severityKey(Severity s) {
    switch (s) {
      case Severity.low:
        return "low";
      case Severity.medium:
        return "medium";
      case Severity.high:
        return "high";
      case Severity.critical:
        return "critical";
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
      _loading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      // ✅ The Cloud Function returns a Map like:
      // { reply: "...", responseId: "...", usedFiles: [...] }
      final Map<String, dynamic> result = await _openAI.sendMessage(
        message: text,
        crisisType: _crisisKey(widget.initialCrisis),
        severity: _severityKey(widget.initialSeverity),
        previousResponseId: _previousResponseId,
      );

      final String replyText = (result["reply"] ?? "").toString().trim();
      _previousResponseId = result["responseId"]?.toString();

      final usedFiles = (result["usedFiles"] is List)
          ? (result["usedFiles"] as List).map((e) => e.toString()).toList()
          : <String>[];

      if (!mounted) return;

      setState(() {
        _messages.add(_ChatMessage(isUser: false, text: replyText.isEmpty ? "No reply received." : replyText));
      });

      evidenceNotifier.value = [
        {
          "title": "Knowledge TXT Used",
          "subtitle": usedFiles.isEmpty ? "None" : usedFiles.take(3).join(" • "),
          "confidence": "n/a",
        },
        {
          "title": "Context",
          "subtitle":
          "${_crisisLabel(widget.initialCrisis)} • ${_severityLabel(widget.initialSeverity)}",
          "confidence": "n/a",
        },
      ];
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(isUser: false, text: "⚠️ OpenAI error: $e"));
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChatTopBar(
          crisis: widget.initialCrisis,
          severity: widget.initialSeverity,
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(18),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final m = _messages[i];
              return m.isUser ? UserBubble(text: m.text) : AIBubble(text: m.text);
            },
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              "Thinking…",
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
        _ChatInputBar(
          controller: _controller,
          onSend: _send,
        ),
      ],
    );
  }
}

class _ChatTopBar extends StatelessWidget {
  final CrisisType crisis;
  final Severity severity;

  const _ChatTopBar({
    required this.crisis,
    required this.severity,
  });

  String _crisisLabel(CrisisType c) {
    switch (c) {
      case CrisisType.supplierFailure:
        return "Supplier Failure";
      case CrisisType.productionHalt:
        return "Production Halt";
      case CrisisType.systemOutage:
        return "System Outage";
      case CrisisType.emergencySop:
        return "Emergency SOP";
    }
  }

  String _severityLabel(Severity s) {
    switch (s) {
      case Severity.low:
        return "Low";
      case Severity.medium:
        return "Medium";
      case Severity.high:
        return "High";
      case Severity.critical:
        return "Critical";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(LucideIcons.messageSquare, size: 18),
          const SizedBox(width: 10),
          const Text(
            "AI Crisis Chat",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              "${_crisisLabel(crisis)} • ${_severityLabel(severity)}",
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(LucideIcons.arrowLeft, size: 18),
            label: const Text("Back"),
          ),
        ],
      ),
    );
  }
}

class UserBubble extends StatelessWidget {
  final String text;
  const UserBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(text),
      ),
    );
  }
}

class AIBubble extends StatelessWidget {
  final String text;
  const AIBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE4E2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: const TextStyle(height: 1.35)),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _ChatInputBar({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: "Ask about actions, SOPs, suppliers...",
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: onSend,
            icon: const Icon(LucideIcons.send, size: 18),
            label: const Text("Send"),
          ),
        ],
      ),
    );
  }
}

/// -------------------- RIGHT: EVIDENCE --------------------

class ChatEvidencePanel extends StatelessWidget {
  const ChatEvidencePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<List<Map<String, String>>>(
          valueListenable: evidenceNotifier,
          builder: (context, sources, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Evidence Used",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (sources.isEmpty)
                  const Text(
                    "No evidence yet.",
                    style: TextStyle(color: Color(0xFF6B7280)),
                  )
                else
                  ...sources.map(
                        (s) => EvidenceItem(
                      title: s["title"] ?? "Unknown",
                      subtitle: s["subtitle"] ?? "",
                      confidence: s["confidence"] ?? "n/a",
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class EvidenceItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String confidence;

  const EvidenceItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle),
          const SizedBox(height: 4),
          Text(
            "Confidence: $confidence",
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

/// -------------------- MODEL --------------------

class _ChatMessage {
  final bool isUser;
  final String text;
  _ChatMessage({required this.isUser, required this.text});
}