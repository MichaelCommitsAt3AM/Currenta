import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { processFeed } from "../_shared/ingestion.ts";

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const body = await req.json();
    const { feedUrl, categoryHint = "world" } = body;

    if (!feedUrl) {
      return new Response(JSON.stringify({ error: "feedUrl is required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[Ingest News Wrapper] Processing feed: ${feedUrl}`);
    const results = await processFeed(feedUrl, categoryHint);

    return new Response(JSON.stringify({ ok: true, results }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[Ingest News Wrapper] Error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
