import { PointCloudViewer } from "./pointCloudViewer";
import { formatPointCount } from "./format";
import { loadLAS } from "./lasSource";

const canvas = document.getElementById("viewer") as HTMLCanvasElement | null;
const label = document.getElementById("count");

if (canvas) {
  const viewer = new PointCloudViewer(canvas);
  viewer.start();

  // `?url=<las/laz>` loads a real scan; otherwise show a placeholder cloud.
  const url = new URLSearchParams(location.search).get("url");
  if (url) {
    if (label) label.textContent = "loading…";
    loadLAS(url)
      .then((pd) => {
        viewer.setPoints(pd.positions, pd.colors);
        if (label) label.textContent = `${formatPointCount(pd.count)} points`;
      })
      .catch((err) => {
        console.error(err);
        if (label) label.textContent = "load error";
      });
  } else {
    const count = 20_000;
    const positions = new Float32Array(count * 3);
    for (let i = 0; i < count; i += 1) {
      positions[i * 3 + 0] = (Math.random() - 0.5) * 4;
      positions[i * 3 + 1] = (Math.random() - 0.5) * 4;
      positions[i * 3 + 2] = (Math.random() - 0.5) * 4;
    }
    viewer.setPoints(positions);
    if (label) label.textContent = `${formatPointCount(count)} points (demo)`;
  }
}
