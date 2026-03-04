from curl_cffi import requests
from trafilatura import bare_extraction
from PIL import Image
import io
import base64
from bs4 import BeautifulSoup

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
                print(f"[Image] Compressed to {size/1024:.1f}KB at quality {quality}")
                break
            
            quality = quality - step
            
        # 5. Encode to Base64
        return base64.b64encode(final_buffer.getvalue()).decode("utf-8")
    except Exception as e:
        print(f"[Image] Failed to process {img_url}: {e}")
        return None

def extract_meta_image(html: str) -> str | None:
    """Fallback manual extraction for hero images."""
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

        # Priority 3: Article image tag if unique enough (careful)
        return None
    except Exception as e:
        print(f"[Scraper] Meta extraction error: {e}")
        return None

def scrape_article_sync(url: str):
    """
    Synchronous scraper using curl_cffi and trafilatura.
    Returns text, image_url, and compressed image_base64.
    """
    try:
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
        
        # If still blocked, try one last fallback: Social Media Bot (some sites allow these for previews)
        if response.status_code in (401, 403):
            print(f"[Scraper] Primary block (Status {response.status_code}) for {url}. Retrying with social bot headers...")
            bot_headers = {
                "User-Agent": "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
                "Accept": "*/*",
                "Referer": "https://www.facebook.com/",
            }
            response = requests.get(url, headers=bot_headers, timeout=10)

        if response.status_code != 200:
            return {"error": f"Site blocked us (Status: {response.status_code})", "url": url}

        # 2. Extract clean text and metadata using trafilatura
        # result can be a dict in older versions or a 'Document' object in newer ones
        extraction_result = bare_extraction(response.text, url=url)
        
        if not extraction_result:
            return {"error": "Could not extract content (empty result)", "url": url}

        # Normalize to dict
        if hasattr(extraction_result, "as_dict"):
            result = extraction_result.as_dict()
        elif isinstance(extraction_result, dict):
            result = extraction_result
        else:
            # Last resort: try vars or manual mapping
            result = {
                "text": getattr(extraction_result, "text", None),
                "image": getattr(extraction_result, "image", None),
                "title": getattr(extraction_result, "title", None),
            }
        
        if not result.get('text'):
            return {"error": "Could not extract text content", "url": url}

        # 3. Handle Image Compression
        image_url = result.get('image')
        
        # Fallback: manual meta-tag extraction if Trafilatura missed it
        if not image_url:
            print(f"[Scraper] Trafilatura missed image for {url}. Trying manual meta extraction...")
            image_url = extract_meta_image(response.text)

        image_base64 = None
        if image_url:
            print(f"[Scraper] Found hero image URL: {image_url}")
            image_base64 = process_image(image_url)
            if not image_base64:
                print(f"[Scraper] Failed to process/download image: {image_url}")
        else:
            print(f"[Scraper] WARNING: No image found in meta tags either for {url}")

        return {
            "text": result.get('text'),
            "image_url": image_url,
            "image_base64": image_base64,
            "title": result.get('title'),
            "url": url
        }

    except Exception as e:
        return {"error": str(e), "url": url}
