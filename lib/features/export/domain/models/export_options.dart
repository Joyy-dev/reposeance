/// Configuration options for generating and saving a Markdown autopsy report.
class ExportOptions {
  /// Whether to include Ask the Ghost Q&A inquiries in the exported Markdown.
  final bool includeGhostQa;

  /// Optional custom title override for the report.
  final String? customTitle;

  const ExportOptions({this.includeGhostQa = true, this.customTitle});

  ExportOptions copyWith({bool? includeGhostQa, String? customTitle}) {
    return ExportOptions(
      includeGhostQa: includeGhostQa ?? this.includeGhostQa,
      customTitle: customTitle ?? this.customTitle,
    );
  }
}
