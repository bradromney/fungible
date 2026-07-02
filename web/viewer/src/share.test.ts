import { describe, it, expect } from "vitest";
import { blobEndpoint, parseSharedSet, parseViewerRequest, shareEndpoint } from "./share";

describe("parseViewerRequest", () => {
  it("prefers a raw url, then a share token, then nothing", () => {
    expect(parseViewerRequest("?url=https://x/scan.laz")).toEqual({ url: "https://x/scan.laz" });
    expect(parseViewerRequest("?share=tok&api=https://api.example.com/")).toEqual({
      share: { token: "tok", api: "https://api.example.com" },
    });
    // url wins when both are present (existing behavior stays intact).
    expect(parseViewerRequest("?url=f.laz&share=tok").url).toBe("f.laz");
    expect(parseViewerRequest("")).toEqual({});
  });

  it("defaults the api base to same-origin", () => {
    expect(parseViewerRequest("?share=tok")).toEqual({ share: { token: "tok", api: "" } });
  });
});

describe("endpoints", () => {
  it("builds the share and blob URLs the API serves", () => {
    expect(shareEndpoint("https://api.example.com", "tok-1")).toBe("https://api.example.com/share/tok-1");
    expect(blobEndpoint("", "set-9/scan.copc.laz", "tok-1")).toBe("/blobs/set-9/scan.copc.laz?share=tok-1");
  });

  it("escapes hostile tokens but preserves the key's path shape", () => {
    expect(shareEndpoint("", "a/../b")).toBe("/share/a%2F..%2Fb");
    expect(blobEndpoint("", "set 1/my scan.laz", "t")).toBe("/blobs/set%201/my%20scan.laz?share=t");
  });
});

describe("parseSharedSet", () => {
  it("accepts a well-formed SetRecord", () => {
    const set = parseSharedSet({ id: "s1", name: "Backyard", pointCount: 42, blobKey: "s1/scan.laz" });
    expect(set).toEqual({ id: "s1", name: "Backyard", pointCount: 42, blobKey: "s1/scan.laz" });
  });

  it("tolerates a missing blobKey/pointCount (metadata-only share)", () => {
    expect(parseSharedSet({ id: "s1", name: "Empty" })).toEqual({ id: "s1", name: "Empty", pointCount: 0 });
  });

  it("rejects malformed bodies", () => {
    expect(parseSharedSet(null)).toBeNull();
    expect(parseSharedSet("nope")).toBeNull();
    expect(parseSharedSet({ name: "no id" })).toBeNull();
    expect(parseSharedSet({ id: "", name: "empty id" })).toBeNull();
  });
});
