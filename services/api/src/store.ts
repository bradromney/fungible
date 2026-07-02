import type { CreateSetBody, SetRecord, ShareInfo, UploadTarget } from "./types";
import { shareIsLive } from "./auth";

// Storage abstraction the request logic depends on. The Workers entry (index.ts)
// implements this over D1 + R2; tests use InMemoryStore. Keeping handlers behind
// this interface is what makes the routing logic unit-testable without the
// Cloudflare runtime.
export interface Store {
  createSet(input: CreateSetBody): Promise<SetRecord>;
  getSet(id: string): Promise<SetRecord | null>;
  /** Returns the share token (+ optional expiry), or null if the set doesn't exist. */
  createShare(setId: string, expiresAt?: string): Promise<ShareInfo | null>;
  /** Resolves a live (unrevoked, unexpired as of `nowISO`) share to its set. */
  resolveShare(token: string, nowISO: string): Promise<SetRecord | null>;
  /** Marks a share revoked. Returns false if the token doesn't exist. */
  revokeShare(token: string): Promise<boolean>;
  /** Returns where to PUT the blob, or null if the set doesn't exist. */
  createUpload(setId: string, filename: string): Promise<UploadTarget | null>;
  /** Records the uploaded blob's key on its set so shares can reach it. */
  attachBlob(setId: string, key: string): Promise<boolean>;
}

interface ShareRow {
  setId: string;
  expiresAt?: string;
  revoked?: boolean;
}

/** Deterministic in-memory store for tests and local dev. */
export class InMemoryStore implements Store {
  private sets = new Map<string, SetRecord>();
  private shares = new Map<string, ShareRow>();
  private seq = 0;

  async createSet(input: CreateSetBody): Promise<SetRecord> {
    this.seq += 1;
    const record: SetRecord = {
      id: `set-${this.seq}`,
      name: input.name,
      createdAt: "1970-01-01T00:00:00.000Z",
      pointCount: input.pointCount ?? 0,
      bounds: input.bounds,
    };
    this.sets.set(record.id, record);
    return record;
  }

  async getSet(id: string): Promise<SetRecord | null> {
    return this.sets.get(id) ?? null;
  }

  async createShare(setId: string, expiresAt?: string): Promise<ShareInfo | null> {
    if (!this.sets.has(setId)) return null;
    this.seq += 1;
    const token = `share-${this.seq}`;
    this.shares.set(token, { setId, expiresAt });
    return { token, expiresAt };
  }

  async resolveShare(token: string, nowISO: string): Promise<SetRecord | null> {
    const share = this.shares.get(token);
    if (!share || !shareIsLive(share, nowISO)) return null;
    return this.sets.get(share.setId) ?? null;
  }

  async revokeShare(token: string): Promise<boolean> {
    const share = this.shares.get(token);
    if (!share) return false;
    share.revoked = true;
    return true;
  }

  async createUpload(setId: string, filename: string): Promise<UploadTarget | null> {
    if (!this.sets.has(setId)) return null;
    const key = `${setId}/${filename}`;
    return { url: `/blobs/${key}`, key };
  }

  async attachBlob(setId: string, key: string): Promise<boolean> {
    const set = this.sets.get(setId);
    if (!set) return false;
    set.blobKey = key;
    return true;
  }
}
