import 'package:reposeance/features/autopsy/domain/models/evidence_item.dart';
import 'package:reposeance/features/autopsy/domain/models/evidence_snapshot.dart';

/// Scored evidence result from deterministic lexical retrieval.
class ScoredEvidence {
  final EvidenceItem item;
  final double score;
  final Set<String> matchedTokens;

  const ScoredEvidence({
    required this.item,
    required this.score,
    required this.matchedTokens,
  });
}

/// Deterministic, pure Dart identifier- and path-aware lexical retrieval engine.
/// Strictly bounded to the active in-memory EvidenceSnapshot. Zero vector DBs.
class LexicalRetrievalEngine {
  static const Set<String> _stopWords = {
    'a',
    'an',
    'the',
    'and',
    'or',
    'but',
    'in',
    'on',
    'at',
    'to',
    'for',
    'of',
    'with',
    'by',
    'from',
    'up',
    'about',
    'into',
    'over',
    'after',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'shall',
    'should',
    'can',
    'could',
    'may',
    'might',
    'must',
    'it',
    'its',
    'this',
    'that',
    'these',
    'those',
    'i',
    'you',
    'he',
    'she',
    'we',
    'they',
    'what',
    'which',
    'who',
    'whom',
    'where',
    'when',
    'why',
    'how',
    'all',
    'any',
    'both',
    'each',
    'few',
    'more',
    'most',
    'other',
    'some',
    'such',
    'no',
    'nor',
    'not',
    'only',
    'own',
    'same',
    'so',
    'than',
    'too',
    'very',
    's',
    't',
    'just',
    'don',
    'now',
    'there',
    'their',
    'project',
    'code',
    'repository',
    'repo',
  };

  static const Map<String, List<String>> _abbreviationSynonyms = {
    'auth': ['authentication', 'authorise', 'authorize', 'auth'],
    'authentication': ['auth'],
    'db': ['database', 'sqlite', 'store', 'db'],
    'database': ['db', 'sqlite', 'store'],
    'config': ['configuration', 'config', 'settings'],
    'configuration': ['config'],
    'repo': ['repository', 'repo'],
    'repository': ['repo'],
    'doc': ['documentation', 'docs', 'readme'],
    'docs': ['documentation', 'doc', 'readme'],
    'impl': ['implementation', 'impl'],
    'implementation': ['impl'],
    'test': ['testing', 'tests', 'test'],
    'tests': ['testing', 'test'],
    'util': ['utility', 'utils', 'helper'],
    'utils': ['utility', 'util', 'helper'],
    'ui': ['interface', 'presentation', 'widget', 'view', 'screen'],
    'nav': ['navigation', 'navigator', 'routing'],
    'msg': ['message', 'messages'],
  };

  /// Tokenizes a string with camelCase splitting, separator splitting, and stop-word filtering.
  static List<String> tokenize(String input) {
    if (input.trim().isEmpty) return const [];

    // 1. Split camelCase (e.g. "sqliteDatabase" -> "sqlite Database")
    final camelCaseSplit = input.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    // 2. Replace non-alphanumeric separators (slashes, dots, dashes, underscores) with space
    final normalized = camelCaseSplit.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ');

    // 3. Lowercase, split, filter stop words and short tokens (< 2 chars)
    final tokens = <String>[];
    for (final raw in normalized.toLowerCase().split(RegExp(r'\s+'))) {
      final token = raw.trim();
      if (token.length >= 2 && !_stopWords.contains(token)) {
        tokens.add(token);
      }
    }
    return tokens;
  }

  /// Retrieves the top-k most relevant evidence items from the snapshot for the given query.
  /// If no items score >= [minScore], returns an empty list, signalling a zero-evidence short-circuit.
  static List<ScoredEvidence> retrieve({
    required EvidenceSnapshot snapshot,
    required String query,
    int topK = 4,
    double minScore = 1.0,
  }) {
    final rawQueryTokens = tokenize(query);
    if (rawQueryTokens.isEmpty) {
      return const [];
    }

    // Expand query tokens with common domain synonyms/abbreviations
    final queryTokens = <String>{...rawQueryTokens};
    for (final token in rawQueryTokens) {
      final syns = _abbreviationSynonyms[token];
      if (syns != null) {
        queryTokens.addAll(syns);
      }
    }

    final List<ScoredEvidence> scoredList = [];

    for (final item in snapshot.evidenceMap.values) {
      double score = 0.0;
      final matchedTokens = <String>{};

      if (item is FileEvidence) {
        // 1. Path segment matching (high priority, weight 3.0)
        final pathTokens = tokenize(item.repositoryRelativePath).toSet();
        for (final qToken in queryTokens) {
          if (pathTokens.contains(qToken)) {
            score += 3.0;
            matchedTokens.add(qToken);
          } else if (item.repositoryRelativePath.toLowerCase().contains(
            qToken,
          )) {
            score += 1.5;
            matchedTokens.add(qToken);
          } else {
            // Stem / Prefix match (e.g. 'auth' and 'authenticate')
            for (final pToken in pathTokens) {
              if (qToken.length >= 4 && pToken.length >= 4) {
                if (qToken.startsWith(pToken) || pToken.startsWith(qToken)) {
                  score += 2.0;
                  matchedTokens.add(qToken);
                  break;
                }
              }
            }
          }
        }

        // 2. Content token matching (weight 1.0, symbols 2.0)
        final contentLower = item.content.toLowerCase();
        for (final qToken in queryTokens) {
          if (contentLower.contains(qToken)) {
            matchedTokens.add(qToken);

            // Count occurrences (capped at 5 to prevent single-token bias)
            final occurrences = _countOccurrences(
              contentLower,
              qToken,
              maxCount: 5,
            );
            score += occurrences * 1.0;

            // Check if token appears as a code symbol / identifier
            if (_isCodeSymbol(contentLower, qToken)) {
              score += 2.0;
            }
          }
        }
      } else if (item is CommitEvidence) {
        // Commit subject matching (weight 2.0)
        final subjectTokens = tokenize(item.subject).toSet();
        for (final qToken in queryTokens) {
          if (subjectTokens.contains(qToken)) {
            score += 2.0;
            matchedTokens.add(qToken);
          } else if (item.subject.toLowerCase().contains(qToken)) {
            score += 1.0;
            matchedTokens.add(qToken);
          } else {
            for (final sToken in subjectTokens) {
              if (qToken.length >= 4 && sToken.length >= 4) {
                if (qToken.startsWith(sToken) || sToken.startsWith(qToken)) {
                  score += 1.5;
                  matchedTokens.add(qToken);
                  break;
                }
              }
            }
          }
        }

        if (item.author != null) {
          final authorLower = item.author!.toLowerCase();
          for (final qToken in queryTokens) {
            if (authorLower.contains(qToken)) {
              score += 1.5;
              matchedTokens.add(qToken);
            }
          }
        }
      }

      if (score >= minScore && matchedTokens.isNotEmpty) {
        scoredList.add(
          ScoredEvidence(
            item: item,
            score: score,
            matchedTokens: matchedTokens,
          ),
        );
      }
    }

    // Deterministic sorting: highest score first, tie-break on evidence ID ascending
    scoredList.sort((a, b) {
      final scoreComparison = b.score.compareTo(a.score);
      if (scoreComparison != 0) return scoreComparison;
      return a.item.id.compareTo(b.item.id);
    });

    if (scoredList.length > topK) {
      return scoredList.sublist(0, topK);
    }
    return scoredList;
  }

  static int _countOccurrences(String text, String sub, {int maxCount = 5}) {
    int count = 0;
    int index = 0;
    while ((index = text.indexOf(sub, index)) != -1) {
      count++;
      if (count >= maxCount) break;
      index += sub.length;
    }
    return count;
  }

  static bool _isCodeSymbol(String content, String token) {
    // Looks for patterns like "class Token", "def token", "function token", "token(", "token."
    final symbolPatterns = [
      'class $token',
      'enum $token',
      '$token(',
      '$token.',
      'import \'$token',
      'package:$token',
    ];
    for (final pattern in symbolPatterns) {
      if (content.contains(pattern)) return true;
    }
    return false;
  }
}
