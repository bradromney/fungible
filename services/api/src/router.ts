import type { Store } from "./store";
import type { ApiResponse, CreateSetBody, CreateShareBody, Bounds } from "./types";
import { ok, created, badRequest, notFound, noContent } from "./types";

export interface ApiRequest {
  method: string;
  path: string;
  body?: unknown;
}

// Pure request router. Maps method+path to a Store operation and returns an
// ApiResponse — no Cloudflare runtime, no I/O of its own, so it's fully
// unit-tested. The Workers entry adapts real Request/Response around this and
// enforces the auth policy (auth.ts) before anything reaches here; `now` is a
// parameter so expiry logic is deterministic under test.
//
// Routes:
//   POST   /sets                create a set            -> 201 SetRecord
//   GET    /sets/:id            fetch a set             -> 200 | 404
//   POST   /sets/:id/share      create a share link     -> 201 {token,url,expiresAt?} | 404
//   POST   /sets/:id/uploads    request a blob upload   -> 201 UploadTarget | 404
//   GET    /share/:token        public set by share     -> 200 | 404 (expired/revoked = 404)
//   DELETE /share/:token        revoke a share link     -> 204 | 404
export async function route(
  req: ApiRequest,
  store: Store,
  now: Date = new Date()
): Promise<ApiResponse> {
  const seg = req.path.split("/").filter(Boolean);

  if (req.method === "POST" && seg.length === 1 && seg[0] === "sets") {
    const parsed = parseCreateSet(req.body);
    if (!parsed) return badRequest("expected { name: string }");
    return created(await store.createSet(parsed));
  }

  if (req.method === "GET" && seg.length === 2 && seg[0] === "sets") {
    const set = await store.getSet(seg[1]);
    return set ? ok(set) : notFound("set not found");
  }

  if (req.method === "POST" && seg.length === 3 && seg[0] === "sets" && seg[2] === "share") {
    const opts = parseCreateShare(req.body);
    if (opts === null) return badRequest("expected optional { expiresInDays: number > 0 }");
    const expiresAt = opts.expiresInDays
      ? new Date(now.getTime() + opts.expiresInDays * 86_400_000).toISOString()
      : undefined;
    const share = await store.createShare(seg[1], expiresAt);
    return share
      ? created({ token: share.token, url: `/share/${share.token}`, expiresAt: share.expiresAt })
      : notFound("set not found");
  }

  if (req.method === "DELETE" && seg.length === 2 && seg[0] === "share") {
    return (await store.revokeShare(seg[1])) ? noContent() : notFound("share not found");
  }

  if (req.method === "POST" && seg.length === 3 && seg[0] === "sets" && seg[2] === "uploads") {
    const filename = parseFilename(req.body);
    if (!filename) return badRequest("expected { filename: string }");
    const target = await store.createUpload(seg[1], filename);
    return target ? created(target) : notFound("set not found");
  }

  if (req.method === "GET" && seg.length === 2 && seg[0] === "share") {
    const set = await store.resolveShare(seg[1], now.toISOString());
    return set ? ok(set) : notFound("share not found");
  }

  return notFound("no such route");
}

// MARK: validation

function parseCreateSet(body: unknown): CreateSetBody | null {
  if (typeof body !== "object" || body === null) return null;
  const o = body as Record<string, unknown>;
  if (typeof o.name !== "string" || o.name.length === 0) return null;
  const result: CreateSetBody = { name: o.name };
  if (typeof o.pointCount === "number") result.pointCount = o.pointCount;
  if (isBounds(o.bounds)) result.bounds = o.bounds;
  return result;
}

/** Returns the parsed options, or null for a malformed body (an absent/empty
 *  body is valid — it means "no expiry"). */
function parseCreateShare(body: unknown): CreateShareBody | null {
  if (body === undefined || body === null) return {};
  if (typeof body !== "object") return null;
  const o = body as Record<string, unknown>;
  if (o.expiresInDays === undefined) return {};
  if (typeof o.expiresInDays !== "number" || !(o.expiresInDays > 0)) return null;
  return { expiresInDays: o.expiresInDays };
}

function parseFilename(body: unknown): string | null {
  if (typeof body !== "object" || body === null) return null;
  const o = body as Record<string, unknown>;
  return typeof o.filename === "string" && o.filename.length > 0 ? o.filename : null;
}

function isBounds(v: unknown): v is Bounds {
  if (typeof v !== "object" || v === null) return false;
  const o = v as Record<string, unknown>;
  const triple = (x: unknown) => Array.isArray(x) && x.length === 3 && x.every((n) => typeof n === "number");
  return triple(o.min) && triple(o.max);
}
