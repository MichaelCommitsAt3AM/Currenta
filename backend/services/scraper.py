from curl_cffi import requests
from trafilatura import bare_extraction
from PIL import Image
import io
import base64

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
            
            quality -= step
            
        # 5. Encode to Base64
        return base64.b64encode(final_buffer.getvalue()).decode("utf-8")
    except Exception as e:
        print(f"[Image] Failed to process {img_url}: {e}")
        return None

def scrape_article_sync(url: str):
    """
    Synchronous scraper using curl_cffi and trafilatura.
    Returns text, image_url, and compressed image_base64.
    """
    try:
        # 1. Fetch with Chrome 120 impersonation
        response = requests.get(url, impersonate="chrome120", timeout=15)
        
        if response.status_code != 200:
            raise Exception(f"Site blocked us (Status: {response.status_code})")

        # 2. Extract clean text and metadata using trafilatura
        result = bare_extraction(response.text, url=url)
        
        if not result or not result.get('text'):
             # fallback or error out
            return {"error": "Could not extract text content", "url": url}

        # 3. Handle Image Compression
        image_url = result.get('image')
        image_base64 = None
        if image_url:
            image_base64 = process_image(image_url)

        return {
            "text": result.get('text'),
            "image_url": image_url,
            "image_base64": image_base64,
            "title": result.get('title'),
            "url": url
        }

    except Exception as e:
        return {"error": str(e), "url": url}
