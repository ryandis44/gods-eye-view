# Container deployment

The image builds the browser bundle with Node.js 24 and serves it on port
`4173` using the app's existing Vite preview server and live-data API proxies.
It runs as the unprivileged `node` user and includes a health check. Like the
existing standalone app, this is a local/trusted deployment: use an authenticated
HTTPS reverse proxy for remote access (see [SECURITY.md](../SECURITY.md)).
[Vite preview](https://vite.dev/guide/static-deploy.html) is intended for local
preview rather than a hardened production web server.

## Build and run locally

From the repository root:

```bash
docker build -t gods-eye-view:local .
docker run --rm --init --name gods-eye-view -p 127.0.0.1:4173:4173 gods-eye-view:local
```

Open <http://localhost:4173>. No API keys are required to start.

To provide optional server-side credentials, create a local environment file
using [.env.example](../.env.example) as a reference, then run:

```bash
docker run --rm --init --name gods-eye-view -p 127.0.0.1:4173:4173 --env-file .env -v gods-eye-view-cache:/app/.gev-cache gods-eye-view:local
```

The cache volume preserves provider caches and the TomTom daily usage counter
across container replacements. Runtime credentials include `OPENAI_API_KEY`,
`GOOGLE_MAPS_SERVER_API_KEY`, `AISSTREAM_API_KEY`, `OPENSKY_CLIENT_ID`,
`OPENSKY_CLIENT_SECRET`, `FIRMS_MAP_KEY`, and `TOMTOM_API_KEY`; supply only those
you need. They are never required by GitHub Actions or the image build.

The in-app **POWER UP** credential editor is only available in development mode;
the preview server deliberately disables its setup endpoints. Configure this
image with build arguments and runtime environment variables instead.

### Browser credentials

`GOOGLE_MAPS_API_KEY` and `CESIUM_ION_TOKEN` are optional **build arguments**:

```bash
docker build --build-arg GOOGLE_MAPS_API_KEY=your-public-browser-key --build-arg CESIUM_ION_TOKEN=your-public-ion-token -t gods-eye-view:local .
```

These values are visible in the compiled JavaScript. Restrict them to your
deployment URL at the provider. Changing them requires rebuilding the image;
setting them only with `docker run -e` does not change the browser bundle.
For Google Places and Street View, supply `GOOGLE_MAPS_SERVER_API_KEY` at runtime
(or `GOOGLE_MAPS_API_KEY` at runtime for the app's single-key fallback).

`PORT` defaults to `4173`. If you change it, update the container side of the
port mapping too. The container listens on `0.0.0.0` internally so Docker can
reach it; the example publishes only to the host's loopback interface.

## Tagged releases on GitHub

[docker-publish.yml](../.github/workflows/docker-publish.yml) runs **only when a
tag matching `v*` is pushed**, including `v1`, `v1.1`, and `v1.2.3`. It builds
and pushes a Linux AMD64 image to `ghcr.io/<owner>/<repository>:<tag>` and signs
the published digest with Cosign, following the neighboring workspace projects.
It does not publish a moving `latest` tag. Branch pushes, pull requests, and
manual dispatch do not trigger this workflow. The existing `ci.yml` continues
to validate main-branch pushes and pull requests independently.

For this checkout, pushing `v1.1` publishes
`ghcr.io/ryandis44/gods-eye-view:v1.1`:

```bash
git tag v1.1
git push origin v1.1
```

No custom GitHub secrets or variables are required. The workflow uses the
automatically supplied `GITHUB_TOKEN` with `packages: write` for GHCR, and
GitHub OIDC for keyless signing. GitHub Actions must be enabled on the repository;
if the GHCR package already exists, it must grant this repository write access.

Optional repository **Actions variables** (Settings → Secrets and variables →
Actions → Variables):

| Variable | Effect |
| --- | --- |
| `GOOGLE_MAPS_API_KEY` | Compiles the public Google Maps browser key into the image. |
| `CESIUM_ION_TOKEN` | Compiles the public Cesium ion token into the image. |

Leave both unset for a keyless build. Configure private provider keys on the
deployment host, not as build arguments or GitHub variables.
