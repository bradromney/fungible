import { load } from "@loaders.gl/core";
import { LASLoader } from "@loaders.gl/las";
import { toPointData, type LoadedAttributes, type PointData } from "./pointData";

// DOM/network edge: fetch + parse a LAS/LAZ file via loaders.gl and hand back the
// pure PointData buffers. (LAZ uses loaders.gl's bundled laz-perf wasm.) The
// COPC/Potree streaming path will layer range-read tiling on top of this same
// normalizer.
export async function loadLAS(url: string): Promise<PointData> {
  const data = await load(url, LASLoader);
  return toPointData(data as unknown as LoadedAttributes);
}
