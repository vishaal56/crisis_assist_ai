class EvidenceSource {
  final String title;
  final String subtitle;
  final double confidence;

  EvidenceSource({
    required this.title,
    required this.subtitle,
    required this.confidence,
  });

  factory EvidenceSource.fromJson(Map<String, dynamic> json) {
    return EvidenceSource(
      title: json["title"],
      subtitle: json["subtitle"],
      confidence: (json["confidence"] as num).toDouble(),
    );
  }
}

class ChatResponse {
  final String answer;
  final List<EvidenceSource> sources;

  ChatResponse({required this.answer, required this.sources});

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final sources = (json["sources"] as List)
        .map((e) => EvidenceSource.fromJson(e as Map<String, dynamic>))
        .toList();

    return ChatResponse(
      answer: json["answer"],
      sources: sources,
    );
  }
}