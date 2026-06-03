// Pure display helpers (unit-tested). No DOM/three dependency.

/** Human-readable point count: 500 → "500", 1500 → "1.5K", 2.5e6 → "2.5M". */
export function formatPointCount(n: number): string {
  if (n < 1_000) return `${n}`;
  if (n < 1_000_000) return `${(n / 1_000).toFixed(1)}K`;
  if (n < 1_000_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  return `${(n / 1_000_000_000).toFixed(1)}B`;
}

/** Human-readable byte size: 512 → "512 B", 1536 → "1.5 KB". */
export function formatFileSize(bytes: number): string {
  const units = ["B", "KB", "MB", "GB", "TB"];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  const text = unit === 0 ? `${value}` : value.toFixed(1);
  return `${text} ${units[unit]}`;
}
