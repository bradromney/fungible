// Pure authorization policy — no runtime, fully unit-tested (auth.test.ts).
// The Workers entry (index.ts) enforces these decisions before routing.
//
// Model (MVP): one bearer key (`API_KEY` wrangler secret) authenticates the
// capture app for everything that creates or reads private state. Share links
// are the deliberate public surface: GET /share/:token, and GET /blobs/:key
// when accompanied by a share token whose set owns that blob. Everything else
// without the key is denied — the previous behavior (world-writable sets and
// R2) is exactly the kind of hole that can't ship.

/** Routes reachable with no credentials at all. */
export function isPublicRoute(method: string, path: string): boolean {
  const seg = path.split("/").filter(Boolean);
  if (method === "OPTIONS") return true; // CORS preflight
  if (method === "GET" && seg.length === 2 && seg[0] === "share") return true;
  return false;
}

/** Parse an `Authorization: Bearer <key>` header; null if absent/malformed. */
export function extractBearer(header: string | null): string | null {
  if (!header) return null;
  const m = /^Bearer\s+(\S+)$/.exec(header);
  return m ? m[1] : null;
}

/**
 * Constant-length-agnostic key check. (Workers `crypto.subtle.timingSafeEqual`
 * needs equal lengths; comparing hashes sidesteps leaking length via early
 * exit. For an MVP single-key check, a simple comparison of same-length
 * strings is acceptable — this helper centralizes it so hardening happens in
 * one place.)
 */
export function bearerMatches(bearer: string | null, apiKey: string | undefined): boolean {
  if (!bearer || !apiKey) return false;
  if (bearer.length !== apiKey.length) return false;
  let diff = 0;
  for (let i = 0; i < bearer.length; i++) diff |= bearer.charCodeAt(i) ^ apiKey.charCodeAt(i);
  return diff === 0;
}

/**
 * A share token authorizes reading exactly the blobs under its set's prefix
 * (upload keys are `${setId}/${filename}`).
 */
export function blobKeyBelongsToSet(key: string, setId: string): boolean {
  return setId.length > 0 && key.startsWith(`${setId}/`);
}

/** ISO-8601 comparison; a share with no expiry never expires. */
export function shareIsLive(share: { expiresAt?: string; revoked?: boolean }, nowISO: string): boolean {
  if (share.revoked) return false;
  if (!share.expiresAt) return true;
  return nowISO < share.expiresAt;
}
