import unittest
from datetime import datetime
import re

# Mocking the constants and logic from the backend
SIMILARITY_THRESHOLD = 0.80

class TestNewsPrioritization(unittest.TestCase):
    def test_google_news_detection(self):
        # Logic from ingestion.py: is_major = "news.google.com" in feed_url
        urls = [
            ("https://news.google.com/rss?hl=en-US", True),
            ("https://techcrunch.com/feed/", False),
            ("https://news.google.com/headlines/section/topic/TECH", True),
            ("https://www.wired.com/feed/rss", False),
        ]
        for url, expected in urls:
            is_major = "news.google.com" in url
            self.assertEqual(is_major, expected, f"Failed for {url}")

    def test_sql_order_by_logic(self):
        # Logic from feed.py
        # ORDER BY {country_boost} ASC, {category_priority} ASC, {trending_tier} ASC, {major_source_tier} ASC, ranking_score DESC
        
        # Simulated data: (trend_score, is_major_source, ranking_score)
        # Goal: Lower tier value = higher priority (ASC)
        items = [
            {"id": "niche_old", "trend": 0, "major": False, "rank": 0.1},
            {"id": "niche_new", "trend": 0, "major": False, "rank": 0.5},
            {"id": "google_old", "trend": 0, "major": True, "rank": 0.2},
            {"id": "google_new", "trend": 0, "major": True, "rank": 0.6},
            {"id": "trending_niche", "trend": 5, "major": False, "rank": 0.8},
            {"id": "trending_google", "trend": 10, "major": True, "rank": 0.9},
        ]

        def sort_key(item):
            # We want ASC for tiers, DESC for ranking
            trending_tier = 0 if item["trend"] > 0 else 1
            major_tier = 0 if item["major"] else 1
            return (trending_tier, major_tier, -item["rank"])

        sorted_items = sorted(items, key=sort_key)
        
        # Expected Order:
        # 1. Trending Google (id: trending_google)
        # 2. Trending Niche (id: trending_niche)
        # 3. Google New (id: google_new)
        # 4. Google Old (id: google_old)
        # 5. Niche New (id: niche_new)
        # 6. Niche Old (id: niche_old)
        
        self.assertEqual(sorted_items[0]["id"], "trending_google")
        self.assertEqual(sorted_items[1]["id"], "trending_niche")
        self.assertEqual(sorted_items[2]["id"], "google_new")
        self.assertEqual(sorted_items[3]["id"], "google_old")
        self.assertEqual(sorted_items[4]["id"], "niche_new")
        self.assertEqual(sorted_items[5]["id"], "niche_old")

if __name__ == "__main__":
    unittest.main()
