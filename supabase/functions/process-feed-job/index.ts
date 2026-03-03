import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { processFeed } from "../_shared/ingestion.ts";

// How many jobs to claim and process per invocation.
// Keep this low (~3–5) so the function stays within the 150s wall-clock limit.
const BATCH_SIZE = 5;

// A job stuck in "processing" for longer than this is considered stale/crashed.
const STALE_THRESHOLD_MINUTES = 10;

const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// ---------------------------------------------------------------------------
// Reset stale jobs — jobs that were claimed but never completed
// (e.g. worker crashed mid-flight). Resets them to 'pending' so they retry.
// ---------------------------------------------------------------------------
async function resetStaleJobs(): Promise<number> {
    const cutoff = new Date(Date.now() - STALE_THRESHOLD_MINUTES * 60 * 1000).toISOString();
    const { data, error } = await supabase
        .from("feed_jobs")
        .update({ status: "pending", updated_at: new Date().toISOString() })
        .eq("status", "processing")
        .lt("locked_at", cutoff)
        .select("id");

    if (error) {
        console.error("[Worker] Failed to reset stale jobs:", error.message);
        return 0;
    }
    const count = data?.length ?? 0;
    if (count > 0) console.log(`[Worker] Reset ${count} stale job(s) to pending.`);
    return count;
}

// ---------------------------------------------------------------------------
// Claim a single job atomically via the DB-side function.
// Returns the claimed job row or null if the queue is empty.
// ---------------------------------------------------------------------------
async function claimJob(): Promise<Record<string, unknown> | null> {
    const { data, error } = await supabase.rpc("claim_feed_job");
    if (error) {
        console.error("[Worker] claim_feed_job RPC error:", error.message);
        return null;
    }
    // The RPC returns a SETOF — data is an array; take the first row.
    return (data as Record<string, unknown>[] | null)?.[0] ?? null;
}

// ---------------------------------------------------------------------------
// Mark a job as completed or failed in the database.
// ---------------------------------------------------------------------------
async function finalizeJob(
    jobId: string,
    status: "completed" | "failed",
    errorMessage?: string,
): Promise<void> {
    await supabase
        .from("feed_jobs")
        .update({
            status,
            last_error: errorMessage ?? null,
            updated_at: new Date().toISOString(),
        })
        .eq("id", jobId);
}

// ---------------------------------------------------------------------------
// Main handler — called by pg_cron every minute.
// ---------------------------------------------------------------------------
serve(async (_req: Request) => {
    // 1. Recover any jobs that were abandoned by a previous crashed worker.
    await resetStaleJobs();

    const summary: { feedUrl: string; status: string; error?: string }[] = [];

    // 2. Process up to BATCH_SIZE jobs sequentially (controlled throughput).
    for (let i = 0; i < BATCH_SIZE; i++) {
        const job = await claimJob();
        if (!job) {
            console.log(`[Worker] Queue empty after ${i} job(s).`);
            break;
        }

        const jobId = job.id as string;
        const feedUrl = job.feed_url as string;
        const category = job.category as string;
        const categoryBias = (job.category_bias as "strong" | "neutral" | undefined) ?? "neutral";

        console.log(`[Worker] Processing job ${jobId}: ${feedUrl} (${category} - ${categoryBias} bias)`);

        try {
            const results = await processFeed(feedUrl, category, categoryBias);
            await finalizeJob(jobId, "completed");
            summary.push({ feedUrl, status: "completed", ...results });
            console.log(`[Worker] Job ${jobId} completed:`, results);
        } catch (err) {
            const message = String(err);
            await finalizeJob(jobId, "failed", message);
            summary.push({ feedUrl, status: "failed", error: message });
            console.error(`[Worker] Job ${jobId} failed:`, message);
        }
    }

    return new Response(
        JSON.stringify({ ok: true, processed: summary.length, summary }),
        { headers: { "Content-Type": "application/json" } },
    );
});
