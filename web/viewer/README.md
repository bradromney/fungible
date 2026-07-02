# Fungible web viewer

Browser viewer for sharing scans and desktop site planning. Today it's a small
**Vite + TypeScript + three.js** points renderer; the planned path (see the
[research dossier](../../docs/research/open-source-components.md#5-web-point-cloud-viewer-sharing--desktop-planning))
is to stream **COPC** (single file, HTTP range reads) or **Potree/EPT** tiles via
**potree-core + loaders.gl**, with measurement and annotation tools — all
permissively licensed (BSD/MIT).

## Develop

```sh
cd web/viewer
npm install
npm run dev         # local dev server
npm run typecheck   # tsc --noEmit
npm test            # vitest
```

CI runs `typecheck` + `test` on every push.

## Loading a scan

Pass a LAS/LAZ URL: `index.html?url=https://…/scan.laz`, or a Fungible share
link: `index.html?share=<token>&api=https://<worker-host>` — the viewer resolves
`GET <api>/share/<token>` and streams the set's blob with the same token (no
credentials needed; expired/revoked links show a friendly error). With no `url` it shows a
placeholder cloud. COPC range-streaming (via `copc.ts` + potree-core) layers on
top of the same `toPointData` normalizer next.

## Structure

- `src/format.ts`, `src/copc.ts`, `src/pointData.ts` — pure, unit-tested logic
  (display helpers, byte-range/manifest, attribute→buffer conversion).
- `src/lasSource.ts` — loaders.gl LAS/LAZ fetch+parse (network edge).
- `src/pointCloudViewer.ts` — three.js renderer (the seam for the streaming loader).
- `src/main.ts` / `index.html` — bootstrap; loads `?url=`, `?share=`, or a placeholder.
- `src/share.ts` — pure share-link resolution (params → endpoints, record validation).
