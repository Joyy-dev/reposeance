import 'autopsy_finding.dart';

/// A prioritized action step in the maintainer revival plan backed by an evidence-grounded reason.
class RevivalStep {
  final String step;
  final AutopsyFinding reason;

  const RevivalStep({required this.step, required this.reason});

  Map<String, dynamic> toJson() => {'step': step, 'reason': reason.toJson()};

  factory RevivalStep.fromJson(Map<String, dynamic> json) {
    return RevivalStep(
      step: json['step'] as String,
      reason: AutopsyFinding.fromJson(json['reason'] as Map<String, dynamic>),
    );
  }
}
