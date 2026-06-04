import { describe, it, expect } from "vitest";
import { deterministicSummary, buildPrompt, netVolume, parseReportFacts } from "./report";

describe("netVolume", () => {
  it("is fill minus cut, undefined when no volumes", () => {
    expect(netVolume({ siteName: "x", cutVolume: 5, fillVolume: 47 })).toBe(42);
    expect(netVolume({ siteName: "x", areaSquareMeters: 10 })).toBeUndefined();
  });
});

describe("deterministicSummary", () => {
  it("states metric numbers and truckloads", () => {
    const s = deterministicSummary({ siteName: "North Lot", areaSquareMeters: 350, cutVolume: 5, fillVolume: 47, pointCount: 1000 });
    expect(s).toContain("North Lot:");
    expect(s).toContain("net fill of 42.0 m³");
    expect(s).toContain("350.0 m²");
    expect(s).toContain("truckload");
    expect(s).toContain("1000 points");
  });

  it("renders imperial in yd³/ft²", () => {
    const s = deterministicSummary({ siteName: "Grade", areaSquareMeters: 100, fillVolume: 42, units: "imperial" });
    expect(s).toContain("54.9 yd³");
    expect(s).toContain("1076.4 ft²");
    expect(s).not.toContain("m³");
  });
});

describe("buildPrompt", () => {
  it("is facts-only and includes the numbers", () => {
    const p = buildPrompt({ siteName: "Site", cutVolume: 5.2, fillVolume: 47 });
    expect(p).toContain("Use ONLY the measured facts");
    expect(p).toContain("- Cut: 5.2 m³");
    expect(p).toContain("- Fill: 47.0 m³");
  });
});

describe("parseReportFacts", () => {
  it("requires a siteName and coerces numbers", () => {
    expect(parseReportFacts({})).toBeNull();
    expect(parseReportFacts(null)).toBeNull();
    const f = parseReportFacts({ siteName: "S", fillVolume: 10, units: "imperial" });
    expect(f?.siteName).toBe("S");
    expect(f?.fillVolume).toBe(10);
    expect(f?.units).toBe("imperial");
  });
});
