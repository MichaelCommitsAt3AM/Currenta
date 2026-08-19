from backend.services.taxonomy import get_taxonomy


def test_taxonomy_loads_and_has_no_duplicate_slugs():
    t = get_taxonomy()
    assert len(t.all_slugs) == len(set(t.all_slugs))
    assert len(t.all_slugs) > 50


def test_no_alias_is_ambiguous_within_overlapping_categories():
    """Guards against regressions like the original 'Climate Change' /
    'Urban Planning' bugs: two different slugs sharing an alias string must
    have disjoint category sets, or `match()` can't tell them apart using
    the article's assigned categories."""
    t = get_taxonomy()
    # Every match key that maps to more than
    # one slug must resolve unambiguously once a category is supplied for
    # every category each candidate slug claims.
    for normalized_key, slugs in t._match_index.items():
        unique_slugs = set(slugs)
        if len(unique_slugs) <= 1:
            continue
        category_sets = [t.slug_categories[s] for s in unique_slugs]
        for i in range(len(category_sets)):
            for j in range(i + 1, len(category_sets)):
                overlap = category_sets[i] & category_sets[j]
                assert not overlap, (
                    f"Alias {normalized_key!r} maps to {unique_slugs} whose "
                    f"category sets overlap on {overlap} - match() can't "
                    f"disambiguate these for an article in that category."
                )


def test_match_resolves_exact_slug():
    t = get_taxonomy()
    assert t.match("artificial_intelligence") == "artificial_intelligence"
    assert t.match("artificial_intelligence.ai_research") == "artificial_intelligence.ai_research"


def test_match_resolves_known_alias_case_insensitively():
    t = get_taxonomy()
    assert t.match("ai") == "artificial_intelligence"
    assert t.match("  Artificial Intelligence  ") == "artificial_intelligence"


def test_match_returns_none_for_unknown_string():
    t = get_taxonomy()
    assert t.match("Definitely Not A Real Subcategory") is None
    assert t.match("") is None
    assert t.match(None) is None


def test_match_uses_category_context_to_disambiguate():
    t = get_taxonomy()
    assert t.match("Wildlife", ["science"]) == "biology_genetics"
    assert t.match("Wildlife", ["environment"]) == "conservation_wildlife"


def test_match_strips_redundant_category_prefix():
    """The model sometimes prefixes an already-valid slug with its category
    name (e.g. mistaking the prompt's "- politics: slug_a, slug_b" display
    grouping for part of the value) — confirmed happening in production
    2026-08-19 once the response_schema enum stopped hard-blocking it."""
    t = get_taxonomy()
    assert t.match("politics.government_policy") == "government_policy"
    assert t.match("business.real_estate") == "real_estate"
    assert t.match("entertainment.theatre_arts") == "theatre_arts"
    # Also strips the prefix off an already-valid dotted L2.L3 child.
    assert t.match("tech.artificial_intelligence.ai_research") == "artificial_intelligence.ai_research"


def test_match_falls_back_to_l2_parent_for_hallucinated_child():
    t = get_taxonomy()
    assert t.match("football_soccer.core_football") == "football_soccer"
    assert t.match("sports.football_soccer") == "football_soccer"


def test_match_still_rejects_genuine_taxonomy_gaps():
    """A prefix-stripped or parent-fallback attempt must not paper over a
    string that truly isn't in the taxonomy at all."""
    t = get_taxonomy()
    assert t.match("entertainment.food_and_drink") is None
    assert t.match("not_a_category.not_a_slug") is None


def test_api_payload_shape_and_etag_stability():
    t = get_taxonomy()
    payload = t.to_api_payload()
    assert payload["version"] == t.version
    assert "tech" in payload["categories"]

    ai_node = next(n for n in payload["categories"]["tech"] if n["slug"] == "artificial_intelligence")
    assert ai_node["display_name"]
    assert isinstance(ai_node["popular"], bool)
    assert any(c["slug"] == "artificial_intelligence.ai_research" for c in ai_node["children"])

    # Each node is listed once, under its single canonical category — unlike
    # prompt_text(), which cross-lists nodes valid for multiple categories.
    assert not any(n["slug"] == "artificial_intelligence" for n in payload["categories"].get("science", []))

    assert t.etag == get_taxonomy().etag  # stable across calls (singleton + deterministic hash)


def test_prompt_text_lists_every_category():
    t = get_taxonomy()
    text = t.prompt_text()
    for category in ("politics", "tech", "science", "business", "sports",
                      "entertainment", "health", "world", "environment"):
        assert f"- {category}:" in text
