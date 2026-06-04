import type { Store } from "./store";
import type { CreateSetBody, SetRecord, UploadTarget } from "./types";
import { route, type ApiRequest } from "./router";
import { buildPrompt, deterministicSummary, parseReportFacts } from "./report";

// Cloudflare Workers entry. Adapts real Request/Response around the pure `route`
// for JSON metadata endpoints, handles binary blob PUT/GET against R2 directly,
// and backs the Store with D1. This file is the only one touching the runtime;
// all the logic it calls is unit-tested (router.test.ts).

export interface Env {
  DB: D1Database;
  BUCKET: R2Bucket;
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

  async createShare(setId: string): Promise<string | null> {
    if (!(await this.getSet(setId))) return null;
    const token = crypto.randomUUID();
    await this.env.DB.prepare("INSERT INTO shares (token, set_id) VALUES (?, ?)").bind(token, setId).run();
    return token;
  }

  async resolveShare(token: string): Promise<SetRecord | null> {
    const row = await this.env.DB.prepare(
      "SELECT sets.* FROM sets JOIN shares ON shares.set_id = sets.id WHERE shares.token = ?"
    )
      .bind(token)
      .first<Record<string, unknown>>();
    return row ? rowToSet(row) : null;
  }

  async createUpload(setId: string, filename: string): Promise<UploadTarget | null> {
    if (!(await this.getSet(setId))) return null;
    const key = `${setId}/${filename}`;
    return { url: `/blobs/${key}`, key };
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

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // Binary blob transfer goes straight to R2 (not through the JSON router).
    if (path.startsWith("/blobs/")) {
      const key = path.slice("/blobs/".length);
      if (request.method === "PUT") {
        await env.BUCKET.put(key, request.body);
        return new Response(null, { status: 201 });
      }
      if (request.method === "GET") {
        const object = await env.BUCKET.get(key);
        return object ? new Response(object.body, { status: 200 }) : new Response("not found", { status: 404 });
      }
      return new Response("method not allowed", { status: 405 });
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
      if (!facts) return Response.json({ error: "expected { siteName, ... }" }, { status: 400 });
      if (!env.ANTHROPIC_API_KEY) {
        return Response.json({ report: deterministicSummary(facts), source: "deterministic" });
      }
      try {
        const report = await generateNarrative(buildPrompt(facts), env.ANTHROPIC_API_KEY);
        return Response.json({ report, source: "llm" });
      } catch {
        return Response.json({ report: deterministicSummary(facts), source: "deterministic-fallback" });
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
    const res = await route(apiReq, new D1Store(env));
    return Response.json(res.body, { status: res.status });
  },
};
