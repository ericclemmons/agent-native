# agent-native

> **⚠️ This project is archived. I recommend using [agent-desktop](https://github.com/lahfir/agent-desktop/) instead.**

---

**Control macOS native apps via the Accessibility tree — like [agent-browser](https://github.com/vercel-labs/agent-browser), but for the desktop.**

Inspired by [agent-browser](https://github.com/vercel-labs/agent-browser) by Vercel Labs. Where agent-browser gives AI agents structured control over web pages via CDP and the DOM, `agent-native` does the same for macOS native applications via the Accessibility (AX) tree.

## Install

### Homebrew

```bash
brew install ericclemmons/tap/agent-native
```

### From source

```bash
git clone https://github.com/ericclemmons/agent-native.git
cd agent-native
make install
```

### Prerequisites
- macOS 13+ (Ventura)
- **Accessibility permissions** granted to your terminal

### Grant Accessibility Access

**System Settings > Privacy & Security > Accessibility > add Terminal.app / iTerm / your IDE**

## Quick Start

```bash
# List running apps
agent-native apps

# Open an app
agent-native open "System Settings"

# Get interactive elements with refs
agent-native snapshot "System Settings" -i

# Click using ref from snapshot
agent-native click @n5

# Fill a text field
agent-native fill @n3 "Wi-Fi"

# Read element text
agent-native get text @n1

# Check state
agent-native is enabled @n7
```

## Commands

### Discovery

```bash
agent-native apps                                    # List running GUI apps
agent-native apps --format json                      # JSON output
agent-native open <app>                              # Launch by name or bundle ID
```

### Snapshot (primary workflow for agents)

```bash
agent-native snapshot <app>                          # Full AX tree with refs
agent-native snapshot <app> -i                       # Interactive elements only
agent-native snapshot <app> -i -c                    # Interactive + compact
agent-native snapshot <app> -d 3                     # Limit depth
agent-native snapshot <app> -i --json                # JSON for tool-use
```

| Option | Description |
|---|---|
| `-i, --interactive` | Only interactive elements (buttons, inputs, toggles, links) |
| `-c, --compact` | Remove empty structural elements |
| `-d, --depth <n>` | Limit tree depth |
| `--json` | JSON output |

### Interaction (use @refs from snapshot)

```bash
agent-native click @n2                               # Click element
agent-native fill @n3 "search text"                  # Clear and type
agent-native type @n3 "append text"                  # Type without clearing
agent-native select @n5 "Option A"                   # Select from popup/dropdown
agent-native check @n4                               # Check checkbox (idempotent)
agent-native uncheck @n4                             # Uncheck checkbox (idempotent)
agent-native focus @n3                               # Focus element
agent-native hover @n2                               # Move cursor to element
agent-native action @n7 AXIncrement                  # Any AX action
```

### Interaction (filter-based, without snapshot)

```bash
agent-native click "System Settings" --title "Wi-Fi"
agent-native fill Safari "https://github.com" --label "Address"
agent-native check "System Settings" --title "Wi-Fi" --role AXCheckBox
```

### Read State

```bash
agent-native get text @n1                            # Get text/title/label
agent-native get value @n3                           # Get input value
agent-native get attr @n2 AXEnabled                  # Get any attribute
agent-native get title Safari                        # Get frontmost window title
agent-native is enabled @n5                          # Check if enabled
agent-native is focused @n3                          # Check if focused
```

### Find & Inspect

```bash
agent-native find <app> --role AXButton              # Find by role
agent-native find <app> --title "Submit"             # Find by title
agent-native inspect @n3                             # All attributes & actions
```

### Wait

```bash
agent-native wait <app> --title "Apply" --timeout 5  # Wait for element
agent-native wait <app> --role AXSheet --timeout 10   # Wait for dialog
```

## Agent Mode

Use `--json` on any command for structured output:

```bash
agent-native snapshot "System Settings" -i --json | jq '.[0].ref'
agent-native get text @n1 --json
agent-native is enabled @n5 --json
```

## Using with AI Agents

### Install the skill

```bash
npx skills add ericclemmons/agent-native
```

### Or add to AGENTS.md / CLAUDE.md

```markdown
## macOS App Automation

Use `agent-native` for controlling native macOS apps. Run `agent-native --help` for all commands.

Core workflow:
1. `agent-native open <app>` -- Launch the app
2. `agent-native snapshot <app> -i` -- Get interactive elements with refs
3. `agent-native click @n1` / `fill @n2 "text"` -- Interact using refs
4. Re-snapshot after page/pane changes
```

## Testing

```bash
make test        # Full suite (requires accessibility permissions)
make test-quick  # Build + CLI smoke tests only
```

## License

MIT
