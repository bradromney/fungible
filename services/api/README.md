# Fungible API (sync + share)

The optional cloud backend behind the local-first app (ADR-0003): hosted blob
storage + a metadata catalog + shareable links that the web viewer consumes.
Built for **Cloudflare Workers + R2 + D1** (R2 has no egress fees — attractive
when users re-download large clouds).

## Design

- `src/router.ts` + `src/store.ts` + `src/types.ts` — **pure** request logic
  behind a `Store` interface, unit-tested with an in-memory store (no runtime
  needed). This is the bulk of the behavior.
- `src/index.ts` — the Workers entry: adapts Request/Response around `route`,
  streams binary blobs straight to R2, and backs `Store` with D1. Only this file
  touches the runtime.

### Endpoints

```
POST   /sets                 create a set             -> 201 SetRecord         [auth]
GET    /sets/:id             fetch a set              -> 200 | 404             [auth]
POST   /sets/:id/share       create a share link      -> 201 {token,url,expiresAt?} | 404  [auth]
POST   /sets/:id/uploads     request a blob upload    -> 201 {url,key} | 404   [auth]
GET    /share/:token         public set by share      -> 200 | 404             public
DELETE /share/:token         revoke a share link      -> 204 | 404             [auth]
PUT    /blobs/:key           upload a blob to R2      -> 201                   [auth]
GET    /blobs/:key           download a blob          -> 200 | 401 | 404       [auth OR ?share=<token>]
POST   /report               site report (facts->text)-> 200 {report,source}   [auth]
```

### Access model

`[auth]` routes require `Authorization: Bearer <API_KEY>` (set with
`wrangler secret put API_KEY`); with no key configured they **fail closed**
(503). The public surface is deliberate and narrow: resolving a share token,
and streaming a blob with `?share=<token>` when that share's set owns the
blob key — which is how the web viewer loads a shared cloud without
credentials. `POST /sets/:id/share` accepts an optional
`{ expiresInDays: number }`; expired or revoked tokens resolve 404. Uploading
a blob records its key on the set (`blobKey`), so a resolved share tells the
viewer exactly what to fetch. All responses carry permissive CORS headers so
the viewer can call from another origin.

`POST /report` takes measured facts (`{ siteName, areaSquareMeters?, cutVolume?,
fillVolume?, pointCount?, units? }`) and returns a client-ready summary. If
`ANTHROPIC_API_KEY` is set it's LLM-enhanced (`source: "llm"`); otherwise — or on
any error — it returns the deterministic summary (`source: "deterministic"`). AI
is enhancement, never a hard dependency.

## Provisioned infrastructure (account: your Cloudflare)

Already created (2026-06-04):
- **R2 bucket** `fungible-scans`
- **D1 database** `fungible` (id `cc401444-b302-4e49-accc-d888bd49e5be`), schema applied

Remaining to go live (one command, needs `wrangler login` on your machine):

```sh
cd services/api && npm install
npx wrangler deploy                                  # deploy the Worker
npx wrangler secret put API_KEY                      # the capture app's bearer key
npx wrangler secret put ANTHROPIC_API_KEY            # optional: enable LLM reports
```

For databases created before share expiry existed, apply the migration noted
at the bottom of `schema.sql` (two `ALTER TABLE shares …` statements).

## Develop / test (no cloud account needed)

```sh
cd services/api
npm install
npm run typecheck
npm test            # exercises the router against the in-memory store
```

CI runs typecheck + test. The pure logic is what we test; the Workers bindings
are validated at deploy.

## Deploy (needs a Cloudflare account)

```sh
npx wrangler r2 bucket create fungible-scans
npx wrangler d1 create fungible            # paste the id into wrangler.toml
npx wrangler d1 execute fungible --file=schema.sql
npm run deploy
```

These steps can also be driven via the Cloudflare MCP integration — provisioning
R2/D1/Workers without touching the dashboard.
