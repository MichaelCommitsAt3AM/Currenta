import { waitlist as copy } from '../content/copy.js';

// Posts to the FastAPI backend (backend/api/waitlist.py). Override the host at
// build time with VITE_WAITLIST_ENDPOINT (see .env.example); the default is the
// live backend. A 429 means "already asked recently" — treated as success.
const ENDPOINT = import.meta.env.VITE_WAITLIST_ENDPOINT || 'https://dev-api.currenta.tech/api/waitlist';
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function mountWaitlist() {
  const form = document.querySelector('[data-waitlist]');
  if (!form) return () => {};

  const email = form.querySelector('input[name="email"]');
  const honey = form.querySelector('input[name="company"]');
  const button = form.querySelector('button[type="submit"]');
  const message = form.querySelector('[data-waitlist-message]');
  const mountedAt = Date.now();
  let busy = false;
  let done = false;

  // Cheap bot signal: a real person takes more than a beat to read + type. Used
  // only to annotate the payload, never to block a submission outright.
  const looksAutomated = () => Boolean(honey.value) || Date.now() - mountedAt < 800;

  const say = (text, tone) => {
    message.textContent = text;
    message.classList.toggle('text-clay-light', tone === 'error');
    message.classList.toggle('text-cream/70', tone !== 'error');
  };

  const succeed = () => {
    done = true;
    form.reset();
    say(copy.success);
    button.remove();
    email.disabled = true;
  };

  const onSubmit = async (e) => {
    e.preventDefault();
    if (busy || done) return;
    if (honey.value) return; // hidden field only a bot fills

    const value = email.value.trim();
    if (!EMAIL_RE.test(value)) {
      say('That doesn’t look like an email address.', 'error');
      email.focus();
      return;
    }

    busy = true;
    button.disabled = true;
    const label = button.querySelector('span');
    const original = label.textContent;
    label.textContent = 'Sending…';

    try {
      const res = await fetch(ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: value,
          ref: document.referrer || null,
          ts: new Date().toISOString(),
          suspected_bot: looksAutomated(),
        }),
      });

      // 429: rate-limited per IP — almost always the same person re-submitting.
      // Treat as "you're on the list" rather than an error.
      if (res.ok || res.status === 429) {
        succeed();
        return;
      }
      if (res.status === 422) {
        say('That doesn’t look like an email address.', 'error');
      } else {
        say(copy.error, 'error');
      }
      busy = false;
      button.disabled = false;
      label.textContent = original;
    } catch (err) {
      console.warn('[waitlist]', err);
      say(copy.error, 'error');
      busy = false;
      button.disabled = false;
      label.textContent = original;
    }
  };

  form.addEventListener('submit', onSubmit);
  return () => form.removeEventListener('submit', onSubmit);
}
