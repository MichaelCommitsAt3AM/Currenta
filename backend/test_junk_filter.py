from backend.services.ingestion import is_junk_content


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
