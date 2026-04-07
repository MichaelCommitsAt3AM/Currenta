import os
import sys
from backend.api import feed

def test_rank_tuple_ordering():
    # country_boost ASC, category_priority ASC, trending_tier ASC, major_source_tier ASC, ranking_score DESC
    
    # User pref: KE, Interests: [tech]
    pref_country = "KE"
    interests = ["tech"]
    
    # Case 1: Primary match (Country + Category)
    a1 = {"id": "a1", "country_code": "KE", "categories": ["tech"], "trend_score": 0, "is_major_source": False, "ranking_score": 0.5}
    # Case 2: Country match only
    a2 = {"id": "a2", "country_code": "KE", "categories": ["politics"], "trend_score": 0, "is_major_source": False, "ranking_score": 0.9}
    # Case 3: Category match only
    a3 = {"id": "a3", "country_code": "US", "categories": ["tech"], "trend_score": 0, "is_major_source": False, "ranking_score": 0.8}
    # Case 4: Trending mismatch
    a4 = {"id": "a4", "country_code": "US", "categories": ["politics"], "trend_score": 10, "is_major_source": False, "ranking_score": 0.1}
    # Case 5: Major source mismatch
    a5 = {"id": "a5", "country_code": "US", "categories": ["politics"], "trend_score": 0, "is_major_source": True, "ranking_score": 0.1}
    
    t1 = feed._get_rank_tuple(a1, pref_country, interests)
    t2 = feed._get_rank_tuple(a2, pref_country, interests)
    t3 = feed._get_rank_tuple(a3, pref_country, interests)
    t4 = feed._get_rank_tuple(a4, pref_country, interests)
    t5 = feed._get_rank_tuple(a5, pref_country, interests)
    
    # Expected order: a1 (0,0), a2 (0,1), a3 (1,0), a4 (1,1,0), a5 (1,1,1,0)
    # Tuple comparison: (0,0,1,1,-0.5) < (0,1,1,1,-0.9) < (1,0,1,1,-0.8) < (1,1,0,1,-0.1) < (1,1,1,0,-0.1)
    
    assert t1 < t2
    assert t2 < t3
    assert t3 < t4
    assert t4 < t5
    
    print("Ranking tuple tests passed!")

def test_global_sort_determinism():
    pref_country = "KE"
    interests = ["tech"]
    
    articles = [
        {"id": "low", "ranking_score": 0.1},
        {"id": "high", "ranking_score": 0.9},
        {"id": "major", "is_major_source": True, "ranking_score": 0.5},
    ]
    
    articles.sort(key=lambda x: feed._get_rank_tuple(x, pref_country, interests))
    
    # Expected: major (1,1,1,0,-0.5) < high (1,1,1,1,-0.9) < low (1,1,1,1,-0.1)
    # Wait, (1,1,1,0,-0.5) [major] vs (1,1,1,1,-0.9) [high]
    # Yes, 0 < 1, so major is first.
    # Between high and low: -0.9 < -0.1, so high is first.
    
    assert [a["id"] for a in articles] == ["major", "high", "low"]
    print("Global sort tests passed!")

if __name__ == "__main__":
    test_rank_tuple_ordering()
    test_global_sort_determinism()
