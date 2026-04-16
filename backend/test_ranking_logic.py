import os
import sys
from backend.api import feed

def test_diversifier_interleaving():
    # Bucket 1: Tech (Interest)
    b1 = [
        {"id": "t1", "categories": ["tech"], "source_name": "TechCrunch", "ranking_score": 0.9},
        {"id": "t2", "categories": ["tech"], "source_name": "TechCrunch", "ranking_score": 0.8},
        {"id": "t3", "categories": ["tech"], "source_name": "Verge", "ranking_score": 0.7},
        {"id": "t4", "categories": ["tech"], "source_name": "Verge", "ranking_score": 0.6},
    ]
    # Bucket 2: Politics (Local)
    b2 = [
        {"id": "p1", "categories": ["politics"], "source_name": "BBC", "ranking_score": 0.95},
        {"id": "p2", "categories": ["politics"], "source_name": "BBC", "ranking_score": 0.85},
        {"id": "p3", "categories": ["politics"], "source_name": "Reuters", "ranking_score": 0.75},
    ]
    # Bucket 3: Science (World)
    b3 = [
        {"id": "s1", "categories": ["science"], "source_name": "Nature", "ranking_score": 0.88},
    ]

    diversifier = feed.Diversifier(
        buckets=[b1, b2, b3],
        ratios=[0.33, 0.33, 0.33],
        max_consecutive_cat=2, # Stricter for testing
        max_consecutive_source=2
    )
    
    result = diversifier.interleave(limit=10)
    
    ids = [a["id"] for a in result]
    # Round-robin expected: b1[0], b2[0], b3[0], b1[1], b2[1], b3[empty]...
    # p1, t1, s1, p2, t2, p3, t3...
    print(f"Interleaved IDs: {ids}")
    
    assert "t1" in ids
    assert "p1" in ids
    assert "s1" in ids
    
    # Check source guard (max 2)
    sources = [a["source_name"] for a in result]
    for i in range(len(sources)-2):
        assert not (sources[i] == sources[i+1] == sources[i+2])

    print("Diversifier interleaving tests passed!")

def test_rank_tuple_ordering():
    # Internal bucket ranking is now just ranking_score DESC
    a1 = {"ranking_score": 0.5}
    a2 = {"ranking_score": 0.9}
    
    t1 = feed._get_rank_tuple(a1, None, [])
    t2 = feed._get_rank_tuple(a2, None, [])
    
    # t1=(-0.5,), t2=(-0.9,)
    assert t2 < t1 # Correct DESC sort
    print("Ranking tuple tests passed!")

if __name__ == "__main__":
    test_diversifier_interleaving()
    test_rank_tuple_ordering()
