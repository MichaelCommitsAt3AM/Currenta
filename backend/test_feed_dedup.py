from backend.api import feed


def test_token_jaccard_similarity_detects_near_duplicate_articles():
    article_a = {
        "title": "Elon Musk Found Liable for Misleading Twitter Investors",
        "summary": "A California jury found Elon Musk intentionally misled investors regarding his Twitter acquisition.",
        "original_url": "https://techcrunch.com/2026/03/20/elon-musk-misled-twitter-investors-while-trying-to-get-out-of-acquisition-jury-says/",
    }
    article_b = {
        "title": "Jury Finds Elon Musk Misled Investors Before Twitter Acquisition",
        "summary": "A California jury ruled Elon Musk misled investors before his $44 billion Twitter purchase.",
        "original_url": "https://www.theverge.com/tech/898511/elon-musk-twitter-lawsuit",
    }

    tokens_a = feed._article_tokens(article_a)
    tokens_b = feed._article_tokens(article_b)

    assert len(tokens_a & tokens_b) >= 4
    assert feed._token_jaccard_similarity(tokens_a, tokens_b) >= 0.30


def test_collapse_near_duplicate_articles_keeps_highest_ranked_item():
    articles = [
        {
            "id": "a1",
            "title": "Elon Musk Found Liable for Misleading Twitter Investors",
            "summary": "A California jury found Elon Musk intentionally misled investors.",
            "original_url": "https://techcrunch.com/2026/03/20/elon-musk-misled-twitter-investors-while-trying-to-get-out-of-acquisition-jury-says/",
            "source_name": "TechCrunch",
            "ranking_score": 2.3,
        },
        {
            "id": "a2",
            "title": "Jury Finds Elon Musk Misled Investors Before Twitter Acquisition",
            "summary": "A California jury ruled Elon Musk misled investors before his $44 billion Twitter purchase.",
            "original_url": "https://www.theverge.com/tech/898511/elon-musk-twitter-lawsuit",
            "source_name": "The Verge",
            "ranking_score": 2.1,
        },
        {
            "id": "a3",
            "title": "NASA Releases New Webb Telescope Deep Field Image",
            "summary": "NASA published a new deep-field image from the James Webb Space Telescope.",
            "original_url": "https://www.nasa.gov/news/new-webb-image/",
            "source_name": "NASA",
            "ranking_score": 1.9,
        },
    ]

    kept = feed._collapse_near_duplicate_articles(articles)

    kept_ids = [a["id"] for a in kept]
    assert "a1" in kept_ids
    assert "a2" not in kept_ids
    assert "a3" in kept_ids
    assert len(kept_ids) == 2
