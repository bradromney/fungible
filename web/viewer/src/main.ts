import { PointCloudViewer } from "./pointCloudViewer";
import { formatPointCount } from "./format";

const canvas = document.getElementById("viewer") as HTMLCanvasElement | null;
const label = document.getElementById("count");

if (canvas) {
  const viewer = new PointCloudViewer(canvas);

  // Placeholder cloud until the COPC/Potree streaming loader is wired in.
  const count = 20_000;
  const positions = new Float32Array(count * 3);
  for (let i = 0; i < count; i += 1) {
    positions[i * 3 + 0] = (Math.random() - 0.5) * 4;
    positions[i * 3 + 1] = (Math.random() - 0.5) * 4;
    positions[i * 3 + 2] = (Math.random() - 0.5) * 4;
  }
  viewer.setPoints(positions);
  viewer.start();

  if (label) label.textContent = `${formatPointCount(count)} points`;
}
