import { describe, it, expect } from "vitest";
import { bearerMatches, blobKeyBelongsToSet, extractBearer, isPublicRoute, shareIsLive } from "./auth";

describe("isPublicRoute", () => {
  it("keeps share resolution public and everything else private", () => {
    expect(isPublicRoute("GET", "/share/abc")).toBe(true);
    expect(isPublicRoute("OPTIONS", "/sets")).toBe(true); // CORS preflight
    expect(isPublicRoute("DELETE", "/share/abc")).toBe(false); // revocation is a write
    expect(isPublicRoute("GET", "/sets/abc")).toBe(false);
    expect(isPublicRoute("POST", "/sets")).toBe(false);
    expect(isPublicRoute("POST", "/report")).toBe(false);
    expect(isPublicRoute("GET", "/share/abc/extra")).toBe(false);
  });
});

describe("extractBearer", () => {
  it("parses well-formed headers and rejects the rest", () => {
    expect(extractBearer("Bearer k-123")).toBe("k-123");
    expect(extractBearer(null)).toBeNull();
    expect(extractBearer("Basic dXNlcg==")).toBeNull();
    expect(extractBearer("Bearer")).toBeNull();
    expect(extractBearer("Bearer two tokens")).toBeNull();
  });
});

describe("bearerMatches", () => {
  it("only matches the exact configured key", () => {
    expect(bearerMatches("secret", "secret")).toBe(true);
    expect(bearerMatches("secret", "Secret")).toBe(false);
    expect(bearerMatches("secre", "secret")).toBe(false);
    expect(bearerMatches(null, "secret")).toBe(false);
    // No configured key must never authenticate anything (fail closed).
    expect(bearerMatches("anything", undefined)).toBe(false);
    expect(bearerMatches("", "")).toBe(false);
  });
});

describe("blobKeyBelongsToSet", () => {
  it("authorizes only keys under the set's prefix", () => {
    expect(blobKeyBelongsToSet("set-1/scan.copc.laz", "set-1")).toBe(true);
    expect(blobKeyBelongsToSet("set-10/scan.copc.laz", "set-1")).toBe(false);
    expect(blobKeyBelongsToSet("set-1", "set-1")).toBe(false); // no filename
    expect(blobKeyBelongsToSet("other/scan.laz", "set-1")).toBe(false);
    expect(blobKeyBelongsToSet("x/y", "")).toBe(false);
  });
});

describe("shareIsLive", () => {
  const now = "2026-07-02T12:00:00.000Z";
  it("honors revocation and expiry", () => {
    expect(shareIsLive({}, now)).toBe(true);
    expect(shareIsLive({ revoked: true }, now)).toBe(false);
    expect(shareIsLive({ expiresAt: "2026-07-03T00:00:00.000Z" }, now)).toBe(true);
    expect(shareIsLive({ expiresAt: "2026-07-01T00:00:00.000Z" }, now)).toBe(false);
    expect(shareIsLive({ expiresAt: "2026-07-03T00:00:00.000Z", revoked: true }, now)).toBe(false);
  });
});
