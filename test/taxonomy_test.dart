// test/taxonomy_test.dart
import 'dart:io';

import 'package:currenta/core/taxonomy/taxonomy.dart';
import 'package:currenta/features/news/domain/entities/news_category.dart';
import 'package:currenta/features/news/domain/subcategory_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

Taxonomy _loadTaxonomy() =>
    Taxonomy.parse(File('assets/taxonomy/taxonomy.json').readAsStringSync());

void main() {
  final taxonomy = _loadTaxonomy();

  group('Taxonomy', () {
    test('files subcategories under their canonical parent (NewsCategory.name)',
        () {
      final sports = taxonomy.subcategorySlugsFor('sports');
      expect(sports, contains('american_football'));
      expect(sports, contains('football_soccer'));
      expect(sports, contains('baseball'));
      // AI is parent=tech even though it is additionally valid for science.
      expect(taxonomy.subcategorySlugsFor('science'),
          isNot(contains('artificial_intelligence')));
    });

    test('every NewsCategory (except local) has taxonomy subcategories', () {
      for (final cat in NewsCategory.values) {
        if (cat == NewsCategory.local) continue;
        expect(taxonomy.subcategoriesFor(cat.name), isNotEmpty,
            reason: 'no subcategories for ${cat.name}');
      }
    });

    test('displayNameForSlug resolves L2 and L3, falls back for unknown', () {
      expect(taxonomy.displayNameForSlug('american_football'),
          'American Football');
      expect(taxonomy.displayNameForSlug('football_soccer.transfers'),
          'Transfers');
      expect(taxonomy.displayNameForSlug('not_a_real_slug'), 'Not A Real Slug');
    });
  });

  group('SubcategoryPreferences', () {
    final sportsSlugs = taxonomy.subcategorySlugsFor('sports').toSet();

    test('deselecting one subcategory of an enabled category mutes exactly it',
        () {
      final selected = sportsSlugs.difference({'american_football'});
      final muted = SubcategoryPreferences.mutedL2(
        taxonomy: taxonomy,
        enabledCategories: {NewsCategory.sports},
        selectedSlugs: selected,
      );
      expect(muted, {'american_football'});
    });

    test('all selected → nothing muted, nothing boosted', () {
      expect(
        SubcategoryPreferences.mutedL2(
          taxonomy: taxonomy,
          enabledCategories: {NewsCategory.sports},
          selectedSlugs: sportsSlugs,
        ),
        isEmpty,
      );
      expect(
        SubcategoryPreferences.boostSlugs(
          taxonomy: taxonomy,
          enabledCategories: {NewsCategory.sports},
          selectedSlugs: sportsSlugs,
        ),
        isEmpty,
      );
    });

    test('a strict subset is sent as a boost', () {
      final selected = {'american_football', 'basketball'};
      expect(
        SubcategoryPreferences.boostSlugs(
          taxonomy: taxonomy,
          enabledCategories: {NewsCategory.sports},
          selectedSlugs: selected,
        ),
        {'american_football', 'basketball'},
      );
    });

    test('disabled categories contribute no mutes', () {
      final muted = SubcategoryPreferences.mutedL2(
        taxonomy: taxonomy,
        enabledCategories: {NewsCategory.sports},
        selectedSlugs: const {}, // nothing selected anywhere
      );
      // only sports slugs, never e.g. tech/business slugs
      expect(muted, sportsSlugs);
    });
  });
}
