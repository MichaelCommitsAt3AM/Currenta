"""Reads cost data from a GCP Billing Export to BigQuery table.

Requires the export to already be enabled on the GCP billing account
(Console > Billing > Billing export > BigQuery export) and
BIGQUERY_BILLING_TABLE / GOOGLE_APPLICATION_CREDENTIALS to be set — see
CLAUDE.md. Both the "Standard" and "Detailed" export schemas carry the
columns this query uses.
"""
import asyncio
import logging
import os
from datetime import date, timedelta
from functools import lru_cache

from google.cloud import bigquery

logger = logging.getLogger(__name__)

BILLING_TABLE = os.environ.get("BIGQUERY_BILLING_TABLE", "")


@lru_cache(maxsize=1)
def _get_client() -> bigquery.Client:
    return bigquery.Client()


def _query_billing_costs_sync(start_date: date, end_date: date) -> list[dict]:
    if not BILLING_TABLE:
        raise RuntimeError("BIGQUERY_BILLING_TABLE is not configured")

    # Cost and credits are summed separately, matching Google's own sample
    # queries for this export schema — credits are already negative, so
    # cost + credits gives the net amount actually billed.
    query = f"""
        SELECT
            DATE(usage_start_time) AS usage_date,
            service.description AS service_name,
            SUM(cost) AS cost,
            SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) AS c), 0)) AS credits,
            ANY_VALUE(currency) AS currency
        FROM `{BILLING_TABLE}`
        WHERE DATE(usage_start_time) BETWEEN @start_date AND @end_date
        GROUP BY usage_date, service_name
        ORDER BY usage_date ASC
    """
    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("start_date", "DATE", start_date),
            bigquery.ScalarQueryParameter("end_date", "DATE", end_date),
        ]
    )
    return [dict(row) for row in _get_client().query(query, job_config=job_config).result()]


async def get_billing_cost_rows(days: int) -> list[dict]:
    end_date = date.today()
    start_date = end_date - timedelta(days=days - 1)
    return await asyncio.to_thread(_query_billing_costs_sync, start_date, end_date)
