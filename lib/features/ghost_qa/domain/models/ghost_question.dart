/// Represents an interactive question asked to the Ghost repository analyst.
class GhostQuestion {
  final String text;
  final DateTime askedAt;

  GhostQuestion({required this.text, DateTime? askedAt})
    : askedAt = askedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'text': text,
    'asked_at': askedAt.toIso8601String(),
  };

  factory GhostQuestion.fromJson(Map<String, dynamic> json) {
    return GhostQuestion(
      text: json['text'] as String,
      askedAt: DateTime.parse(json['asked_at'] as String),
    );
  }
}
