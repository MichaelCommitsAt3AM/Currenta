"""Canonical subcategory taxonomy, loaded from taxonomy/taxonomy.json.

The taxonomy is a 2-tier tree (with a handful of 3rd-tier nodes on
high-volume topics). Every node exposes a stable `slug`; L3 nodes are
addressed as "<l2_slug>.<l3_slug>". This module builds the lookup
structures used to:
  - render the allowed-value list injected into the summarization prompt
  - validate/normalize whatever the LLM returns before it hits the DB
"""
from __future__ import annotations

import hashlib
import json
import logging
import os
import re
from typing import Dict, List, Optional, Set

logger = logging.getLogger(__name__)

_TAXONOMY_PATH = os.path.join(
    os.path.dirname(__file__), "..", "..", "taxonomy", "taxonomy.json"
)


def _normalize(s: str) -> str:
    s = s.lower().strip()
    s = re.sub(r"[^a-z0-9]+", " ", s)
    return " ".join(s.split())


class Taxonomy:
    def __init__(self, path: str = _TAXONOMY_PATH):
        with open(path, "rb") as f:
            raw_bytes = f.read()
        data = json.loads(raw_bytes)
        self.version = data.get("version", 1)
        self.etag = hashlib.sha256(raw_bytes).hexdigest()[:16]

        self.all_slugs: List[str] = []
        self.slug_display: Dict[str, str] = {}
        self.slug_categories: Dict[str, Set[str]] = {}
        self.slug_aliases: Dict[str, List[str]] = {}
        # normalized alias/slug string -> list of candidate full slugs
        self._match_index: Dict[str, List[str]] = {}
        # category -> ordered list of (slug, display_name, popular)
        self.by_category: Dict[str, List[dict]] = {}

        for node in data["categories"]:
            categories = {node["parent"], *node.get("additional_categories", [])}
            self._register(node["slug"], node["display_name"], categories,
                            node.get("aliases", []))
            self.by_category.setdefault(node["parent"], []).append({
                "slug": node["slug"],
                "display_name": node["display_name"],
                "popular": node.get("popular", False),
                "children": [
                    {"slug": f"{node['slug']}.{c['slug']}", "display_name": c["display_name"]}
                    for c in node.get("children", [])
                ],
            })
            for child in node.get("children", []):
                full_slug = f"{node['slug']}.{child['slug']}"
                self._register(full_slug, child["display_name"], categories,
                                child.get("aliases", []))

        self._category_names = {_normalize(c) for c in self.by_category}

    def _register(self, slug: str, display_name: str, categories: Set[str],
                  aliases: List[str]) -> None:
        self.all_slugs.append(slug)
        self.slug_display[slug] = display_name
        self.slug_categories[slug] = categories
        self.slug_aliases[slug] = list(aliases)
        self._match_index.setdefault(_normalize(slug), []).append(slug)
        self._match_index.setdefault(_normalize(display_name), []).append(slug)
        for alias in aliases:
            self._match_index.setdefault(_normalize(alias), []).append(slug)

    def prompt_text(self) -> str:
        """Compact, category-grouped listing of every valid slug for the prompt.

        Unlike `by_category` (which files each node under its single
        canonical/display category), this lists a node under every
        category it's valid for — e.g. a climate node whose canonical
        home is 'environment' but that's also valid for 'science'
        articles appears in both lines, since the model picks the
        subcategory only after it has already picked categories.
        """
        by_cat: Dict[str, List[str]] = {}
        for slug, cats in self.slug_categories.items():
            for c in cats:
                by_cat.setdefault(c, []).append(slug)
        lines = [f"- {c}: {', '.join(sorted(slugs))}" for c, slugs in sorted(by_cat.items())]
        return "\n".join(lines)

    def match(self, raw: str, categories: Optional[List[str]] = None) -> Optional[str]:
        """Resolve a raw LLM subcategory string to a canonical slug.

        Prefers an exact slug/alias match; when the alias is ambiguous
        (maps to multiple slugs, e.g. "Climate Change" under both science
        and environment) prefers whichever candidate overlaps the
        article's assigned categories.

        Falls back to two defensive normalizations for the model's most
        common formatting slips (confirmed in production 2026-08-19, without
        a response_schema enum backstopping this field): (1) a redundant
        "<category>." prefix on an otherwise-valid slug, e.g.
        "politics.government_policy" instead of "government_policy" — likely
        the model pattern-matching the prompt's "- category: slug, slug"
        display grouping into the value itself; (2) a hallucinated L3 child
        under a real L2 slug, e.g. "football_soccer.core_football" — falls
        back to the valid L2 parent.
        """
        if not raw:
            return None

        candidates = self._match_index.get(_normalize(raw))
        if candidates:
            return self._pick(candidates, categories)

        if "." in raw:
            first, _, rest = raw.partition(".")
            if _normalize(first) in self._category_names and rest:
                candidates = self._match_index.get(_normalize(rest))
                if candidates:
                    return self._pick(candidates, categories)

            parent, _, _child = raw.rpartition(".")
            if parent:
                candidates = self._match_index.get(_normalize(parent))
                if candidates:
                    return self._pick(candidates, categories)

        return None

    def _pick(self, candidates: List[str], categories: Optional[List[str]]) -> str:
        if len(candidates) == 1 or not categories:
            return candidates[0]
        cat_set = set(categories)
        for slug in candidates:
            if self.slug_categories.get(slug, set()) & cat_set:
                return slug
        return candidates[0]

    def is_valid(self, slug: str) -> bool:
        return slug in self.slug_display

    def label_text(self, slug: str) -> str:
        """Display name + aliases as one string — an embedding target richer
        than the slug/display name alone, for fuzzy-matching raw LLM output
        that doesn't hit the alias map (see scripts/backfill_subcategories.py)."""
        display = self.slug_display.get(slug, slug)
        aliases = self.slug_aliases.get(slug, [])
        return f"{display}: {', '.join(aliases)}" if aliases else display

    def to_api_payload(self) -> dict:
        """Client-facing shape for GET /api/taxonomy: each node listed once,
        under its single canonical/display category (unlike `prompt_text`,
        which lists cross-tagged nodes under every valid category)."""
        return {
            "version": self.version,
            "categories": self.by_category,
        }


_taxonomy: Optional[Taxonomy] = None


def get_taxonomy() -> Taxonomy:
    global _taxonomy
    if _taxonomy is None:
        _taxonomy = Taxonomy()
    return _taxonomy
