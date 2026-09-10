// Single source of truth for page copy + every stat shown on the page.
// Each number here traces to ARCHITECTURE.md / README.md — see landing/PLAN.md §7.
// If a claim can't be sourced, it doesn't belong in this file.

export const brand = {
  name: 'Currenta',
  domain: 'currenta.tech',
  email: 'support@currenta.tech',
  tagline: 'News without the noise.',
};

export const nav = [
  { label: 'Manifesto', href: '/#philosophy' },
  { label: 'How it works', href: '/#pipeline' },
  { label: 'Ways to read', href: '/#reading-modes' },
];

export const hero = {
  eyebrow: 'AI-first news, minus the clickbait',
  lineTop: 'News without the',
  lineEmph: 'Noise.',
  sub: 'Every story scanned from the wire, distilled to a factual 65-word brief, deduplicated across outlets, and ranked for what you actually read.',
  // mono telemetry strip — verified values
  telemetry: ['180+ sources', '65-word briefs', '1024-dim matching', 'ranked for you'],
  ctaPrimary: 'Join the waitlist',
  storeNote: 'Coming soon to iOS & Android',
};

export const features = {
  eyebrow: 'The instrument',
  title: 'A newsroom that runs while you sleep',
  sub: 'Not a feed of headlines — a working pipeline you can watch.',
};

export const summaryShuffler = {
  label: 'Distilled intelligence',
  faces: [
    {
      tag: '5Ws summary',
      headline: 'Central bank holds rate, signals one more hike before year-end',
      body: 'The monetary policy committee kept its benchmark rate unchanged for a second meeting, citing cooling inflation but persistent wage pressure. Officials flagged a further increase is likely before December if services prices do not ease. Markets had priced a hold. The decision passed 7–2, with two members pushing for an immediate hike.',
      chip: '6 outlets → 1 story',
    },
    {
      tag: 'Dedup cluster',
      headline: 'Same event, six framings, collapsed to one',
      body: 'Wire copy, a business daily, two broadcasters and two aggregators filed the same rate decision within 40 minutes. Currenta compared a framing-free event key for each and merged them above a 0.75 similarity threshold — you see the story once, with every source attached.',
      chip: 'similarity 0.91',
    },
    {
      tag: 'Locality match',
      headline: 'Flagged relevant to your region',
      body: 'The pipeline detects whether a story is locally significant before it reaches your feed, with dedicated ingestion for regional outlets. Geo-IP sets your default region on first open; you can change it any time.',
      chip: 'local ingestion',
    },
  ],
};

export const pipelineTypewriter = {
  label: 'Live ingestion',
  liveLabel: 'Live feed',
  lines: [
    'Scanning 180+ wire feeds…',
    'Blocking betting odds, previews & live-blogs…',
    'Summarising with Gemini — 65 words, five Ws…',
    'Embedding a 1024-dim vector…',
    'Comparing the event key against 7 days of coverage…',
    'Collapsing 6 sources into 1 story…',
    'Scoring freshness × momentum…',
  ],
};

export const interestTuner = {
  label: 'Your interests, enforced',
  note: 'De-select a category and it is gone from every part of your feed — a hard opt-out, not a nudge.',
  chips: ['Politics', 'Business', 'Technology', 'Science', 'Sport', 'Culture', 'Local'],
  muteTarget: 'Sport',
  saveLabel: 'Save',
  feedBefore: ['Transfer window: the 9 deals still on', 'Rate decision splits the committee', 'New telescope resolves a forming planet'],
  feedAfter: ['Rate decision splits the committee', 'New telescope resolves a forming planet', 'The election maths, district by district'],
};

export const philosophy = {
  eyebrow: 'The manifesto',
  old: { prefix: 'Old media asks:', q: 'What will make you click?' },
  ours: { prefix: 'Currenta asks:', q: 'What do you actually need to know?' },
  body: 'Attention is not the product. The pipeline is tuned for signal — factual summaries, one story per event, and a feed that ages momentum out within an evening instead of chasing it.',
};

export const pipeline = {
  eyebrow: 'How it works',
  title: 'Three stages, one clean feed',
  cards: [
    {
      n: '01',
      kicker: 'Discovery',
      title: 'Track the whole wire',
      body: '180+ RSS feeds and custom scrapers, polled continuously. A deterministic gate blocks betting lines, sports previews and live-blogs before a single token reaches the model.',
      stat: '180+ sources · regex junk-gate',
    },
    {
      n: '02',
      kicker: 'Distillation',
      title: 'Strip the framing, keep the facts',
      body: 'Each article becomes a strict 65-word five-Ws brief plus a framing-free event key. Near-duplicate coverage is merged above 0.75 cosine similarity, so the same event never fills your feed twice.',
      stat: '65 words · dedup ≥ 0.75',
    },
    {
      n: '03',
      kicker: 'Personalisation',
      title: 'Match what you actually read',
      body: 'Your interactions build an interest vector. The For You feed pulls the 150 nearest stories by embedding, then re-ranks them on a blend of similarity and freshness so a fresher story can overtake a marginally better match.',
      stat: 'similarity × recency · 0.6 / 0.4',
    },
  ],
};

export const readingModes = {
  eyebrow: 'Ways to read',
  title: 'Three ways in',
  sub: 'Every mode draws from the same 48-hour candidate window. No paywalls, no tiers.',
  cards: [
    {
      icon: 'trending-up',
      name: 'Trending',
      copy: 'High-momentum stories inside the categories you keep — and only those.',
      stat: '20% of your feed · Google-Trends matched · decays hourly',
      featured: false,
    },
    {
      icon: 'sparkles',
      name: 'For You',
      copy: 'Semantically matched to what you actually read, then re-ranked so the freshest strong match wins.',
      stat: '70% of your feed · similarity × recency, 0.6 / 0.4',
      featured: true,
    },
    {
      icon: 'map-pin',
      name: 'Local',
      copy: 'Your region’s news, detected on first open, with ingestion dedicated to regional outlets.',
      stat: 'Geo-IP · dedicated local pipeline',
      featured: false,
    },
  ],
};

export const waitlist = {
  eyebrow: 'Early access',
  title: 'Be first on the feed',
  sub: 'We’re finishing the iOS and Android builds. Leave an email and we’ll send a build link — nothing else.',
  placeholder: 'you@example.com',
  cta: 'Request access',
  success: 'You’re on the list. Watch your inbox for a build link.',
  error: 'Something went wrong. Try again in a moment.',
};

export const footer = {
  status: 'All systems operational',
  columns: [
    {
      title: 'Currenta',
      links: [
        { label: 'Manifesto', href: '/#philosophy' },
        { label: 'How it works', href: '/#pipeline' },
        { label: 'Ways to read', href: '/#reading-modes' },
      ],
    },
    {
      title: 'Legal',
      links: [
        { label: 'Privacy policy', href: '/privacy.html' },
        { label: 'Terms of service', href: '/terms.html' },
        { label: 'Delete account data', href: '/delete-account.html' },
      ],
    },
    {
      title: 'Contact',
      links: [{ label: brand.email, href: `mailto:${brand.email}` }],
    },
  ],
  legalLine: `© ${new Date().getFullYear()} Currenta. All rights reserved.`,
};
