// lib/core/taxonomy/taxonomy.dart
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One node in the canonical subcategory taxonomy — mirrors an entry of
/// `taxonomy/taxonomy.json`, the backend's single source of truth (also
/// served at `GET /api/taxonomy`, and the vocabulary every article's
/// `subcategories` array is tagged from).
///
/// Bundled into the app as `assets/taxonomy/taxonomy.json`, kept
/// byte-identical to the backend copy by `test/taxonomy_asset_parity_test.dart`
/// so the two never drift.
class TaxonomyNode {
  const TaxonomyNode({
    required this.slug,
    required this.displayName,
    required this.parent,
    required this.popular,
    required this.children,
  });

  /// L2 slug (e.g. `american_football`). L3 children are addressed as
  /// `<parent l2 slug>.<child slug>` (e.g. `football_soccer.transfers`).
  final String slug;
  final String displayName;

  /// Canonical parent category slug (`sports`, `tech`, …) — equal to
  /// `NewsCategory.name`.
  final String parent;
  final bool popular;
  final List<TaxonomyNode> children;
}

/// In-memory view of the canonical taxonomy. Load once with [ensureLoaded]
/// (idempotent, cheap) before reading [instance].
class Taxonomy {
  Taxonomy._(this._byCategory, this._displayBySlug);

  static const assetPath = 'assets/taxonomy/taxonomy.json';
  static Taxonomy? _instance;

  static Taxonomy get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('Taxonomy.ensureLoaded() must complete before Taxonomy.instance');
    }
    return i;
  }

  static bool get isLoaded => _instance != null;

  static Future<Taxonomy> ensureLoaded() async {
    final existing = _instance;
    if (existing != null) return existing;
    final parsed = parse(await rootBundle.loadString(assetPath));
    _instance = parsed;
    return parsed;
  }

  /// Visible for testing — parse a raw JSON string without the asset bundle.
  static Taxonomy parse(String rawJson) {
    final data = json.decode(rawJson) as Map<String, dynamic>;
    final byCategory = <String, List<TaxonomyNode>>{};
    final displayBySlug = <String, String>{};

    for (final entry in (data['categories'] as List)) {
      final node = entry as Map<String, dynamic>;
      final slug = node['slug'] as String;
      final parent = node['parent'] as String;

      final children = <TaxonomyNode>[];
      for (final c in (node['children'] as List? ?? const [])) {
        final child = c as Map<String, dynamic>;
        final fullSlug = '$slug.${child['slug']}';
        final childName = child['display_name'] as String;
        displayBySlug[fullSlug] = childName;
        children.add(TaxonomyNode(
          slug: fullSlug,
          displayName: childName,
          parent: parent,
          popular: false,
          children: const [],
        ));
      }

      displayBySlug[slug] = node['display_name'] as String;
      byCategory.putIfAbsent(parent, () => <TaxonomyNode>[]).add(TaxonomyNode(
            slug: slug,
            displayName: node['display_name'] as String,
            parent: parent,
            popular: node['popular'] as bool? ?? false,
            children: children,
          ));
    }

    return Taxonomy._(byCategory, displayBySlug);
  }

  final Map<String, List<TaxonomyNode>> _byCategory;
  final Map<String, String> _displayBySlug;

  /// L2 nodes whose canonical parent is [categorySlug] (`NewsCategory.name`),
  /// in taxonomy-file order. Cross-tagged nodes are filed only under their
  /// canonical parent — matches the backend `Taxonomy.to_api_payload`.
  List<TaxonomyNode> subcategoriesFor(String categorySlug) =>
      _byCategory[categorySlug] ?? const <TaxonomyNode>[];

  List<String> subcategorySlugsFor(String categorySlug) =>
      subcategoriesFor(categorySlug).map((n) => n.slug).toList();

  bool isValidSlug(String slug) => _displayBySlug.containsKey(slug);

  /// Human label for an L2 (`american_football`) or L3
  /// (`football_soccer.transfers`) slug; falls back to a title-cased
  /// rendering for anything not in the taxonomy.
  String displayNameForSlug(String slug) =>
      _displayBySlug[slug] ?? humanizeSlug(slug);

  static String humanizeSlug(String slug) {
    final leaf = slug.contains('.') ? slug.split('.').last : slug;
    const upper = {'ai', 'us', 'uk', 'eu', 'un', 'nba', 'nfl', 'tv', 'mlb'};
    return leaf
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => upper.contains(w)
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
