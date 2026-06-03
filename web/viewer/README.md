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

## Structure

- `src/format.ts` — pure display helpers (unit-tested, no DOM).
- `src/pointCloudViewer.ts` — three.js renderer; the seam where the streaming
  COPC/Potree loader replaces the in-memory buffer.
- `src/main.ts` / `index.html` — bootstrap with a placeholder cloud.
