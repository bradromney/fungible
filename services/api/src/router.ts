import type { Store } from "./store";
import type { ApiResponse, CreateSetBody, Bounds } from "./types";
import { ok, created, badRequest, notFound } from "./types";

export interface ApiRequest {
  method: string;
  path: string;
  body?: unknown;
}

// Pure request router. Maps method+path to a Store operation and returns an
// ApiResponse — no Cloudflare runtime, no I/O of its own, so it's fully
// unit-tested. The Workers entry adapts real Request/Response around this.
//
// Routes:
//   POST /sets                  create a set            -> 201 SetRecord
//   GET  /sets/:id              fetch a set             -> 200 | 404
//   POST /sets/:id/share        create a share link     -> 201 {token,url} | 404
//   POST /sets/:id/uploads      request a blob upload   -> 201 UploadTarget | 404
//   GET  /share/:token          public set by share     -> 200 | 404
export async function route(req: ApiRequest, store: Store): Promise<ApiResponse> {
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
    const token = await store.createShare(seg[1]);
    return token ? created({ token, url: `/share/${token}` }) : notFound("set not found");
  }

  if (req.method === "POST" && seg.length === 3 && seg[0] === "sets" && seg[2] === "uploads") {
    const filename = parseFilename(req.body);
    if (!filename) return badRequest("expected { filename: string }");
    const target = await store.createUpload(seg[1], filename);
    return target ? created(target) : notFound("set not found");
  }

  if (req.method === "GET" && seg.length === 2 && seg[0] === "share") {
    const set = await store.resolveShare(seg[1]);
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
