create table feed_jobs (
  id uuid primary key default gen_random_uuid(),
  feed_url text not null,
  category text not null,
  status text not null default 'pending',
  attempts int not null default 0,
  locked_at timestamptz,
  last_error text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index on feed_jobs(status);

create table llm_usage (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now()
);

create index on llm_usage(created_at);

create or replace function claim_feed_job()
returns setof feed_jobs
language plpgsql
as $$
begin
  return query
  update feed_jobs
  set status = 'processing',
      locked_at = now(),
      attempts = attempts + 1,
      updated_at = now()
  where id = (
    select id
    from feed_jobs
    where status = 'pending' or (status = 'failed' and attempts < 3)
    order by created_at asc
    limit 1
    for update skip locked
  )
  returning *;
end;
$$;
