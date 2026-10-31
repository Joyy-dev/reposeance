/// Typed commit subject representation extracted safely from git log.
class GitCommit {
  final String hash;
  final String author;
  final DateTime date;
  final String subject;

  const GitCommit({
    required this.hash,
    required this.author,
    required this.date,
    required this.subject,
  });

  String get shortHash => hash.length >= 7 ? hash.substring(0, 7) : hash;

  Map<String, dynamic> toJson() {
    return {
      'hash': hash,
      'short_hash': shortHash,
      'author': author,
      'date': date.toIso8601String(),
      'subject': subject,
    };
  }

  @override
  String toString() =>
      '[$shortHash] $subject ($author, ${date.toIso8601String()})';
}
