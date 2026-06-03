import { describe, it, expect } from "vitest";
import { rangeHeader, boundsDiagonal, parseManifest } from "./copc";

describe("rangeHeader", () => {
  it("builds an inclusive byte range", () => {
    expect(rangeHeader(0, 100)).toBe("bytes=0-99");
    expect(rangeHeader(2048, 512)).toBe("bytes=2048-2559");
  });
  it("rejects invalid windows", () => {
    expect(() => rangeHeader(-1, 10)).toThrow();
    expect(() => rangeHeader(0, 0)).toThrow();
    expect(() => rangeHeader(1.5, 10)).toThrow();
  });
});

describe("boundsDiagonal", () => {
  it("computes the bbox diagonal", () => {
    expect(boundsDiagonal({ min: [0, 0, 0], max: [3, 0, 4] })).toBe(5);
  });
});

describe("parseManifest", () => {
  const valid = {
    id: "site-1",
    name: "Backyard",
    url: "https://cdn.example/site-1.copc.laz",
    pointCount: 1_234_567,
    bounds: { min: [0, 0, 0], max: [10, 2, 8] },
  };

  it("accepts a well-formed manifest", () => {
    const m = parseManifest(valid);
    expect(m.id).toBe("site-1");
    expect(m.pointCount).toBe(1_234_567);
    expect(m.bounds.max[0]).toBe(10);
  });

  it("rejects malformed input", () => {
    expect(() => parseManifest(null)).toThrow();
    expect(() => parseManifest({ ...valid, pointCount: "lots" })).toThrow();
    expect(() => parseManifest({ ...valid, bounds: { min: [0, 0], max: [1, 1, 1] } })).toThrow();
    expect(() => parseManifest({ ...valid, url: 42 })).toThrow();
  });
});
