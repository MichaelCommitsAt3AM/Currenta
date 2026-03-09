from services.scraper import scrape_article_sync
import json

def test_google_news_scraping():
    url = "https://news.google.com/rss/articles/CBMizwFBVV95cUxOLTRwNkh4aGNRT2JSRnVOR004Z185VVJObEt0Y0J4UTBzbmZ4VDVGdm5kWndXaWRpR1lxOUJkWUY1N1NtU2VzSmx6RDVhZ0VDVW5JczI2dlFacGtRWVJzTVM4cnRMU2RwaXFSWmNlWkFQVy1SRC1HdkFaMXlyZkJTMG91S3VZYi1kX21SNDNDZXNxYTFQSzh1aFRaNzE5azZFS3cyNUJZQzkxSFFhVXpaTmt1U3RPWHdTdHdKMWhBM3NJQTlYTV80SC1EYmtrdFnSAbsBQVVfeXFMTmVWa1FJVG4wR1NvbEtPTUdnbTdJMFE1UzNRQmhGdm1Vd1NOTFBmNVpPZTZibmc3ZmpnSlFuc1FQNEVoSGlTQUtmWU9jdGpCdTFzOTl3MGNVVDhvWkRTb0xnZ3RWcEtOek9iZWQ4TVlScWx6YUpPRnlNZVAybzBJeFpDMjNDZWtGaFRWaTlTM1h5N0dhWmtTRXdsSUhFMHdocXk1UzF0ZGNOcmcwTmtUVEYzTDhJZ0Y1S0xBSQ?oc=5"
    
    print(f"Testing URL: {url}")
    result = scrape_article_sync(url)
    
    if "error" in result:
        print(f"FAILED: {result['error']}")
        if "url" in result:
            print(f"Attempted Destination URL: {result['url']}")
    else:
        print("SUCCESS!")
        print(f"Resolved URL: {result['url']}")
        print(f"Title: {result['title']}")
        print(f"Image Found: {result['image_url'] is not None}")
        if result['image_url']:
            print(f"Image URL: {result['image_url']}")
        print(f"Image Base64 length: {len(result['image_base64']) if result['image_base64'] else 0}")
        print(f"Text Preview: {result['text'][:200]}...")

if __name__ == "__main__":
    test_google_news_scraping()
