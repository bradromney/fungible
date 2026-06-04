import { describe, it, expect } from "vitest";
import { toPointData, type LoadedAttributes } from "./pointData";

describe("toPointData", () => {
  it("passes positions through and counts points", () => {
    const loaded: LoadedAttributes = {
      attributes: { POSITION: { value: new Float32Array([0, 0, 0, 1, 2, 3]), size: 3 } },
    };
    const pd = toPointData(loaded);
    expect(pd.count).toBe(2);
    expect(Array.from(pd.positions.slice(3))).toEqual([1, 2, 3]);
    expect(pd.colors).toBeUndefined();
  });

  it("normalizes 16-bit LAS colors to [0,1]", () => {
    const loaded: LoadedAttributes = {
      attributes: {
        POSITION: { value: new Float32Array([0, 0, 0, 1, 1, 1]), size: 3 },
        COLOR_0: { value: new Uint16Array([65535, 0, 0, 0, 65535, 0]), size: 3 },
      },
    };
    const pd = toPointData(loaded);
    expect(pd.colors).toBeDefined();
    expect(Array.from(pd.colors!)).toEqual([1, 0, 0, 0, 1, 0]);
  });

  it("normalizes 8-bit colors and handles RGBA stride", () => {
    const loaded: LoadedAttributes = {
      attributes: {
        POSITION: { value: new Float32Array([0, 0, 0]), size: 3 },
        COLOR_0: { value: new Uint8Array([255, 128, 0, 255]), size: 4 },
      },
    };
    const pd = toPointData(loaded);
    expect(pd.colors![0]).toBeCloseTo(1, 5);
    expect(pd.colors![1]).toBeCloseTo(128 / 255, 5);
    expect(pd.colors![2]).toBe(0);
  });
});
