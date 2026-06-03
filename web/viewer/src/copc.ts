// Streaming-loader seam. COPC is a single LAZ-1.4 file with an octree; the
// viewer fetches octree nodes with HTTP Range requests rather than downloading
// the whole cloud. These pure helpers (the byte-range header and the share
// manifest) are what the loader will build on; they're unit-tested so the
// transport contract is pinned before the heavier potree-core/loaders.gl
// integration lands.

export interface ScanBounds {
  min: [number, number, number];
  max: [number, number, number];
}

/** Metadata for a shared scan the viewer loads. */
export interface ScanManifest {
  id: string;
  name: string;
  /** URL of the COPC file (range-readable). */
  url: string;
  pointCount: number;
  bounds: ScanBounds;
}

/** Build an HTTP Range header value for a byte window. */
export function rangeHeader(offset: number, length: number): string {
  if (!Number.isInteger(offset) || offset < 0) throw new Error(`invalid offset: ${offset}`);
  if (!Number.isInteger(length) || length <= 0) throw new Error(`invalid length: ${length}`);
  return `bytes=${offset}-${offset + length - 1}`;
}

/** The diagonal size of a scan's bounding box (handy for camera framing). */
export function boundsDiagonal(bounds: ScanBounds): number {
  const dx = bounds.max[0] - bounds.min[0];
  const dy = bounds.max[1] - bounds.min[1];
  const dz = bounds.max[2] - bounds.min[2];
  return Math.sqrt(dx * dx + dy * dy + dz * dz);
}

/** Parse + validate a manifest from untrusted JSON. */
export function parseManifest(input: unknown): ScanManifest {
  if (typeof input !== "object" || input === null) throw new Error("manifest must be an object");
  const o = input as Record<string, unknown>;
  const str = (k: string): string => {
    if (typeof o[k] !== "string") throw new Error(`manifest.${k} must be a string`);
    return o[k] as string;
  };
  const triple = (v: unknown, k: string): [number, number, number] => {
    if (!Array.isArray(v) || v.length !== 3 || !v.every((n) => typeof n === "number")) {
      throw new Error(`manifest.${k} must be [number, number, number]`);
    }
    return v as [number, number, number];
  };
  const bounds = o.bounds as Record<string, unknown> | undefined;
  if (!bounds) throw new Error("manifest.bounds is required");
  if (typeof o.pointCount !== "number") throw new Error("manifest.pointCount must be a number");

  return {
    id: str("id"),
    name: str("name"),
    url: str("url"),
    pointCount: o.pointCount,
    bounds: { min: triple(bounds.min, "bounds.min"), max: triple(bounds.max, "bounds.max") },
  };
}
