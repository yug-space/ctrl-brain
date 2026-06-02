# Contributing

Thanks for taking the time to improve Ctrl+Brain.

## Development

Build the native macOS app from the repo root:

```bash
chmod +x build.sh
./build.sh
open "Ctrl+Brain.app"
```

Run the landing site from `web/`:

```bash
npm install
npm run dev
```

## Configuration

Copy `.env.example` to `.env` for local secrets. Do not commit `.env` files.

`SUPERMEMORY_API_KEY` enables syncing. `CTRL_BRAIN_DESCRIBE_BACKEND` can be
`claude` or `codex`; the selected CLI must be available on PATH.

## Pull Requests

- Keep changes focused and describe the user-facing behavior.
- Run `./build.sh` for native app changes.
- Run `npm run build` in `web/` for landing site changes.
- Avoid committing generated outputs such as `.next/`, `.vercel/`, app bundles,
  local captures, or credentials.
