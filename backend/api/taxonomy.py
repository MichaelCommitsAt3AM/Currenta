from fastapi import APIRouter, Request, Response
from ..core.security import limiter
from ..services.taxonomy import get_taxonomy

router = APIRouter()


@router.get("")
@limiter.limit("60/minute")
async def get_taxonomy_payload(request: Request, response: Response):
    """
    Canonical category/subcategory tree used for onboarding personalization
    and article subcategory display. Static within a running process (only
    changes on deploy), so it's served with a content-hash ETag — clients
    should send If-None-Match and expect a 304 when nothing changed.
    """
    taxonomy = get_taxonomy()
    response.headers["ETag"] = taxonomy.etag
    response.headers["Cache-Control"] = "public, max-age=3600"

    if_none_match = request.headers.get("if-none-match")
    if if_none_match == taxonomy.etag:
        response.status_code = 304
        return None

    return taxonomy.to_api_payload()
