// lib/features/news/domain/subcategory_preferences.dart
import '../../../core/taxonomy/taxonomy.dart';
import 'entities/news_category.dart';

/// Pure translation of the Personalization screen's selection state into the
/// rows written to `user_muted_subcategories` (hard feed filter) and
/// `user_sub_interests` (soft ranking boost).
class SubcategoryPreferences {
  const SubcategoryPreferences._();

  /// L2 slugs to hard-mute: every subcategory of an *enabled* category the
  /// user has de-selected. Disabled categories contribute nothing — their
  /// exclusion is handled backend-side by the interest-category filter.
  static Set<String> mutedL2({
    required Taxonomy taxonomy,
    required Set<NewsCategory> enabledCategories,
    required Set<String> selectedSlugs,
  }) {
    final muted = <String>{};
    for (final cat in enabledCategories) {
      if (cat == NewsCategory.local) continue;
      for (final slug in taxonomy.subcategorySlugsFor(cat.name)) {
        if (!selectedSlugs.contains(slug)) muted.add(slug);
      }
    }
    return muted;
  }

  /// Selected L2 slugs worth sending as a ranking boost: only where the user
  /// kept a *strict subset* of a category's subcategories. "All on" carries no
  /// relative signal, so it is left out to keep `user_sub_interests` lean.
  static Set<String> boostSlugs({
    required Taxonomy taxonomy,
    required Set<NewsCategory> enabledCategories,
    required Set<String> selectedSlugs,
  }) {
    final boost = <String>{};
    for (final cat in enabledCategories) {
      if (cat == NewsCategory.local) continue;
      final all = taxonomy.subcategorySlugsFor(cat.name);
      if (all.isEmpty) continue;
      final selected = all.where(selectedSlugs.contains).toList();
      if (selected.isNotEmpty && selected.length < all.length) {
        boost.addAll(selected);
      }
    }
    return boost;
  }
}
