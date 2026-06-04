// Pure conversion from a loaded point cloud's attribute mesh (loaders.gl shape)
// into the interleaved buffers three.js wants. Kept framework-free and
// structurally typed so it's unit-tested without pulling loaders.gl or a GPU,
// and so the LAS/LAZ/PLY loaders all funnel through one normalizer.

export interface AttributeArray {
  value: ArrayLike<number>;
  size?: number;
}

export interface LoadedAttributes {
  attributes: {
    POSITION: AttributeArray;
    COLOR_0?: AttributeArray;
  };
}

export interface PointData {
  positions: Float32Array;
  colors?: Float32Array; // rgb in [0,1], or undefined when the cloud has none
  count: number;
}

export function toPointData(loaded: LoadedAttributes): PointData {
  const pos = loaded.attributes.POSITION.value;
  const positions = pos instanceof Float32Array ? pos : Float32Array.from(pos);
  const count = Math.floor(positions.length / 3);

  let colors: Float32Array | undefined;
  const color = loaded.attributes.COLOR_0;
  if (color) {
    const v = color.value;
    // LAS colors are commonly 16-bit; 8-bit otherwise.
    const max = v instanceof Uint16Array ? 65535 : 255;
    const comps = color.size ?? 3;
    colors = new Float32Array(count * 3);
    for (let i = 0; i < count; i += 1) {
      colors[i * 3 + 0] = (v[i * comps + 0] ?? 0) / max;
      colors[i * 3 + 1] = (v[i * comps + 1] ?? 0) / max;
      colors[i * 3 + 2] = (v[i * comps + 2] ?? 0) / max;
    }
  }

  return { positions, colors, count };
}
