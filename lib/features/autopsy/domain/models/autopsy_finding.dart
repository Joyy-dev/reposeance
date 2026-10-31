enum FindingKind { observed, inferred }

/// Represents an individual evidence-grounded factual finding in an autopsy.
class AutopsyFinding {
  final String text;
  final FindingKind kind;
  final List<String> evidenceIds;

  const AutopsyFinding({
    required this.text,
    required this.kind,
    required this.evidenceIds,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'kind': kind.name,
    'evidence_ids': evidenceIds,
  };

  factory AutopsyFinding.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String;
    final kindStr = json['kind'] as String;
    final kind = kindStr == 'inferred'
        ? FindingKind.inferred
        : FindingKind.observed;
    final rawIds = (json['evidence_ids'] as List<dynamic>?) ?? [];
    final evidenceIds = rawIds.map((e) => e.toString()).toList();

    return AutopsyFinding(text: text, kind: kind, evidenceIds: evidenceIds);
  }
}
