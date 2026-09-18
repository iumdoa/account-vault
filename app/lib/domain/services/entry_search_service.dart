import '../models/vault_entry.dart';

/// Pure, stateless search service for vault entries.
///
/// Rules (README Section 4.2):
/// 1. Searches title, address, username, group, tags, notes (NEVER searches password).
/// 2. Case-insensitive for ASCII, substring match for Chinese, fragment match for IP/domain.
/// 3. Trims query, splits by whitespace into terms; all terms must match at least one searchable field.
/// 4. Scoring: exact title/address match first, followed by prefix matches, then substring matches.
///    Tie-breaker: updatedAt descending (newer first), then stable id lexicographical order.
/// 5. Empty query returns all entries with stable order.
class EntrySearchService {
  /// Pure function that performs search and ranking
  static List<VaultEntry> search(List<VaultEntry> entries, String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      // Empty query: return all entries sorted by updatedAt desc, tie-break id asc
      final sorted = List<VaultEntry>.from(entries);
      sorted.sort(_stableComparator);
      return sorted;
    }

    final queryLower = cleanQuery.toLowerCase();
    final terms = queryLower
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();

    if (terms.isEmpty) {
      final sorted = List<VaultEntry>.from(entries);
      sorted.sort(_stableComparator);
      return sorted;
    }

    final matchedWithScore = <({VaultEntry entry, int score})>[];

    for (final entry in entries) {
      final titleLower = entry.title.toLowerCase();
      final addressLower = (entry.address ?? '').toLowerCase();
      final usernameLower = (entry.username ?? '').toLowerCase();
      final groupLower = (entry.group ?? '').toLowerCase();
      final tagsLower = entry.tags.map((t) => t.toLowerCase()).toList();
      final notesLower = (entry.notes ?? '').toLowerCase();

      // Check if ALL terms match at least one searchable field
      var allTermsMatched = true;
      for (final term in terms) {
        final matchesThisTerm =
            titleLower.contains(term) ||
            addressLower.contains(term) ||
            usernameLower.contains(term) ||
            groupLower.contains(term) ||
            tagsLower.any((tag) => tag.contains(term)) ||
            notesLower.contains(term);

        if (!matchesThisTerm) {
          allTermsMatched = false;
          break;
        }
      }

      if (!allTermsMatched) {
        continue;
      }

      // Calculate relevance score
      var score = 0;

      // Exact matches for whole query
      if (titleLower == queryLower) {
        score += 1000;
      } else if (titleLower.startsWith(queryLower)) {
        score += 500;
      }

      if (addressLower == queryLower) {
        score += 800;
      } else if (addressLower.startsWith(queryLower)) {
        score += 400;
      }

      if (usernameLower == queryLower) {
        score += 600;
      } else if (usernameLower.startsWith(queryLower)) {
        score += 300;
      }

      // Term-level match scoring
      for (final term in terms) {
        if (titleLower == term) {
          score += 120;
        } else if (titleLower.startsWith(term)) {
          score += 60;
        } else if (titleLower.contains(term)) {
          score += 30;
        }

        if (addressLower == term) {
          score += 100;
        } else if (addressLower.startsWith(term)) {
          score += 50;
        } else if (addressLower.contains(term)) {
          score += 25;
        }

        if (usernameLower == term) {
          score += 80;
        } else if (usernameLower.startsWith(term)) {
          score += 40;
        } else if (usernameLower.contains(term)) {
          score += 20;
        }

        if (groupLower.contains(term)) {
          score += 15;
        }

        if (tagsLower.any((tag) => tag == term)) {
          score += 25;
        } else if (tagsLower.any((tag) => tag.contains(term))) {
          score += 10;
        }

        if (notesLower.contains(term)) {
          score += 5;
        }
      }

      matchedWithScore.add((entry: entry, score: score));
    }

    // Sort by score descending, tie-break by stable comparator
    matchedWithScore.sort((a, b) {
      final scoreDiff = b.score.compareTo(a.score);
      if (scoreDiff != 0) {
        return scoreDiff;
      }
      return _stableComparator(a.entry, b.entry);
    });

    return matchedWithScore.map((item) => item.entry).toList();
  }

  /// Stable comparator: updatedAt descending (newer first), then id ascending
  static int _stableComparator(VaultEntry a, VaultEntry b) {
    final dateComp = b.updatedAt.compareTo(a.updatedAt);
    if (dateComp != 0) {
      return dateComp;
    }
    return a.id.compareTo(b.id);
  }
}
