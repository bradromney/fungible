// Wire types for the Fungible sync/share API. Kept framework-free so the
// request logic is unit-tested without the Cloudflare Workers runtime.

export interface Bounds {
  min: [number, number, number];
  max: [number, number, number];
}

export interface SetRecord {
  id: string;
  name: string;
  createdAt: string; // ISO-8601
  pointCount: number;
  bounds?: Bounds;
  /** R2 object key of the merged COPC/LAS blob, once uploaded. */
  blobKey?: string;
}

export interface CreateSetBody {
  name: string;
  pointCount?: number;
  bounds?: Bounds;
}

export interface ShareInfo {
  token: string;
  /** ISO-8601 instant after which the link stops resolving; absent = no expiry. */
  expiresAt?: string;
}

export interface CreateShareBody {
  /** Days until the link expires (measured from `now`); absent = no expiry. */
  expiresInDays?: number;
}

export interface UploadTarget {
  /** Where the client PUTs the blob (presigned URL or a Worker route). */
  url: string;
  /** The object key the blob will live at. */
  key: string;
}

export interface ApiResponse {
  status: number;
  body: unknown;
}

export function ok(body: unknown): ApiResponse {
  return { status: 200, body };
}
export function created(body: unknown): ApiResponse {
  return { status: 201, body };
}
export function badRequest(message: string): ApiResponse {
  return { status: 400, body: { error: message } };
}
export function notFound(message = "not found"): ApiResponse {
  return { status: 404, body: { error: message } };
}
export function noContent(): ApiResponse {
  return { status: 204, body: null };
}
