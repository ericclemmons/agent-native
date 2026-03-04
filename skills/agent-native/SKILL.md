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

**snapshot -> read refs -> interact by ref -> re-snapshot**

```bash
agent-native open "System Settings"
agent-native snapshot "System Settings" -i    # Get interactive elements with @refs
agent-native click @n5                        # Interact using refs
agent-native snapshot "System Settings" -i    # Re-snapshot after UI changes
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

## Electron / Web Apps (Slack, Discord, VS Code, etc.)

Electron apps expose a minimal AX tree — inner UI elements are often opaque AXGroups with no labels. When `snapshot -i` returns very few useful elements:

1. **Use `key` for keyboard shortcuts** — most Electron apps have rich keyboard support:

```bash
agent-native key Slack cmd+k                     # Open quick switcher
agent-native key Slack "channel name" return     # Type and confirm
```

2. **Use `screenshot` for visual aid** — see what's on screen when the AX tree isn't helpful:

```bash
agent-native screenshot Slack /tmp/slack.png     # Capture Slack's window
```

3. **Use the window title** to confirm navigation state:

```bash
agent-native get title Slack
# "Chad Donohue (DM) - Ryan Florence Fan Club - Slack"
```

4. **Common Slack shortcuts**: Cmd+K (quick switcher), Cmd+U (upload file), Cmd+N (new message).

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
