import os
import sys
import types

# Ensure backend security module import does not fail in test-only execution.
os.environ.setdefault("ADMIN_API_KEY", "test-key")

# Provide a tiny geoip2 stub so feed import works in environments
# where optional geo lookup dependencies are not installed.
if "geoip2" not in sys.modules:
    geoip2_module = types.ModuleType("geoip2")
    geoip2_database_module = types.ModuleType("geoip2.database")

    class _DummyReader:
        def __init__(self, *args, **kwargs):
            pass

    geoip2_database_module.Reader = _DummyReader
    geoip2_module.database = geoip2_database_module
    sys.modules["geoip2"] = geoip2_module
    sys.modules["geoip2.database"] = geoip2_database_module

from backend.api import feed


SOCIAL_MEDIA_VERDICT_SUMMARIES = [
    "A California jury awarded $3 million in damages to a young plaintiff who alleged social media platforms harmed her childhood. Meta and Alphabet were found liable, with TikTok and Snapchat settling prior to trial. This verdict questions the effectiveness of Section 230 in shielding tech companies from liability. The ruling may embolden lawmakers and lead to further lawsuits against social media giants.",
    "A Los Angeles jury found Meta and YouTube negligent for failing to warn users about platform dangers, awarding $6 million in damages. The plaintiff alleged childhood addiction to apps like Instagram and YouTube caused severe mental health issues. This verdict, comparing the case to the tobacco industry's \"Big Tobacco\" moment, could significantly impact social media companies' legal standing.",
    "A Los Angeles jury found Meta and Google liable for harming a young woman through addictive app design, awarding her $3 million in damages. The lawsuit alleged that the companies' social media platforms deliberately addict and harm children. Jurors determined the companies failed to adequately warn users about product dangers. Meta and Google plan to appeal the verdict, citing disagreement with the findings.",
    "A California jury found Meta and YouTube liable for negligence, awarding $3 million in damages to a young woman whose mental health suffered due to addictive platform designs. This landmark verdict, one of the first of its kind, could signal significant changes for social media companies. Thousands of similar lawsuits are pending nationwide, with some already resulting in substantial penalties.",
    "A Los Angeles jury found Meta and YouTube negligent in a social media addiction case, ordering them to pay $6 million in damages. The lawsuit, brought by a young woman, alleged harm from addictive platform features during her childhood. Meta will pay 70 percent of compensatory damages, with YouTube covering the rest, plus punitive damages. This verdict marks a significant legal precedent for similar cases against tech companies",
]


def test_token_jaccard_similarity_detects_near_duplicate_articles():
    article_a = {
        "title": "LA Jury Rules Against Social Platforms in Addiction Harm Case",
        "summary": SOCIAL_MEDIA_VERDICT_SUMMARIES[1],
        "original_url": "https://source-b.example.com/meta-youtube-addiction-trial",
    }
    article_b = {
        "title": "LA Jury Rules Against Social Platforms in Addiction Harm Case",
        "summary": SOCIAL_MEDIA_VERDICT_SUMMARIES[2],
        "original_url": "https://source-c.example.com/meta-google-addictive-design-verdict",
    }

    tokens_a = feed._article_tokens(article_a)
    tokens_b = feed._article_tokens(article_b)

    assert len(tokens_a & tokens_b) >= 4
    assert feed._token_jaccard_similarity(tokens_a, tokens_b) >= 0.30


def test_collapse_near_duplicate_articles_keeps_highest_ranked_item():
    articles = [
        {
            "id": "a1",
            "title": "California Jury Awards Damages in Social Media Case",
            "summary": SOCIAL_MEDIA_VERDICT_SUMMARIES[0],
            "original_url": "https://source-a.example.com/social-media-harm-case",
            "source_name": "Source A",
            "ranking_score": 3.0,
        },
        {
            "id": "a2",
            "title": "LA Jury Rules Against Social Platforms in Addiction Harm Case",
            "summary": SOCIAL_MEDIA_VERDICT_SUMMARIES[1],
            "original_url": "https://source-b.example.com/meta-youtube-addiction-trial",
            "source_name": "Source B",
            "ranking_score": 2.8,
        },
        {
            "id": "a3",
            "title": "LA Jury Rules Against Social Platforms in Addiction Harm Case",
            "summary": SOCIAL_MEDIA_VERDICT_SUMMARIES[2],
            "original_url": "https://source-c.example.com/meta-google-addictive-design-verdict",
            "source_name": "Source C",
            "ranking_score": 2.6,
        },
        {
            "id": "a4",
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
    assert "a2" in kept_ids
    assert "a3" not in kept_ids
    assert "a4" in kept_ids
    assert len(kept_ids) == 3


def test_collapse_near_duplicate_articles_works_even_with_different_headlines_and_urls():
    canonical = {
        "id": "lead",
        "title": "LA Jury Rules Against Social Platforms in Addiction Harm Case",
        "summary": SOCIAL_MEDIA_VERDICT_SUMMARIES[1],
        "original_url": "https://source-b.example.com/meta-youtube-addiction-trial",
        "ranking_score": 10.0,
    }
    variant = {
        "id": "variant",
        "title": "LA Jury Rules Against Social Platforms in Addiction Harm Case",
        "summary": SOCIAL_MEDIA_VERDICT_SUMMARIES[2],
        "original_url": "https://source-c.example.com/meta-google-addictive-design-verdict",
        "ranking_score": 9.0,
    }

    kept = feed._collapse_near_duplicate_articles([canonical, variant])
    kept_ids = [article["id"] for article in kept]
    assert kept_ids == ["lead"]
