from curl_cffi import requests
from trafilatura import bare_extraction
from PIL import Image
import io
import base64
from bs4 import BeautifulSoup
import httpx
from googlenewsdecoder import gnewsdecoder
import json

def process_image(img_url: str) -> str | None:
    """Downloads, resizes, and iteratively compresses to target ~150KB."""
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
            
        # 5. Encode to Base64
        return base64.b64encode(final_buffer.getvalue()).decode("utf-8")
    except Exception as e:
        print(f"[Image] Failed to process {img_url}: {e}")
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
    Returns text, image_url, and compressed image_base64.
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

        # 3. Handle Image Compression
        image_url = result.get('image')
        
        # Fallback: manual meta-tag extraction if Trafilatura missed it
        if not image_url:
            image_url = extract_meta_image(response.text)

        image_base64 = None
        if image_url:
            image_base64 = process_image(image_url)

        return {
            "text": result.get('text'),
            "image_url": image_url,
            "image_base64": image_base64,
            "title": result.get('title'),
            "url": url,
            "original_url": original_url
        }

    except Exception as e:
        return {"error": str(e), "url": url, "original_url": original_url}
