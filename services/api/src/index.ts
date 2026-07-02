import type { Store } from "./store";
import type { CreateSetBody, SetRecord, ShareInfo, UploadTarget } from "./types";
import { route, type ApiRequest } from "./router";
import { buildPrompt, deterministicSummary, parseReportFacts } from "./report";
import { bearerMatches, blobKeyBelongsToSet, extractBearer, isPublicRoute, shareIsLive } from "./auth";

// Cloudflare Workers entry. Adapts real Request/Response around the pure `route`
// for JSON metadata endpoints, handles binary blob PUT/GET against R2 directly,
// and backs the Store with D1. This file is the only one touching the runtime;
// all the logic it calls is unit-tested (router.test.ts, auth.test.ts).
//
// Access model: every route except the share surface requires the app's bearer
// key (`wrangler secret put API_KEY`). Share links are the public surface:
// GET /share/:token resolves a live share, and GET /blobs/:key?share=<token>
// lets the web viewer stream the set's blob with the same token. With no
// API_KEY configured, protected routes fail closed (503) rather than open.

export interface Env {
  DB: D1Database;
  BUCKET: R2Bucket;
  /** Bearer key the capture app authenticates with (`wrangler secret put API_KEY`). */
  API_KEY?: string;
  /** Optional: set via `wrangler secret put ANTHROPIC_API_KEY` to enable
   *  LLM-enhanced reports. Absent → deterministic reports (still works). */
  ANTHROPIC_API_KEY?: string;
}

const REPORT_SYSTEM_PROMPT =
  "You are a surveying and earthwork assistant. Produce concise, accurate, " +
  "client-ready site summaries from measured facts. Never invent or alter numbers; " +
  "use only the figures provided.";

/// Claude API call for an enhanced narrative. Throws on any failure so the
/// caller falls back to the deterministic summary.
async function generateNarrative(prompt: string, apiKey: string): Promise<string> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-6",
      max_tokens: 400,
      // Cached system block → prompt caching across report requests.
      system: [{ type: "text", text: REPORT_SYSTEM_PROMPT, cache_control: { type: "ephemeral" } }],
      messages: [{ role: "user", content: prompt }],
    }),
  });
  if (!res.ok) throw new Error(`anthropic ${res.status}`);
  const data = (await res.json()) as { content?: Array<{ type: string; text?: string }> };
  const text = data.content?.find((b) => b.type === "text")?.text;
  if (!text) throw new Error("no text in anthropic response");
  return text;
}

class D1Store implements Store {
  constructor(private env: Env) {}

  async createSet(input: CreateSetBody): Promise<SetRecord> {
    const record: SetRecord = {
      id: crypto.randomUUID(),
      name: input.name,
      createdAt: new Date().toISOString(),
      pointCount: input.pointCount ?? 0,
      bounds: input.bounds,
    };
    await this.env.DB.prepare(
      "INSERT INTO sets (id, name, created_at, point_count, bounds_json) VALUES (?, ?, ?, ?, ?)"
    )
      .bind(record.id, record.name, record.createdAt, record.pointCount, JSON.stringify(record.bounds ?? null))
      .run();
    return record;
  }

  async getSet(id: string): Promise<SetRecord | null> {
    const row = await this.env.DB.prepare("SELECT * FROM sets WHERE id = ?").bind(id).first<Record<string, unknown>>();
    return row ? rowToSet(row) : null;
  }

  async createShare(setId: string, expiresAt?: string): Promise<ShareInfo | null> {
    if (!(await this.getSet(setId))) return null;
    const token = crypto.randomUUID();
    await this.env.DB.prepare("INSERT INTO shares (token, set_id, expires_at, revoked) VALUES (?, ?, ?, 0)")
      .bind(token, setId, expiresAt ?? null)
      .run();
    return { token, expiresAt };
  }

  async resolveShare(token: string, nowISO: string): Promise<SetRecord | null> {
    const share = await this.shareRow(token);
    if (!share || !shareIsLive(share, nowISO)) return null;
    return this.getSet(share.setId);
  }

  async revokeShare(token: string): Promise<boolean> {
    const result = await this.env.DB.prepare("UPDATE shares SET revoked = 1 WHERE token = ?").bind(token).run();
    return (result.meta?.changes ?? 0) > 0;
  }

  async createUpload(setId: string, filename: string): Promise<UploadTarget | null> {
    if (!(await this.getSet(setId))) return null;
    const key = `${setId}/${filename}`;
    return { url: `/blobs/${key}`, key };
  }

  async attachBlob(setId: string, key: string): Promise<boolean> {
    const result = await this.env.DB.prepare("UPDATE sets SET blob_key = ? WHERE id = ?").bind(key, setId).run();
    return (result.meta?.changes ?? 0) > 0;
  }

  /** The raw share row (regardless of liveness) — used for blob authorization. */
  async shareRow(token: string): Promise<{ setId: string; expiresAt?: string; revoked?: boolean } | null> {
    const row = await this.env.DB.prepare("SELECT set_id, expires_at, revoked FROM shares WHERE token = ?")
      .bind(token)
      .first<Record<string, unknown>>();
    if (!row) return null;
    return {
      setId: String(row.set_id),
      expiresAt: row.expires_at ? String(row.expires_at) : undefined,
      revoked: Boolean(row.revoked),
    };
  }
}

function rowToSet(row: Record<string, unknown>): SetRecord {
  return {
    id: String(row.id),
    name: String(row.name),
    createdAt: String(row.created_at),
    pointCount: Number(row.point_count ?? 0),
    bounds: row.bounds_json ? JSON.parse(String(row.bounds_json)) ?? undefined : undefined,
    blobKey: row.blob_key ? String(row.blob_key) : undefined,
  };
}

// The web viewer runs on another origin; the public share surface (and the
// authed API, harmlessly) must be CORS-readable.
const CORS_HEADERS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, POST, PUT, DELETE, OPTIONS",
  "access-control-allow-headers": "authorization, content-type",
};

function json(body: unknown, status: number): Response {
  return status === 204
    ? new Response(null, { status, headers: CORS_HEADERS })
    : Response.json(body, { status, headers: CORS_HEADERS });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const bearer = extractBearer(request.headers.get("authorization"));
    const authed = bearerMatches(bearer, env.API_KEY);
    const store = new D1Store(env);
    const nowISO = new Date().toISOString();

    // Binary blob transfer goes straight to R2 (not through the JSON router).
    if (path.startsWith("/blobs/")) {
      const key = path.slice("/blobs/".length);

      if (request.method === "GET") {
        // Readable with the app key, or with a live share token owning the key.
        let allowed = authed;
        if (!allowed) {
          const token = url.searchParams.get("share");
          const share = token ? await store.shareRow(token) : null;
          allowed = !!share && shareIsLive(share, nowISO) && blobKeyBelongsToSet(key, share.setId);
        }
        if (!allowed) return json({ error: "unauthorized" }, 401);
        const object = await env.BUCKET.get(key);
        return object
          ? new Response(object.body, { status: 200, headers: CORS_HEADERS })
          : json({ error: "not found" }, 404);
      }

      if (request.method === "PUT") {
        if (!env.API_KEY) return json({ error: "API_KEY not configured" }, 503);
        if (!authed) return json({ error: "unauthorized" }, 401);
        await env.BUCKET.put(key, request.body);
        // Record the blob on its set so share resolution can point viewers at it.
        const setId = key.split("/")[0] ?? "";
        if (setId) await store.attachBlob(setId, key);
        return json(null, 201);
      }

      return json({ error: "method not allowed" }, 405);
    }

    // Everything except the public share surface requires the app key.
    if (!isPublicRoute(request.method, path)) {
      if (!env.API_KEY) return json({ error: "API_KEY not configured" }, 503);
      if (!authed) return json({ error: "unauthorized" }, 401);
    }

    // AI report (LLM-enhanced, deterministic fallback). Needs env + network, so
    // it lives here rather than the pure router.
    if (path === "/report" && request.method === "POST") {
      let facts;
      try {
        facts = parseReportFacts(await request.json());
      } catch {
        facts = null;
      }
      if (!facts) return json({ error: "expected { siteName, ... }" }, 400);
      if (!env.ANTHROPIC_API_KEY) {
        return json({ report: deterministicSummary(facts), source: "deterministic" }, 200);
      }
      try {
        const report = await generateNarrative(buildPrompt(facts), env.ANTHROPIC_API_KEY);
        return json({ report, source: "llm" }, 200);
      } catch {
        return json({ report: deterministicSummary(facts), source: "deterministic-fallback" }, 200);
      }
    }

    // JSON metadata endpoints.
    let body: unknown;
    if (request.method === "POST") {
      try {
        body = await request.json();
      } catch {
        body = undefined;
      }
    }
    const apiReq: ApiRequest = { method: request.method, path, body };
    const res = await route(apiReq, store);
    return json(res.body, res.status);
  },
};
