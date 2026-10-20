# Morse Lamp web page

The site at <https://morse-code.huyakhuyak.productions>: landing page with the og-image, the
privacy policy and the support page. Astro 6 on Bun, Tailwind CSS 4, `astro-og-canvas`.

```bash
bun install
bun run dev        # http://localhost:4321
bun run check      # astro check
bun run test       # astro build, then bun test against dist/
```

The icon copies in `public/` and `src/assets/` are written by `../scripts/render-icon.sh`, the
screenshots in `src/assets/screenshots/` by `../scripts/compose-screenshots.swift`; regenerate
them, do not edit. The landing button is the `GET_APP` constant in `src/lib/site.ts`.

## Deployment

Dokku builds this directory with the `Dockerfile` (bun build, then nginx). One-time setup on the
server, run by the owner (done 2026-10-20):

```bash
ssh dokku@oasis.wg apps:create morse-code-huyakhuyak-productions
ssh dokku@oasis.wg builder:set morse-code-huyakhuyak-productions build-dir web
ssh dokku@oasis.wg domains:set morse-code-huyakhuyak-productions morse-code.huyakhuyak.productions
# TLS: mirror whatever `ssh dokku@oasis.wg letsencrypt:list` shows for huyakhuyak-productions,
# typically: ssh dokku@oasis.wg letsencrypt:enable morse-code-huyakhuyak-productions
```

Then, from the repo root:

```bash
git remote add dokku dokku@oasis.wg:morse-code-huyakhuyak-productions
git push dokku main
```

DNS needs no step: `*.huyakhuyak.productions` already resolves to the server.
