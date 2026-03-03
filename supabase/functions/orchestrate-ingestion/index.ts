import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Feed registry — mirrors lib/core/config/news_sources.dart
// Keep these two files in sync when adding/removing feeds.
// ---------------------------------------------------------------------------
const FEEDS: { feedUrl: string; defaultCategory: string; categoryBias: "strong" | "neutral" }[] = [
    // World
    { feedUrl: "http://feeds.bbci.co.uk/news/rss.xml", defaultCategory: "world", categoryBias: "neutral" },
    { feedUrl: "http://feeds.bbci.co.uk/news/world/rss.xml", defaultCategory: "world", categoryBias: "neutral" },
    { feedUrl: "https://www.reutersagency.com/feed/?best-topics=political-general&post_type=best", defaultCategory: "world", categoryBias: "neutral" },
    { feedUrl: "https://www.aljazeera.com/xml/rss/all.xml", defaultCategory: "world", categoryBias: "neutral" },
    { feedUrl: "https://rss.nytimes.com/services/xml/rss/nyt/World.xml", defaultCategory: "world", categoryBias: "neutral" },
    { feedUrl: "https://feeds.a.dj.com/rss/RSSWorldNews.xml", defaultCategory: "world", categoryBias: "neutral" },
    { feedUrl: "https://www.dw.com/xml/rss-en-all", defaultCategory: "world", categoryBias: "neutral" },
    { feedUrl: "https://www.france24.com/en/rss", defaultCategory: "world", categoryBias: "neutral" },
    // Tech
    { feedUrl: "https://www.theverge.com/rss/index.xml", defaultCategory: "tech", categoryBias: "strong" },
    { feedUrl: "https://techcrunch.com/feed/", defaultCategory: "tech", categoryBias: "strong" },
    { feedUrl: "https://www.wired.com/feed/rss", defaultCategory: "tech", categoryBias: "strong" },
    { feedUrl: "https://www.cnet.com/rss/news/", defaultCategory: "tech", categoryBias: "strong" },
    { feedUrl: "https://feeds.arstechnica.com/arstechnica/index", defaultCategory: "tech", categoryBias: "strong" },
    { feedUrl: "https://www.engadget.com/rss.xml", defaultCategory: "tech", categoryBias: "strong" },
    { feedUrl: "https://9to5mac.com/feed/", defaultCategory: "tech", categoryBias: "strong" },
    { feedUrl: "https://www.gizmodo.com/rss", defaultCategory: "tech", categoryBias: "strong" },
    { feedUrl: "https://mashable.com/feeds/rss/all", defaultCategory: "tech", categoryBias: "strong" },
    // Politics
    { feedUrl: "https://www.politico.com/rss/politicopicks.xml", defaultCategory: "politics", categoryBias: "strong" },
    { feedUrl: "https://thehill.com/homenews/feed/", defaultCategory: "politics", categoryBias: "strong" },
    { feedUrl: "https://rss.nytimes.com/services/xml/rss/nyt/Politics.xml", defaultCategory: "politics", categoryBias: "strong" },
    { feedUrl: "https://www.huffpost.com/section/politics/feed", defaultCategory: "politics", categoryBias: "strong" },
    // Science
    { feedUrl: "https://www.sciencedaily.com/rss/all.xml", defaultCategory: "science", categoryBias: "strong" },
    { feedUrl: "https://www.sciencedaily.com/rss/top/science.xml", defaultCategory: "science", categoryBias: "strong" },
    { feedUrl: "https://www.nature.com/nature.rss", defaultCategory: "science", categoryBias: "strong" },
    { feedUrl: "https://www.nasa.gov/rss/dyn/breaking_news.rss", defaultCategory: "science", categoryBias: "strong" },
    { feedUrl: "https://www.scientificamerican.com/section/all/feed/", defaultCategory: "science", categoryBias: "strong" },
    { feedUrl: "https://www.newscientist.com/feed/home/", defaultCategory: "science", categoryBias: "strong" },
    // Sports
    { feedUrl: "https://www.skysports.com/rss/12040", defaultCategory: "sports", categoryBias: "strong" },
    { feedUrl: "https://feeds.bbci.co.uk/sport/rss.xml", defaultCategory: "sports", categoryBias: "strong" },
    { feedUrl: "https://www.espn.com/espn/rss/news", defaultCategory: "sports", categoryBias: "strong" },
    { feedUrl: "https://www.cbssports.com/rss/headlines/", defaultCategory: "sports", categoryBias: "strong" },
    // Entertainment
    { feedUrl: "https://variety.com/feed/", defaultCategory: "entertainment", categoryBias: "strong" },
    { feedUrl: "https://www.hollywoodreporter.com/feed/", defaultCategory: "entertainment", categoryBias: "strong" },
    { feedUrl: "https://www.billboard.com/feed/", defaultCategory: "entertainment", categoryBias: "strong" },
    { feedUrl: "https://www.rollingstone.com/feed/", defaultCategory: "entertainment", categoryBias: "strong" },
    // Business
    { feedUrl: "https://www.ft.com/news-feed.rss", defaultCategory: "business", categoryBias: "strong" },
    { feedUrl: "https://www.cnbc.com/id/100003114/device/rss/rss.html", defaultCategory: "business", categoryBias: "strong" },
    { feedUrl: "https://feeds.a.dj.com/rss/WSJcomUSBusiness.xml", defaultCategory: "business", categoryBias: "strong" },
    { feedUrl: "https://www.bloomberg.com/feeds/podcasts/pfe_itunes.xml", defaultCategory: "business", categoryBias: "strong" },
    // Health
    { feedUrl: "https://www.who.int/rss-feeds/news-english.xml", defaultCategory: "health", categoryBias: "strong" },
    { feedUrl: "https://www.healthline.com/rss/all-news.xml", defaultCategory: "health", categoryBias: "strong" },
    { feedUrl: "https://www.mayoclinic.org/rss/all-news-topics.xml", defaultCategory: "health", categoryBias: "strong" },
];

const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// ---------------------------------------------------------------------------
// Handler — inserts pending jobs; the worker drains them at its own pace.
// We use onConflict to skip feeds that already have a pending/processing job
// (enforced by the partial unique index in the migration).
// ---------------------------------------------------------------------------
serve(async (_req: Request) => {
    console.log(`[Orchestrator] Queuing ${FEEDS.length} feeds…`);

    const rows = FEEDS.map(({ feedUrl, defaultCategory, categoryBias }) => ({
        feed_url: feedUrl,
        category: defaultCategory,
        category_bias: categoryBias,
        status: "pending",
        attempts: 0,
    }));

    // Insert all feeds; skip any that are already pending or processing
    // (partial unique index: feed_jobs_active_unique on feed_url WHERE status IN ('pending','processing'))
    const { data, error } = await supabase
        .from("feed_jobs")
        .insert(rows, { count: "exact" })
        .select("id");

    if (error) {
        // Code 23505 = unique_violation → some feeds already queued, not a hard error
        const alreadyQueued = error.code === "23505";
        if (!alreadyQueued) {
            console.error("[Orchestrator] Insert error:", error.message);
            return new Response(JSON.stringify({ ok: false, error: error.message }), {
                status: 500,
                headers: { "Content-Type": "application/json" },
            });
        }
        console.log("[Orchestrator] Some feeds already queued — skipped duplicates.");
    }

    const queued = data?.length ?? 0;
    console.log(`[Orchestrator] Queued ${queued} new jobs. Worker will drain them.`);

    return new Response(
        JSON.stringify({ ok: true, queued }),
        { headers: { "Content-Type": "application/json" } },
    );
});
