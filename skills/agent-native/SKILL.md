---
name: agent-native
description: macOS native app automation CLI for AI agents. Use when the user needs to interact with macOS desktop applications, including opening apps, clicking buttons, toggling settings, filling forms, reading UI state, automating System Settings, controlling Finder, Safari, or any native app.
---

# agent-native

macOS native app automation via the Accessibility tree. Like agent-browser, but for desktop apps.

## Prerequisites

- macOS 13+ with Accessibility permissions granted to your terminal
- Binary at `agent-native` (install via `swift build -c release && cp .build/release/agent-native /usr/local/bin/`)

## Core Workflow

**apps -> pick/open target -> snapshot -> interact by ref -> re-snapshot**

1. **Always start with `agent-native apps`** to see what's already running. Prefer reusing an already-open app (e.g. if a browser is already open, use it instead of opening a different one).
   - **Known browsers:** Safari, Arc, Chrome, Firefox, Helium. Any of these can be used for web tasks.
2. Only call `agent-native open <app>` if the target app isn't already running.
3. Snapshot, interact, and re-snapshot as needed.

```bash
agent-native apps                            # Check what's already running
agent-native snapshot Safari -i              # Use the already-open browser
agent-native click @n5                       # Interact using refs
agent-native snapshot Safari -i              # Re-snapshot after UI changes
```

Always re-snapshot after actions that change the UI. Refs are invalidated when UI structure changes.

## Commands

### Navigation

```bash
agent-native open <app>                          # Open/activate by name or bundle ID
agent-native open "System Settings"
agent-native open com.apple.Safari               # Already-running apps just activate
```

### Screenshot

```bash
agent-native screenshot <app> [path]             # Capture app's frontmost window
agent-native screenshot Slack                    # Saves to /tmp/agent-native-screenshot.png
agent-native screenshot Slack /tmp/slack.png     # Custom path
agent-native screenshot Slack --json             # {"path": "...", "width": ..., "height": ...}
```

### Keystroke Sending

```bash
agent-native key <app> <keys...>                 # Send keystrokes to an app
agent-native key Slack "Hello world"             # Type text
agent-native key Slack cmd+k                     # Send Cmd+K
agent-native key Slack escape                    # Special keys: escape, return, tab, delete, up, down, left, right, space
agent-native key Slack cmd+a delete              # Chain multiple keys
agent-native key Calculator 5 + 3 return         # Multiple keystrokes
```

Modifiers: `cmd`/`command`, `ctrl`/`control`, `alt`/`option`/`opt`, `shift`

### Paste File

```bash
agent-native paste <app> <path>                  # Copy file to clipboard and Cmd+V into app
agent-native paste Slack /tmp/screenshot.png     # Paste image into Slack
agent-native paste Slack ./report.pdf            # Paste any file
```

### Snapshot (recommended for agents)

```bash
agent-native snapshot <app>                      # Full AX tree with refs
agent-native snapshot <app> -i                   # Interactive elements only (recommended)
agent-native snapshot <app> -i -c                # Interactive + compact
agent-native snapshot <app> -d 3                 # Limit depth
agent-native snapshot <app> -i --json            # JSON for parsing
```

| Flag | Description |
|---|---|
| `-i` | Interactive elements only |
| `-c` | Compact -- remove empty structural elements |
| `-d <n>` | Limit tree depth |
| `--json` | JSON output |

### Interaction (use @refs from snapshot)

```bash
agent-native click @n2                           # Click / press
agent-native fill @n3 "text"                     # Clear field and type
agent-native type @n3 "text"                     # Type without clearing
agent-native select @n5 "Option A"               # Select from dropdown
agent-native check @n4                           # Check checkbox (idempotent)
agent-native uncheck @n4                         # Uncheck checkbox (idempotent)
agent-native focus @n3                           # Focus element
agent-native hover @n2                           # Move cursor to element
agent-native action @n7 AXIncrement              # Any AX action
```

### Read State

```bash
agent-native get text @n1                        # Get text / title / label
agent-native get value @n3                       # Get input value
agent-native get attr @n2 AXEnabled              # Get any AX attribute
agent-native get title Safari                    # Frontmost window title
agent-native is enabled @n5                      # true / false
agent-native is focused @n3                      # true / false
```

### Discovery

```bash
agent-native apps                                # List running GUI apps
agent-native apps --format json                  # JSON output
agent-native find <app> --role AXButton          # Find elements by filter
agent-native find <app> --title "Submit"         # Find by title
agent-native inspect @n3                         # All attributes and actions
agent-native tree <app> --depth 3                # Raw AX tree (no refs)
```

### Wait

```bash
agent-native wait <app> --title "Apply" --timeout 5
agent-native wait <app> --role AXSheet --timeout 10
```

## Browser & Electron Enhanced Access

Chromium browsers (Arc, Chrome, Edge, Brave, Vivaldi) and Electron apps don't expose web DOM content in the macOS AX tree by default. `snapshot` now auto-detects these apps and enhances access automatically.

**Priority chain:** CDP read → AX-enhanced interact → keyboard fallback → screenshot

### Automatic Detection in `snapshot`

```bash
agent-native snapshot Arc -i                      # Auto-detects Chromium, enables AX enhancement
agent-native snapshot "VS Code" -i                # Auto-detects Electron, enables AX enhancement
```

When `snapshot` detects a Chromium/Electron app:
1. **CDP mode** (richest): If browser was launched with `--remote-debugging-port`, snapshot reads the full web accessibility tree via Chrome DevTools Protocol
2. **AX-enhanced mode** (fallback): Sets `AXEnhancedUserInterface` to force the app to build its accessibility tree, then walks it normally

### CDP Mode (richest web content)

Launch your browser with CDP enabled for the best results:

```bash
# Launch Chrome with CDP
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222

# Snapshot auto-detects CDP on ports 9222/9229
agent-native snapshot Chrome -i

# Or specify a port explicitly
agent-native snapshot Chrome -i --port 9222
```

### Manual Persistent Control

```bash
agent-native ax-enable Arc                        # Persistently enable AXEnhancedUserInterface
agent-native snapshot Arc -i                      # Now shows web page elements
agent-native ax-disable Arc                       # Restore when done
```

### Fallback: Keyboard Shortcuts + Screenshots

When AX tree is still sparse (some Electron apps), fall back to keyboard-driven interaction:

```bash
agent-native key Slack cmd+k                     # Open quick switcher
agent-native key Slack "channel name" return     # Type and confirm
agent-native screenshot Slack /tmp/slack.png     # Visual confirmation
agent-native get title Slack                     # Check navigation state
```

### Pasting files into apps

```bash
agent-native paste Slack /path/to/image.png      # Copies to clipboard and pastes in one step
```

## Tips

- **Always use `-i` with snapshot** -- full trees are noisy.
- **Re-snapshot after navigation** -- old refs may not resolve after UI changes.
- **`check`/`uncheck` are idempotent** -- they read current state first.
- **`fill` clears first, `type` appends.**
- **AX tree peers into browsers** -- Safari/Chrome expose web content as AX nodes.
- **Electron apps need keyboard shortcuts** -- use System Events keystrokes when AX is sparse.
