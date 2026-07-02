import { PointCloudViewer } from "./pointCloudViewer";
import { formatPointCount } from "./format";
import { loadLAS } from "./lasSource";
import { blobEndpoint, parseSharedSet, parseViewerRequest, shareEndpoint } from "./share";

const canvas = document.getElementById("viewer") as HTMLCanvasElement | null;
const label = document.getElementById("count");

function setLabel(text: string) {
  if (label) label.textContent = text;
}

if (canvas) {
  const viewer = new PointCloudViewer(canvas);
  viewer.start();

  // `?url=<las/laz>` loads a raw file; `?share=<token>[&api=<base>]` resolves a
  // Fungible share link through the API; otherwise show a placeholder cloud.
  const request = parseViewerRequest(location.search);

  const showCloud = (url: string, name?: string) => {
    setLabel("loading…");
    loadLAS(url)
      .then((pd) => {
        viewer.setPoints(pd.positions, pd.colors);
        const points = `${formatPointCount(pd.count)} points`;
        setLabel(name ? `${name} — ${points}` : points);
      })
      .catch((err) => {
        console.error(err);
        setLabel("load error");
      });
  };

  if (request.url) {
    showCloud(request.url);
  } else if (request.share) {
    const { token, api } = request.share;
    setLabel("resolving share…");
    fetch(shareEndpoint(api, token))
      .then(async (res) => {
        if (!res.ok) throw new Error(`share ${res.status}`);
        const set = parseSharedSet(await res.json());
        if (!set) throw new Error("malformed share record");
        if (set.blobKey) {
          showCloud(blobEndpoint(api, set.blobKey, token), set.name);
        } else {
          setLabel(`${set.name} — no scan uploaded yet`);
        }
      })
      .catch((err) => {
        console.error(err);
        setLabel("share link not found or expired");
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
    setLabel(`${formatPointCount(count)} points (demo)`);
  }
}
