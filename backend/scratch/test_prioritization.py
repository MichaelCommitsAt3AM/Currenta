import asyncio
from uuid import UUID
from datetime import datetime

# Mock Diversifier
class Diversifier:
    def __init__(self, buckets, ratios, **kwargs):
        self.buckets = buckets
        self.ratios = ratios
    def interleave(self, limit):
        res = []
        for b in self.buckets:
            res.extend(b[:limit])
        return res

def test_split_logic():
    interests = ['tech', 'science']
    interest_set = set(interests)
    
    personalized_bucket = [
        {"id": "1", "categories": ["tech", "world"]},
        {"id": "2", "categories": ["entertainment", "tech"]},
        {"id": "3", "categories": ["science", "politics"]},
    ]
    
    all_ids = set()
    def process_bucket(bucket):
        primary = []
        secondary = []
        for a in bucket:
            if a['id'] not in all_ids:
                all_ids.add(a['id'])
                cats = a.get('categories') or []
                if cats and cats[0] in interest_set:
                    primary.append(a)
                else:
                    secondary.append(a)
        return primary, secondary

    p_primary, p_secondary = process_bucket(personalized_bucket)
    
    print(f"Primary: {[a['id'] for a in p_primary]}")
    print(f"Secondary: {[a['id'] for a in p_secondary]}")
    
    assert "1" in [a['id'] for a in p_primary]
    assert "3" in [a['id'] for a in p_primary]
    assert "2" in [a['id'] for a in p_secondary]
    print("Test passed!")

if __name__ == "__main__":
    test_split_logic()
