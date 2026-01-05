# Copilot instructions for ESPHomeDesigner-Docker

Goal: help an AI code agent become productive quickly when editing the editor UI, features, and Docker packaging.

- **Big picture**: this repository packages a client-side web app (static HTML/JS/CSS) into a Docker image served by nginx. The UI lives under `Docker/src/data/` and is served as-is by the Docker image defined in `Docker/Dockerfile` (nginx). There is no backend server in this repo.

- **Entry points**:
  - `Docker/src/data/editor.html` — main single-page editor UI.
  - `Docker/src/data/js/main.js` — top-level application lifecycle and event wiring.
  - `Docker/src/data/feature_registry.js` — dynamic loader and registry for widget feature modules.
  - `Docker/src/nginx/default.conf` — nginx config used by the Docker image (index set to `editor.html`).

- **Feature modules**: widgets live under `Docker/src/data/features/{featureId}/render.js`. New features should export a `render` export (ES module) so `feature_registry.js` can dynamically `import()` them. Legacy IIFE registration via `window.FeatureRegistry` is supported but newer work should prefer ES module exports.

- **Data flow & conventions**:
  - UI generates YAML snippets in-memory via functions exposed in the global namespace (see `generateSnippetLocally()` usages in `main.js`).
  - Features may additionally provide `yaml_export.js` alongside `render.js` (see `calendar/yaml_export.js`) for YAML-specific export logic.
  - The registry uses `window.RETERMINAL_BASE_PATH` or defaults to `./features` for dynamic imports — agent edits should preserve relative import expectations (no file:// imports).

- **Dev / run commands** (from repository root):
  - Build the image: `docker build -t esphome-designer -f Docker/Dockerfile .`
  - Run locally: `docker run --rm -p 8080:80 esphome-designer` then open `http://localhost:8080`.
  - Quick live-edit without building: serve `Docker/src/data` as static files (e.g., `npx http-server Docker/src/data -p 8080`) or mount into an nginx container: `docker run --rm -p 8080:80 -v $(pwd)/Docker/src/data:/usr/share/nginx/html:ro nginx:latest`.

- **Patterns to follow**:
  - Keep UI logic in `js/` and feature-specific rendering inside `features/` per-widget folders.
  - When adding a widget: register its id (folder name) in `feature_registry.js` will pick it up via dynamic import; ensure `render.js` exports `render`.
  - Use the app event bus and helpers defined globally (look for `on(EVENTS.*)` usages in `main.js`). Do not introduce a separate runtime store unless intentionally replacing `window.AppState`.

- **Debugging tips**:
  - Dynamic import errors commonly occur when serving files from `file://`; always run via HTTP (docker/nginx or local static server).
  - Check browser console for `[FeatureRegistry]` logs when features fail to load.

- **What an AI should not assume**:
  - There is no backend or Node build step in this repo; adding server-side code is out-of-scope unless the user asks.
  - There are no discovered automated tests — changes should be validated manually by running the container or a static server and exercising the editor UI.

If any section is unclear or you'd like this shortened/expanded, tell me which part to refine.
