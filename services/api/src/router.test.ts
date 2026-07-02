import { describe, it, expect } from "vitest";
import { route } from "./router";
import { InMemoryStore } from "./store";
import type { SetRecord } from "./types";

function store() {
  return new InMemoryStore();
}

describe("POST /sets", () => {
  it("creates a set", async () => {
    const res = await route({ method: "POST", path: "/sets", body: { name: "Backyard", pointCount: 100 } }, store());
    expect(res.status).toBe(201);
    expect((res.body as SetRecord).name).toBe("Backyard");
    expect((res.body as SetRecord).pointCount).toBe(100);
  });

  it("rejects a missing name", async () => {
    const res = await route({ method: "POST", path: "/sets", body: {} }, store());
    expect(res.status).toBe(400);
  });
});

describe("GET /sets/:id", () => {
  it("returns a created set, 404 otherwise", async () => {
    const s = store();
    const created = await route({ method: "POST", path: "/sets", body: { name: "Site" } }, s);
    const id = (created.body as SetRecord).id;
    expect((await route({ method: "GET", path: `/sets/${id}`, body: undefined }, s)).status).toBe(200);
    expect((await route({ method: "GET", path: "/sets/nope", body: undefined }, s)).status).toBe(404);
  });
});

describe("share flow", () => {
  it("creates a share token and resolves it back to the set", async () => {
    const s = store();
    const set = (await route({ method: "POST", path: "/sets", body: { name: "Shared" } }, s)).body as SetRecord;

    const shareRes = await route({ method: "POST", path: `/sets/${set.id}/share`, body: undefined }, s);
    expect(shareRes.status).toBe(201);
    const token = (shareRes.body as { token: string }).token;

    const resolved = await route({ method: "GET", path: `/share/${token}`, body: undefined }, s);
    expect(resolved.status).toBe(200);
    expect((resolved.body as SetRecord).id).toBe(set.id);
  });

  it("404s sharing a missing set and resolving a bad token", async () => {
    const s = store();
    expect((await route({ method: "POST", path: "/sets/missing/share", body: undefined }, s)).status).toBe(404);
    expect((await route({ method: "GET", path: "/share/bad", body: undefined }, s)).status).toBe(404);
  });

  it("expires a share after its window and rejects a bad expiry body", async () => {
    const s = store();
    const set = (await route({ method: "POST", path: "/sets", body: { name: "Timed" } }, s)).body as SetRecord;

    const minted = new Date("2026-07-01T00:00:00.000Z");
    const shareRes = await route(
      { method: "POST", path: `/sets/${set.id}/share`, body: { expiresInDays: 7 } },
      s,
      minted
    );
    expect(shareRes.status).toBe(201);
    const { token, expiresAt } = shareRes.body as { token: string; expiresAt: string };
    expect(expiresAt).toBe("2026-07-08T00:00:00.000Z");

    const day6 = new Date("2026-07-07T00:00:00.000Z");
    const day8 = new Date("2026-07-09T00:00:00.000Z");
    expect((await route({ method: "GET", path: `/share/${token}`, body: undefined }, s, day6)).status).toBe(200);
    expect((await route({ method: "GET", path: `/share/${token}`, body: undefined }, s, day8)).status).toBe(404);

    const bad = await route({ method: "POST", path: `/sets/${set.id}/share`, body: { expiresInDays: -1 } }, s);
    expect(bad.status).toBe(400);
  });

  it("revokes a share so it stops resolving", async () => {
    const s = store();
    const set = (await route({ method: "POST", path: "/sets", body: { name: "Revocable" } }, s)).body as SetRecord;
    const { token } = (await route({ method: "POST", path: `/sets/${set.id}/share`, body: undefined }, s)).body as {
      token: string;
    };

    expect((await route({ method: "GET", path: `/share/${token}`, body: undefined }, s)).status).toBe(200);
    expect((await route({ method: "DELETE", path: `/share/${token}`, body: undefined }, s)).status).toBe(204);
    expect((await route({ method: "GET", path: `/share/${token}`, body: undefined }, s)).status).toBe(404);
    expect((await route({ method: "DELETE", path: "/share/unknown", body: undefined }, s)).status).toBe(404);
  });
});

describe("uploads", () => {
  it("returns an upload target keyed under the set", async () => {
    const s = store();
    const set = (await route({ method: "POST", path: "/sets", body: { name: "Up" } }, s)).body as SetRecord;
    const res = await route({ method: "POST", path: `/sets/${set.id}/uploads`, body: { filename: "scan.copc.laz" } }, s);
    expect(res.status).toBe(201);
    expect((res.body as { key: string }).key).toBe(`${set.id}/scan.copc.laz`);
  });

  it("rejects a missing filename", async () => {
    const s = store();
    const set = (await route({ method: "POST", path: "/sets", body: { name: "Up" } }, s)).body as SetRecord;
    expect((await route({ method: "POST", path: `/sets/${set.id}/uploads`, body: {} }, s)).status).toBe(400);
  });
});

describe("unknown routes", () => {
  it("404s", async () => {
    expect((await route({ method: "GET", path: "/", body: undefined }, store())).status).toBe(404);
    expect((await route({ method: "DELETE", path: "/sets/x", body: undefined }, store())).status).toBe(404);
  });
});
