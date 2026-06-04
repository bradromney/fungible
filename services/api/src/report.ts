// Server-side report generation, mirroring the on-device FungibleInsights module
// so shared sets / the web viewer can produce reports too. Pure functions
// (deterministic summary + LLM prompt) live here and are unit-tested; the actual
// Claude API call lives in index.ts (it needs network + the secret key) and
// always falls back to `deterministicSummary` — AI as enhancement, never a
// dependency.

export interface ReportFacts {
  siteName: string;
  areaSquareMeters?: number;
  cutVolume?: number;
  fillVolume?: number;
  pointCount?: number;
  units?: "metric" | "imperial";
  truckCapacityCubicMeters?: number;
}

const CUBIC_YARDS_PER_CUBIC_METER = 1.307950619314392;
const SQ_FEET_PER_SQ_METER = 10.763910416709722;

function fmt(v: number): string {
  return v.toFixed(1);
}
function vol(m3: number, units: string): string {
  return units === "imperial" ? `${fmt(m3 * CUBIC_YARDS_PER_CUBIC_METER)} yd³` : `${fmt(m3)} m³`;
}
function area(m2: number, units: string): string {
  return units === "imperial" ? `${fmt(m2 * SQ_FEET_PER_SQ_METER)} ft²` : `${fmt(m2)} m²`;
}
function truckloads(volume: number | undefined, capacity: number): number {
  if (!volume || volume <= 0 || capacity <= 0) return 0;
  return Math.ceil(volume / capacity);
}

export function netVolume(f: ReportFacts): number | undefined {
  if (f.cutVolume === undefined && f.fillVolume === undefined) return undefined;
  return (f.fillVolume ?? 0) - (f.cutVolume ?? 0);
}

export function deterministicSummary(f: ReportFacts): string {
  const units = f.units ?? "metric";
  const cap = f.truckCapacityCubicMeters ?? 10;
  const parts: string[] = [`${f.siteName}:`];
  const net = netVolume(f);

  if (net !== undefined) {
    parts.push(`${net >= 0 ? "net fill" : "net cut"} of ${vol(Math.abs(net), units)}`);
    if (f.areaSquareMeters !== undefined) parts.push(`over ${area(f.areaSquareMeters, units)}`);
    parts.push(`(cut ${vol(f.cutVolume ?? 0, units)}, fill ${vol(f.fillVolume ?? 0, units)}).`);
    const fillLoads = truckloads(f.fillVolume, cap);
    if (fillLoads > 0) parts.push(`Fill ≈ ${fillLoads} truckload${fillLoads === 1 ? "" : "s"}.`);
  } else if (f.areaSquareMeters !== undefined) {
    parts.push(`plan area ${area(f.areaSquareMeters, units)}.`);
  }
  if (f.pointCount && f.pointCount > 0) parts.push(`Captured from ${f.pointCount} points.`);
  return parts.join(" ");
}

export function buildPrompt(f: ReportFacts): string {
  const units = f.units ?? "metric";
  const lines = [
    "Write a concise, client-ready site summary for a construction/landscaping/3D-capture professional.",
    "Use ONLY the measured facts below — do not invent numbers. 2–3 sentences then a short bulleted next-steps list.",
    "",
    "Facts:",
    `- Site: ${f.siteName}`,
  ];
  if (f.areaSquareMeters !== undefined) lines.push(`- Plan area: ${area(f.areaSquareMeters, units)}`);
  if (f.cutVolume !== undefined) lines.push(`- Cut: ${vol(f.cutVolume, units)}`);
  if (f.fillVolume !== undefined) lines.push(`- Fill: ${vol(f.fillVolume, units)}`);
  const net = netVolume(f);
  if (net !== undefined) lines.push(`- Net: ${vol(Math.abs(net), units)} (${net >= 0 ? "fill" : "cut"})`);
  if (f.pointCount) lines.push(`- Point count: ${f.pointCount}`);
  return lines.join("\n");
}

export function parseReportFacts(body: unknown): ReportFacts | null {
  if (typeof body !== "object" || body === null) return null;
  const o = body as Record<string, unknown>;
  if (typeof o.siteName !== "string" || o.siteName.length === 0) return null;
  const num = (k: string): number | undefined => (typeof o[k] === "number" ? (o[k] as number) : undefined);
  const units = o.units === "imperial" ? "imperial" : o.units === "metric" ? "metric" : undefined;
  return {
    siteName: o.siteName,
    areaSquareMeters: num("areaSquareMeters"),
    cutVolume: num("cutVolume"),
    fillVolume: num("fillVolume"),
    pointCount: num("pointCount"),
    units,
    truckCapacityCubicMeters: num("truckCapacityCubicMeters"),
  };
}
