from curl_cffi import requests
from trafilatura import bare_extraction
from PIL import Image
import io
from bs4 import BeautifulSoup
import httpx
from googlenewsdecoder import gnewsdecoder
import json
from datetime import datetime, timezone

def process_image(img_url: str) -> bytes | None:
    """Downloads, resizes, and iteratively compresses to target ~150KB. Returns raw bytes."""
    try:
        # 1. Fetch bytes
        res = requests.get(img_url, impersonate="chrome120", timeout=10)
        if res.status_code != 200:
            return None

        # 2. Open with Pillow
        img = Image.open(io.BytesIO(res.content))
        
        # Convert to RGB
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")

        # 3. Resize if too large
        max_size = (1200, 1200)
        img.thumbnail(max_size, Image.Resampling.LANCZOS)

        # 4. Iterative Compression to target ~150KB
        target_size_bytes = 150 * 1024
        quality = 85
        step = 5
        min_quality = 20
        
        final_buffer = io.BytesIO()
        
        while quality >= min_quality:
            current_buffer = io.BytesIO()
            img.save(current_buffer, format="JPEG", quality=quality, optimize=True)
            size = current_buffer.tell()
            
            if size <= target_size_bytes or quality == min_quality:
                final_buffer = current_buffer
                # print(f"[Image] Compressed to {size/1024:.1f}KB at quality {quality}")
                break
            
            quality = quality - step
            
        # 5. Return raw bytes
        return final_buffer.getvalue()
    except Exception as e:
        print(f"[Image] Failed to process {img_url}: {e}")
        return None

def extract_meta_title(html: str) -> str | None:
    """Fallback manual extraction for article titles."""
    try:
        soup = BeautifulSoup(html, 'html.parser')
        
        # Priority 1: Open Graph Title
        og_title = soup.find("meta", property="og:title") or soup.find("meta", attrs={"name": "og:title"})
        if og_title and og_title.get("content"):
            return og_title["content"]
            
        # Priority 2: Twitter Title
        twitter_title = soup.find("meta", property="twitter:title") or soup.find("meta", attrs={"name": "twitter:title"})
        if twitter_title and twitter_title.get("content"):
            return twitter_title["content"]

        # Priority 3: <title> tag (clean it up)
        if soup.title and soup.title.string:
            title = soup.title.string.strip()
            # Common patterns to remove: " | TechCrunch", " - Reuters", etc.
            for separator in [" | ", " - ", " : ", " » "]:
                if separator in title:
                    title = title.split(separator)[0]
            return title

        return None
    except Exception as e:
        print(f"[Scraper] Title extraction error: {e}")
        return None

def extract_meta_image(html: str) -> str | None:
    """Fallback manual extraction for hero images with support for JSON-LD and site-specific patterns."""
    try:
        soup = BeautifulSoup(html, 'html.parser')
        
        # Priority 1: Open Graph Image
        og_image = soup.find("meta", property="og:image") or soup.find("meta", attrs={"name": "og:image"})
        if og_image and og_image.get("content"):
            return og_image["content"]
            
        # Priority 2: Twitter Image
        twitter_image = soup.find("meta", property="twitter:image") or soup.find("meta", attrs={"name": "twitter:image"})
        if twitter_image and twitter_image.get("content"):
            return twitter_image["content"]

        # Priority 3: JSON-LD (Schema.org) - Very reliable for news sites
        for script in soup.find_all("script", type="application/ld+json"):
            try:
                content = script.get_text()
                if not content: continue
                data = json.loads(content)
                if isinstance(data, list):
                    for entry in data:
                        if "image" in entry:
                            img = entry["image"]
                            if isinstance(img, dict) and "url" in img: return img["url"]
                            if isinstance(img, str): return img
                elif isinstance(data, dict):
                    # Check direct or within @graph
                    graph = data.get("@graph", [])
                    items = graph if isinstance(graph, list) else [data]
                    for item in items:
                        if "image" in item:
                            img = item["image"]
                            if isinstance(img, dict) and "url" in img: return img["url"]
                            if isinstance(img, str): return img
            except:
                continue

        # Priority 4: Specific site patterns (e.g., The Hill)
        # thehill.com uses figure.article__featured-image img
        hill_img = soup.select_one("figure.article__featured-image img")
        if hill_img:
            # Check data-src (lazy loading) then src
            res = hill_img.get("data-src") or hill_img.get("src")
            if res: return res

        # Priority 5: Generic hero/featured image selectors
        selectors = [
            "img.featured-image", "img.hero-image", ".main-image img", 
            ".article-lead-image img", ".post-thumbnail img"
        ]
        for sel in selectors:
            found = soup.select_one(sel)
            if found:
                found_src = found.get("data-src") or found.get("src")
                if found_src and found_src.startswith("http"): return found_src

        return None
    except Exception as e:
        print(f"[Scraper] Image extraction error: {e}")
        return None

def extract_ld_json_content(html: str) -> dict | None:
    """Extracts article title and body from JSON-LD metadata as a fallback."""
    try:
        soup = BeautifulSoup(html, 'html.parser')
        for script in soup.find_all("script", type="application/ld+json"):
            content = script.get_text()
            if not content: continue
            try:
                data = json.loads(content)
                items = data if isinstance(data, list) else [data]
                if isinstance(data, dict) and "@graph" in data:
                    items.extend(data["@graph"])

                for item in items:
                    if not isinstance(item, dict): continue
                    
                    if item.get("@type") in ["NewsArticle", "Article", "BlogPosting", "WebPage"]:
                        # Standard Media and others often use articleBody
                        body = item.get("articleBody") or item.get("description") or item.get("text")
                        title = item.get("headline") or item.get("name")
                        
                        if body and len(body) > 250:
                            clean_body = BeautifulSoup(body, "html.parser").get_text(separator="\n").strip()
                            clean_title = BeautifulSoup(title, "html.parser").get_text().strip() if title else None
                            return {"text": clean_body, "title": clean_title}
            except:
                continue
        return None
    except Exception as e:
        print(f"[Scraper] JSON-LD content extraction error: {e}")
        return None

def detect_paywall_html(html: str) -> bool:
    """Detects paywalls using meta tags and JSON-LD schema metadata."""
    try:
        soup = BeautifulSoup(html, 'html.parser')
        
        # 1. Schema.org isAccessibleForFree (very common in news)
        # Check meta tags first
        meta_free = soup.find("meta", attrs={"itemprop": "isAccessibleForFree"}) or \
                    soup.find("meta", property="isAccessibleForFree") or \
                    soup.find("meta", attrs={"name": "isAccessibleForFree"})
        if meta_free and meta_free.get("content", "").lower() == "false":
            return True

        # 2. JSON-LD isAccessibleForFree
        for script in soup.find_all("script", type="application/ld+json"):
            try:
                data = json.loads(script.get_text())
                items = data if isinstance(data, list) else [data]
                if isinstance(data, dict) and "@graph" in data:
                    items.extend(data["@graph"])
                
                for item in items:
                    if not isinstance(item, dict): continue
                    if str(item.get("isAccessibleForFree")).lower() == "false":
                        return True
                    # Some sites hide it in hasPart
                    has_part = item.get("hasPart")
                    if isinstance(has_part, dict):
                        if str(has_part.get("isAccessibleForFree")).lower() == "false":
                            return True
                    elif isinstance(has_part, list):
                        for part in has_part:
                            if isinstance(part, dict) and str(part.get("isAccessibleForFree")).lower() == "false":
                                return True
            except:
                continue

        # 3. Known meta-tag patterns
        # article:premium, news_keywords containing 'premium', etc.
        premium = soup.find("meta", property="article:premium") or \
                  soup.find("meta", attrs={"name": "premium"})
        if premium and premium.get("content", "").lower() in ("true", "yes", "1"):
            return True
            
        return False
    except:
        return False

def resolve_google_news_url(url: str) -> str:
    """Decodes Google News wrapper URLs using googlenewsdecoder."""
    if "news.google.com/rss/articles/" not in url:
        return url
    
    try:
        res = gnewsdecoder(url)
        if res and res.get("status"):
            decoded_url = res.get("decoded_url")
            if decoded_url and decoded_url.startswith("http") and "news.google.com" not in decoded_url:
                print(f"[Scraper] Resolved {url[:50]}... to {decoded_url[:50]}...")
                return decoded_url
        return url
    except Exception as e:
        print(f"[Scraper] GN Decoder error for {url}: {e}")
        return url

def scrape_article_sync(url: str):
    """
    Synchronous scraper using curl_cffi and trafilatura.
    Returns text, image_url, and compressed image_bytes.
    """
    try:
        original_url = url
        # 0. Resolve Google News wrapper URLs
        url = resolve_google_news_url(url)

        # 1. Fetch with Chrome 120 impersonation
        domain = url.split("//")[-1].split("/")[0]
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
            "Accept-Language": "en-US,en;q=0.9",
            "Accept-Encoding": "gzip, deflate, br",
            "Referer": "https://www.google.com/",
            "Authority": domain,
            "DNT": "1",
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1",
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "cross-site",
            "Sec-Fetch-User": "?1",
            "Cache-Control": "max-age=0",
        }
        
        response = requests.get(url, impersonate="chrome120", headers=headers, timeout=15)
        
        # If still blocked, try fallback: Social Media Bot (some sites allow these for previews)
        if response.status_code in (401, 403, 429):
            print(f"[Scraper] Primary block (Status {response.status_code}) for {url}. Retrying with social bot headers...")
            bot_headers = {
                "User-Agent": "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
                "Accept": "*/*",
                "Referer": "https://www.facebook.com/",
            }
            response = requests.get(url, headers=bot_headers, timeout=10)

        if response.status_code != 200:
            return {"error": f"Site blocked us (Status: {response.status_code})", "url": url, "original_url": original_url}

        # 2. Extract clean text and metadata using trafilatura
        extraction_result = bare_extraction(response.text, url=url)
        
        if not extraction_result:
            # Fallback check before returning error
            ld_res = extract_ld_json_content(response.text)
            if ld_res:
                print(f"[Scraper] Trafilatura failed (None), fell back to JSON-LD content for {url}")
                result = {"text": ld_res["text"], "title": ld_res.get("title"), "image": None}
            else:
                return {"error": "Could not extract content (empty result)", "url": url, "original_url": original_url}
        else:
            # Normalize to dict
            if hasattr(extraction_result, "as_dict"):
                result = extraction_result.as_dict()
            elif isinstance(extraction_result, dict):
                result = extraction_result
            else:
                result = {
                    "text": getattr(extraction_result, "text", None),
                    "image": getattr(extraction_result, "image", None),
                    "title": getattr(extraction_result, "title", None),
                }
            
            if not result.get('text') or len(result.get('text')) < 400:
                # Fallback: JSON-LD extraction
                ld_res = extract_ld_json_content(response.text)
                if ld_res:
                    print(f"[Scraper] Trafilatura failed/short, fell back to JSON-LD content for {url}")
                    if not result: result = {}
                    result['text'] = ld_res["text"]
                    if not result.get("title"): result["title"] = ld_res.get("title")

        if not result.get('text'):
            return {"error": "Could not extract text content", "url": url, "original_url": original_url}

        # 3. Handle Title Fallback
        if not result.get('title'):
            result['title'] = extract_meta_title(response.text)

        # 4. Handle Image Compression
        image_url = result.get('image')
        
        # Fallback: manual meta-tag extraction if Trafilatura missed it
        if not image_url:
            image_url = extract_meta_image(response.text)

        image_bytes = None
        if image_url:
            image_bytes = process_image(image_url)

        # 4. Final detection
        is_paywalled = detect_paywall_html(response.text)

        return {
            "text": result.get('text'),
            "image_url": image_url,
            "image_bytes": image_bytes,
            "title": result.get('title'),
            "url": url,
            "original_url": original_url,
            "is_paywalled": is_paywalled
        }

    except Exception as e:
        return {"error": str(e), "url": url, "original_url": original_url}

def discover_techcrunch_articles(limit: int = 10) -> list[dict]:
    """
    Discovers latest TechCrunch articles via WP JSON API.
    Provides a cleaner alternative to RSS.
    """
    url = f"https://techcrunch.com/wp-json/wp/v2/posts?per_page={limit}"
    try:
        # Use httpx for a simple JSON fetch
        with httpx.Client(timeout=10.0) as client:
            res = client.get(url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36"})
            if res.status_code != 200:
                print(f"[Scraper] TechCrunch API failed (Status {res.status_code})")
                return []
            
            data = res.json()
            articles = []
            for post in data:
                title = post.get("title", {}).get("rendered", "")
                # Clean HTML entities from title
                clean_title = BeautifulSoup(title, "html.parser").get_text()
                
                # Parse date string to datetime object (asyncpg requires datetime, not str)
                pub_date_str = post.get("date_gmt")
                try:
                    if pub_date_str:
                        # TechCrunch API date_gmt is 'YYYY-MM-DDTHH:MM:SS'
                        pub_date = datetime.fromisoformat(pub_date_str).replace(tzinfo=timezone.utc)
                    else:
                        pub_date = datetime.now(timezone.utc)
                except Exception:
                    pub_date = datetime.now(timezone.utc)

                articles.append({
                    "title": clean_title,
                    "link": post.get("link"),
                    "pubDate": pub_date,
                    "source": "TechCrunch",
                    "description": BeautifulSoup(post.get("excerpt", {}).get("rendered", ""), "html.parser").get_text(strip=True)
                })
            return articles
    except Exception as e:
        print(f"[Scraper] TechCrunch discovery error: {e}")
        return []
