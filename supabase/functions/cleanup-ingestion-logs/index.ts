import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.42.0'

Deno.serve(async (req) => {
  console.log('Cleanup job started at:', new Date().toISOString())

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing environment variables: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY')
    }

    const supabaseClient = createClient(supabaseUrl, supabaseServiceKey)

    // Calculate the threshold date (7 days ago)
    const sevenDaysAgo = new Date()
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7)
    const thresholdDate = sevenDaysAgo.toISOString()

    console.log(`Cleaning up logs older than: ${thresholdDate}`)

    const { error, count } = await supabaseClient
      .from('ingestion_logs')
      .delete({ count: 'exact' })
      .lt('created_at', thresholdDate)

    if (error) {
      console.error('Error during cleanup:', error)
      throw error
    }

    console.log(`Successfully deleted ${count} rows from ingestion_logs.`)

    return new Response(
      JSON.stringify({
        message: 'Cleanup successful',
        deleted_count: count ?? 0,
        threshold: thresholdDate
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (err) {
    console.error('Fatal error in cleanup function:', err)
    return new Response(
      JSON.stringify({ error: err.message }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})
