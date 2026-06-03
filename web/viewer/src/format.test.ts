import { describe, it, expect } from "vitest";
import { formatPointCount, formatFileSize } from "./format";

describe("formatPointCount", () => {
  it("leaves small counts as-is", () => {
    expect(formatPointCount(0)).toBe("0");
    expect(formatPointCount(500)).toBe("500");
  });
  it("abbreviates thousands and millions", () => {
    expect(formatPointCount(1_500)).toBe("1.5K");
    expect(formatPointCount(2_500_000)).toBe("2.5M");
    expect(formatPointCount(3_200_000_000)).toBe("3.2B");
  });
});

describe("formatFileSize", () => {
  it("formats bytes through gigabytes", () => {
    expect(formatFileSize(512)).toBe("512 B");
    expect(formatFileSize(1_536)).toBe("1.5 KB");
    expect(formatFileSize(1_048_576)).toBe("1.0 MB");
    expect(formatFileSize(1_610_612_736)).toBe("1.5 GB");
  });
});
