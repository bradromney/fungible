// Share-link resolution (pure, unit-tested): turn the viewer's URL parameters
// into API endpoints and validate what the API returns. The DOM/network edge
// (main.ts) does the actual fetching. Contract matches services/api:
//   GET  <api>/share/<token>            -> SetRecord {id,name,pointCount,blobKey?}
//   GET  <api>/blobs/<blobKey>?share=…  -> the set's LAS/LAZ/COPC blob
// The share token authorizes the blob read, so a link works with no credentials.

/** What the viewer was asked to show. `url` (a raw file) wins over `share`
 *  to preserve the original `?url=` behavior; neither = demo cloud. */
export interface ViewerRequest {
  url?: string;
  share?: { token: string; api: string };
}

/** Parse `location.search`. `api` defaults to same-origin (empty base). */
export function parseViewerRequest(search: string): ViewerRequest {
  const params = new URLSearchParams(search);
  const url = params.get("url");
  if (url) return { url };
  const token = params.get("share");
  if (token) return { share: { token, api: normalizeApiBase(params.get("api") ?? "") } };
  return {};
}

/** Trim a trailing slash so endpoint building is unambiguous. */
export function normalizeApiBase(api: string): string {
  return api.endsWith("/") ? api.slice(0, -1) : api;
}

export function shareEndpoint(api: string, token: string): string {
  return `${api}/share/${encodeURIComponent(token)}`;
}

/** Blob keys contain a path separator (`setId/filename`) that must survive. */
export function blobEndpoint(api: string, blobKey: string, token: string): string {
  const path = blobKey.split("/").map(encodeURIComponent).join("/");
  return `${api}/blobs/${path}?share=${encodeURIComponent(token)}`;
}

/** The share surface's SetRecord, as much of it as the viewer needs. */
export interface SharedSet {
  id: string;
  name: string;
  pointCount: number;
  blobKey?: string;
}

/** Validate an API response body; null for anything malformed. */
export function parseSharedSet(body: unknown): SharedSet | null {
  if (typeof body !== "object" || body === null) return null;
  const o = body as Record<string, unknown>;
  if (typeof o.id !== "string" || o.id.length === 0) return null;
  if (typeof o.name !== "string") return null;
  const set: SharedSet = {
    id: o.id,
    name: o.name,
    pointCount: typeof o.pointCount === "number" ? o.pointCount : 0,
  };
  if (typeof o.blobKey === "string" && o.blobKey.length > 0) set.blobKey = o.blobKey;
  return set;
}
