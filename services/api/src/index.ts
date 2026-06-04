import type { Store } from "./store";
import type { CreateSetBody, SetRecord, UploadTarget } from "./types";
import { route, type ApiRequest } from "./router";

// Cloudflare Workers entry. Adapts real Request/Response around the pure `route`
// for JSON metadata endpoints, handles binary blob PUT/GET against R2 directly,
// and backs the Store with D1. This file is the only one touching the runtime;
// all the logic it calls is unit-tested (router.test.ts).

export interface Env {
  DB: D1Database;
  BUCKET: R2Bucket;
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
