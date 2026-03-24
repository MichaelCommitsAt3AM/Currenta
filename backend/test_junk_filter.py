from backend.services.ingestion import is_junk_content, is_junk_url


def test_prediction_without_betting_context_is_not_junk():
    title = "Oil is predicted to fall next week after inventory builds"
    text = "Analysts forecast weaker demand and larger reserves, with Brent expected to soften if OPEC supply remains stable."
    assert is_junk_content(text, title) is None


def test_forecast_without_betting_context_is_not_junk():
    title = "Economic forecast points to slower growth in Q3"
    text = "Central bank officials said inflation remains sticky while manufacturing output contracts for a third straight month."
    assert is_junk_content(text, title) is None


def test_betting_tips_content_is_junk():
    title = "NBA betting tips: point spread and moneyline picks tonight"
    text = "Our expert picks target the best game odds and over/under value across three playoff matchups."
    reason = is_junk_content(text, title)
    assert reason is not None


def test_promo_bonus_bets_content_is_junk():
    title = "Best sportsbook promo code this weekend"
    text = "Claim your welcome bonus bets and first deposit offer with this coupon code before kickoff."
    reason = is_junk_content(text, title)
    assert reason is not None


def test_affiliate_disclosure_only_is_not_junk():
    title = "Apple to expand satellite features in next iOS release"
    text = (
        "Apple is expected to expand emergency communication features globally. "
        "This article includes independent reporting and analysis. "
        "We may earn a commission from affiliate links, but editorial decisions remain independent."
    )
    assert is_junk_content(text, title, "https://9to5mac.com/2026/03/18/sample-story") is None


def test_affiliate_disclosure_with_commercial_intent_is_junk():
    title = "Best MacBook deals this week"
    text = (
        "We may earn a commission from affiliate links. "
        "Check our buying guide for the best price and coupon offers before you buy now."
    )
    reason = is_junk_content(text, title, "https://9to5mac.com/2026/03/18/macbook-deals")
    assert reason is not None


def test_skysports_live_blog_url_is_junk():
    title = "Championship live scores, match updates and free highlights"
    text = "Live coverage and rolling updates for tonight's football fixtures."
    reason = is_junk_content(
        text,
        title,
        "https://www.skysports.com/football/live-blog/12040/13521733/championship-live-scores-match-updates"
    )
    assert reason is not None


def test_live_scores_match_updates_phrase_is_junk_without_url():
    title = "EFL live scores and match updates"
    text = "Get minute-by-minute updates, full-time results, and live commentary."
    reason = is_junk_content(text, title)
    assert reason is not None

def test_who_health_article_is_not_junk():
    title = "WHO validates elimination of trachoma as a public health problem in Libya"
    text = (
        "The World Health Organization (WHO) has confirmed that Libya has successfully eliminated trachoma as a public health problem. "
        "The report highlights the collective efforts of health workers and international stakeholders. "
        "The spread of the disease was significantly controlled through a combination of surgery, antibiotics, facial cleanliness and environmental improvement. "
        "This achievement is a major milestone for the region's health security."
    )
    url = "https://www.who.int/news/item/18-02-2026-who-validates-elimination-of-trachoma-as-a-public-health-problem-in-libya"
    assert is_junk_content(text, title, url) is None


def test_is_junk_url_blocks_betting_slug_fast():
    reason = is_junk_url(
        "https://example.com/football/arsenal-vs-chelsea-odds-and-picks",
        "Arsenal vs Chelsea odds and picks",
        "arsenal vs chelsea"
    )
    assert reason is not None


def test_is_junk_url_blocks_bad_betting_domain():
    reason = is_junk_url("https://www.bet365.com/soccer/premier-league")
    assert reason is not None


def test_is_junk_url_allows_non_sports_prediction_story():
    reason = is_junk_url(
        "https://www.reuters.com/world/climate/climate-predictions-2026-03-24/",
        "Climate predictions show higher heat extremes",
        "climate forecast"
    )
    assert reason is None


def test_is_junk_url_blocks_sports_prematch_preview_pattern():
    reason = is_junk_url(
        "https://www.charltonafc.com/news/information-fans-attending-canaries-clash",
        "Information for fans attending Canaries clash",
        "charlton vs norwich city"
    )
    assert reason is not None


def test_is_junk_url_allows_postmatch_report_story():
    reason = is_junk_url(
        "https://www.bbc.com/sport/football/articles/cx2kexample",
        "Norwich beat Charlton 2-1 in Championship result",
        "match report and reaction"
    )
    assert reason is None
