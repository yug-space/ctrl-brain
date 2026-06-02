<div align="center">
  <img src="assets/logo.svg" width="96" height="96" alt="Ctrl+Brain logo"/>
  <h1>Ctrl+Brain</h1>
  <p><strong>Your second brain, one keystroke away.</strong></p>
</div>

A tiny macOS menu-bar agent. Press **⌃⇧2** anywhere and Ctrl+Brain captures the
selected text, image, or screenshot — OCRs it, describes it with a local model,
and saves it to one editable Markdown document. Supermemory sync is optional;
local AI agents can use the bundled MCP server instead.

## Requirements

- macOS 13 or newer
- Xcode Command Line Tools (`xcode-select --install`)
- A local describe backend: Claude CLI or Codex CLI available on `PATH`
- Optional: a Supermemory API key for sync
- Optional: Node.js for the local MCP server

## What it does

Press **Control+Shift+2** (the shortcut is customizable) anywhere:

- **Selected text** is read via the Accessibility API (with a synthetic ⌘C
  fallback for browsers) and saved with its source URL — exact, no OCR.
- **Images / screenshots** are OCR'd on-device with **Apple Vision**, described
  by a local **Claude / Codex CLI**, and saved.
- **Nothing selected?** The native screenshot picker opens; the region you grab
  is captured the same way.

Everything lands in one rolling, **editable** local document:

```
~/SecondBrain/captures/SecondBrain.mdx
```

Open the menu-bar item → **Open** to browse it. The viewer renders the Markdown
cleanly (headings, captions, inline images — no raw syntax), is fully editable
with autosave, and live-updates as new captures arrive. If you set a
Supermemory API key, captures also sync there.

## Build & run

```bash
cp .env.example .env # optional, for Supermemory sync / backend selection
chmod +x build.sh && ./build.sh
open "Ctrl+Brain.app"
```

No Xcode project — it compiles with `clang` and is signed with a local
self-signed identity so permission grants persist across rebuilds.

## Publish Updates

Deploy the website directly to the linked Vercel project:

```bash
scripts/deploy-web.sh
```

Build, notarize, and replace the GitHub release DMG:

```bash
scripts/publish-dmg-release.sh
```

The release script defaults to `v1.0.0`, uses the `ctrlbrain-notary` notarytool
profile, and uploads `dist/Ctrl+Brain-1.0.dmg` to the GitHub release. Override
with `TAG=...`, `REPO=...`, `ASSET_NAME=...`, or `NOTARY_KEYCHAIN_PROFILE=...`.

First run requires macOS permissions (granted once, then they stick):

- **Accessibility** — for reading the selection and the synthetic ⌘C.
- **Screen Recording** — only for the screenshot picker.
- **Automation** (optional) — source-URL detection in Safari / Chrome / Arc.

After the first run, Ctrl+Brain installs a per-user LaunchAgent so it starts
automatically in the background when you log in to your Mac.

## Settings

Menu-bar icon → **Settings…** (or ⌘,):

- **Container tag** — groups captures in Supermemory and is written into the
  document frontmatter; applied to every capture. Default `my-second-brain`.
- **Capture shortcut** — click the recorder and press any combo (needs a
  modifier). Default `⌃⇧2`. Re-binds live.

The Supermemory API key is read from `SUPERMEMORY_API_KEY`, then from a `.env`
file (cwd, the app bundle's Resources, the bundle's parent dir,
`~/SecondBrain/.env`, or `~/.config/ctrlbrain/.env`).

Set `CTRL_BRAIN_DESCRIBE_BACKEND=claude` or `CTRL_BRAIN_DESCRIBE_BACKEND=codex`
to choose the image-description backend. Ctrl+Brain searches common Homebrew,
npm, nvm, asdf, bun, cargo, and local-bin paths so GUI launches can still find
the selected CLI.

## Local MCP

Ctrl+Brain ships a local stdio MCP server for users who do not use Supermemory,
or for anyone who wants MCP-capable AI agents to read, search, and append notes
to the same Markdown brain directly:

```json
{
  "mcpServers": {
    "ctrl-brain": {
      "command": "node",
      "args": ["/path/to/ctrl-brain/mcp/ctrl-brain-mcp.js"]
    }
  }
}
```

By default it uses:

```text
~/SecondBrain/captures/SecondBrain.mdx
```

Override that path with `CTRL_BRAIN_FILE` if needed. Available tools:
`brain_status`, `read_brain`, `tail_brain`, `search_brain`, and
`append_brain`.

See `mcp/README.md` for a fuller config example.

## Project layout

| File | Role |
|------|------|
| `main.m`, `AppDelegate.{h,m}` | The whole app: hotkey, capture, OCR, describe, upload, viewer, settings |
| `Info.plist` | Bundle config (`LSUIElement`, app icon) |
| `build.sh` | `clang` build, ad-hoc/self-signed code-sign, bundles `.env` + logo + icon |
| `package-dmg.sh` | Developer ID signed/notarized DMG packaging |
| `scripts/` | Direct website deploy and release upload helpers |
| `mcp/` | Local stdio MCP server for AI agents |
| `assets/` | `logo.svg`, generated `AppIcon.icns` |
| `web/` | Next.js landing site |
| `.env.example` | Local configuration template |

## Open source

Ctrl+Brain is released under the MIT License. See `CONTRIBUTING.md`,
`SECURITY.md`, and `THIRD_PARTY_NOTICES.md` before opening issues or pull
requests.
