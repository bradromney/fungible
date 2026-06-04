import type { CreateSetBody, SetRecord, UploadTarget } from "./types";

// Storage abstraction the request logic depends on. The Workers entry (index.ts)
// implements this over D1 + R2; tests use InMemoryStore. Keeping handlers behind
// this interface is what makes the routing logic unit-testable without the
// Cloudflare runtime.
export interface Store {
  createSet(input: CreateSetBody): Promise<SetRecord>;
  getSet(id: string): Promise<SetRecord | null>;
  /** Returns a share token, or null if the set doesn't exist. */
  createShare(setId: string): Promise<string | null>;
  resolveShare(token: string): Promise<SetRecord | null>;
  /** Returns where to PUT the blob, or null if the set doesn't exist. */
  createUpload(setId: string, filename: string): Promise<UploadTarget | null>;
}

/** Deterministic in-memory store for tests and local dev. */
export class InMemoryStore implements Store {
  private sets = new Map<string, SetRecord>();
  private shares = new Map<string, string>(); // token -> setId
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

  async createShare(setId: string): Promise<string | null> {
    if (!this.sets.has(setId)) return null;
    this.seq += 1;
    const token = `share-${this.seq}`;
    this.shares.set(token, setId);
    return token;
  }

  async resolveShare(token: string): Promise<SetRecord | null> {
    const setId = this.shares.get(token);
    return setId ? (this.sets.get(setId) ?? null) : null;
  }

  async createUpload(setId: string, filename: string): Promise<UploadTarget | null> {
    if (!this.sets.has(setId)) return null;
    const key = `${setId}/${filename}`;
    return { url: `/blobs/${key}`, key };
  }
}
