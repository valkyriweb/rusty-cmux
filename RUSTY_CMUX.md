# Rusty cmux Fork Notes

Purpose: local cmux fork for evaluating whether Rusty should adopt cmux-style primitives:

- in-terminal browser panes backed by `WKWebView`
- vertical workspace tabs on the left
- per-pane horizontal `surface` tabs (`terminal`, `browser`, markdown/file preview, etc.)
- CLI/socket control for workspaces, panes, surfaces, and browser automation

## Repository layout

- Upstream source clone: `~/Projects/oss/cmux`
- Rusty fork checkout: `~/Projects/personal/rusty-cmux`
- Intended GitHub fork remote: `git@github.com:valkyriweb/rusty-cmux.git`
- Upstream remote: `https://github.com/manaflow-ai/cmux.git`

`gh repo fork manaflow-ai/cmux --clone=false --default-branch-only --fork-name rusty-cmux` returned GitHub HTTP 502 twice on 2026-05-25, so this checkout is local-first for now. Create the GitHub fork later, then `git push -u origin main`.

## Setup

```bash
cd ~/Projects/personal/rusty-cmux
./scripts/setup.sh
```

This initializes submodules and links cached `GhosttyKit.xcframework`.

## Build profiles

Use the fork-local wrapper instead of raw `reload.sh`:

```bash
cd ~/Projects/personal/rusty-cmux
scripts/rusty-build-profile.sh dev
scripts/rusty-build-profile.sh browser --launch
scripts/rusty-build-profile.sh tabs
```

Profiles are intentionally isolated:

| Profile | App name | Bundle ID | Use |
|---|---|---|---|
| `dev` | `Rusty cmux DEV` | `com.valkyriweb.rustycmux.dev` | general fork hacking |
| `browser` | `Rusty cmux Browser` | `com.valkyriweb.rustycmux.browser` | browser-pane reverse engineering |
| `tabs` | `Rusty cmux Tabs` | `com.valkyriweb.rustycmux.tabs` | workspace/surface/tab layout experiments |

`reload.sh` prints an `App path:` line after build. Add `--launch` to open the built app.

The wrapper defaults `CMUX_SKIP_ZIG_BUILD=1` because Homebrew Zig on this machine is currently `0.16.x`, while cmux's Ghostty CLI helper build requires Zig `0.15.2`. Install/switch to Zig `0.15.2` and run `CMUX_SKIP_ZIG_BUILD=0 scripts/rusty-build-profile.sh <profile>` if you need to rebuild that helper.

## Live browser smoke

After launching the browser profile:

```bash
scripts/rusty-build-profile.sh browser --launch
```

Use the profile socket and bundled CLI directly when the app name is overridden:

```bash
CLI="$HOME/Library/Developer/Xcode/DerivedData/cmux-rusty-cmux-browser/Build/Products/Debug/Rusty cmux Browser.app/Contents/Resources/bin/cmux"
CMUX_SOCKET_PATH=/tmp/cmux-debug-rusty-cmux-browser.sock \
CMUX_BUNDLE_ID=com.valkyriweb.rustycmux.browser \
CMUX_BUNDLED_CLI_PATH="$CLI" \
  "$CLI" open https://example.com --json
```

Verified result on 2026-05-25: opened URL as `surface:2` in a right split, then `cmux browser surface:2 get url --json` returned `https://example.com/`.

## Current architecture notes

cmux nouns:

1. `window`: native macOS window
2. `workspace`: left-sidebar vertical tab
3. `pane`: split region inside a workspace
4. `surface`: tab inside a pane; can be terminal or browser
5. `panel`: internal implementation name for a surface view/model

Important source files:

- `Sources/Panels/Panel.swift` — `PanelType` includes `.terminal`, `.browser`, `.markdown`, `.filePreview`, `.rightSidebarTool`.
- `Sources/Panels/PanelContentView.swift` — switches panel type to `TerminalPanelView`, `BrowserPanelView`, etc.
- `Sources/Panels/BrowserPanel.swift` — browser model/state, search/theme/settings, WebKit integration.
- `Sources/Panels/BrowserPanelView.swift` — browser UI/chrome/omnibar.
- `Sources/Panels/CmuxWebView.swift` — custom `WKWebView` behavior.
- `Sources/BrowserWindowPortal.swift` — window-level WebKit hosting/portal layer.
- `Sources/Workspace.swift` and `Sources/WorkspaceContentView.swift` — workspace/pane/surface layout.
- `docs/agent-browser-port-spec.md` — browser automation API inventory and parity status.
- `CLI/cmux.swift` — CLI methods around `workspace.*`, `pane.*`, `surface.*`, `browser.*`.

## License warning

cmux is GPL-3.0-or-later. Treat it as a reference/fork lane, not code to copy into Rusty, unless Rusty's license/commercial-license story is intentionally handled.
