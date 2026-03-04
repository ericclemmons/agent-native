# PLAN.md — agent-native

Reproduce this project from scratch. Create every file listed below, then run the git commands at the end.

## Project Overview

**agent-native** is a Swift CLI that controls macOS native apps via the Accessibility tree — like [agent-browser](https://github.com/vercel-labs/agent-browser), but for the desktop. AI agents can open apps, snapshot the AX tree with refs (`@n1`, `@n2`), click/fill/check elements by ref, read state, and wait for elements. All commands support `--json` for tool-use integration.

Inspired by and credited to [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) (Apache-2.0).

## Directory Structure

```
agent-native/
├── .github/workflows/ci.yml
├── .gitignore
├── LICENSE
├── Makefile
├── Package.swift
├── README.md
├── Sources/AgentNative/
│   ├── AgentNative.swift
│   ├── Commands/
│   │   ├── ActionCommand.swift
│   │   ├── AppsCommand.swift
│   │   ├── ClickCommand.swift
│   │   ├── FindCommand.swift
│   │   ├── GetCommand.swift
│   │   ├── InspectCommand.swift
│   │   ├── InteractionCommands.swift
│   │   ├── IsCommand.swift
│   │   ├── OpenCommand.swift
│   │   ├── SnapshotCommand.swift
│   │   ├── TreeCommand.swift
│   │   ├── TypeCommand.swift
│   │   └── WaitCommand.swift
│   └── Core/
│       ├── AXEngine.swift
│       ├── AXNode.swift
│       ├── ElementResolver.swift
│       ├── Output.swift
│       └── RefStore.swift
├── TestFixture/
│   └── TestFixture.swift
├── skills/agent-native/
│   └── SKILL.md
└── test/
    └── integration.sh
```

## Architecture

- **Core/AXNode.swift** — Codable struct representing an AX element (role, title, value, label, identifier, enabled, focused, position, size, path, actions, childCount).
- **Core/AXEngine.swift** — Wraps macOS `AXUIElement` APIs: app discovery, element attribute reading, tree walking, element search with filters, performing actions, setting values/focus. This is the main workhorse.
- **Core/RefStore.swift** — Persists snapshot refs (`@n1` → element locator) to a temp JSON file so they survive between CLI invocations (each command is a separate process).
- **Core/ElementResolver.swift** — Shared logic: resolve an element either by `@ref` (via RefStore) or by app name + filter flags (role/title/label/identifier).
- **Core/Output.swift** — JSON and text formatting helpers.
- **Commands/** — One file per CLI subcommand, all using ArgumentParser. Every interaction command accepts either `@ref` or app+filters. All support `--json`.
- **AgentNative.swift** — `@main` entry point registering all subcommands.
- **TestFixture/TestFixture.swift** — Minimal AppKit app with known AX elements for CI testing. Single file, compiles with `swiftc`.
- **test/integration.sh** — Bash integration test suite (~35 assertions). Has `--quick` mode for build-only tests (no AX permissions needed).
- **skills/agent-native/SKILL.md** — Agent skill file installable via `npx skills add`.

## Key Design Decisions

1. **Snapshot + refs workflow** (from agent-browser): `snapshot` assigns refs like `@n1` to every element, persists them to `/tmp/agent-native-refs.json`. Subsequent commands resolve `@n1` back to a live AXUIElement by re-walking the tree and matching attributes.
2. **`check`/`uncheck` are idempotent** — they read current value first, only toggle if needed.
3. **`fill` clears then sets, `type` just sets** — mirrors agent-browser's distinction.
4. **Fuzzy app matching** — `findApp()` does case-insensitive prefix match, then substring fallback.
5. **CI uses TCC database injection** — `sudo sqlite3` on the macOS GitHub Actions runner to grant accessibility permissions.

---

## Files

Create each file exactly as shown below. Files containing nested code fences use `````-delimited blocks.


### `./.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    name: Build & Quick Test
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Build (release)
        run: swift build -c release

      - name: CLI smoke test
        run: |
          .build/release/agent-native --version
          .build/release/agent-native --help
          .build/release/agent-native apps

  integration:
    name: Integration Tests
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Build agent-native
        run: swift build -c release

      - name: Build test fixture
        run: swiftc -o .build/TestFixture TestFixture/TestFixture.swift -framework Cocoa

      - name: Grant accessibility permissions
        run: |
          # The TCC database schema varies by macOS version.
          # On macOS 14 (Sonoma) runners, we insert into the access table
          # to grant accessibility to the shell and our binaries.
          TCC_DB="/Library/Application Support/com.apple.TCC/TCC.db"

          grant_access() {
            local client="$1"
            sudo sqlite3 "$TCC_DB" \
              "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version) \
               VALUES ('kTCCServiceAccessibility', '$client', 1, 2, 4, 1);" 2>/dev/null || true
          }

          # Grant to common shells and our binaries
          grant_access "/bin/bash"
          grant_access "/bin/zsh"
          grant_access "/usr/bin/env"
          grant_access "$PWD/.build/release/agent-native"
          grant_access "$PWD/.build/TestFixture"

          # Also try the broader approach for the runner
          RUNNER_BIN=$(which bash)
          grant_access "$RUNNER_BIN"

          echo "TCC grants applied"

      - name: Run integration tests
        run: |
          chmod +x test/integration.sh
          ./test/integration.sh

      - name: Run quick tests (fallback if AX fails)
        if: failure()
        run: |
          chmod +x test/integration.sh
          ./test/integration.sh --quick
```

### `./.gitignore`

```
# Swift / SPM
.build/
.swiftpm/
Package.resolved
*.xcodeproj/
*.xcworkspace/
xcuserdata/
DerivedData/

# macOS
.DS_Store
*.dSYM/

# IDE
.vscode/
.idea/
```

### `./LICENSE`

```
MIT License

Copyright (c) 2026 Eric

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### `./Makefile`

```
.PHONY: build release install clean test test-quick fixture

build:
	swift build

release:
	swift build -c release

install: release
	cp .build/release/agent-native /usr/local/bin/agent-native
	@echo "✓ Installed to /usr/local/bin/agent-native"

fixture:
	swiftc -o .build/TestFixture TestFixture/TestFixture.swift -framework Cocoa
	@echo "✓ Built test fixture"

test: release fixture
	chmod +x test/integration.sh
	./test/integration.sh

test-quick: release
	chmod +x test/integration.sh
	./test/integration.sh --quick

clean:
	swift package clean
	rm -rf .build
```

### `./Package.swift`

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "agent-native",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "agent-native",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/AgentNative"
        ),
    ]
)
```

### `./README.md`

`````
# agent-native

**Control macOS native apps via the Accessibility tree — like [agent-browser](https://github.com/vercel-labs/agent-browser), but for the desktop.**

Inspired by [agent-browser](https://github.com/vercel-labs/agent-browser) by Vercel Labs. Where agent-browser gives AI agents structured control over web pages via CDP and the DOM, `agent-native` does the same for macOS native applications via the Accessibility (AX) tree. Same workflow, same mental model, different target.

## Setup

### Prerequisites
- macOS 13+ (Ventura)
- Swift 5.9+ (Xcode 15+)
- **Accessibility permissions** granted to your terminal

### Build

```bash
git clone https://github.com/yourname/agent-native.git
cd agent-native
swift build -c release
```

### Install

```bash
make install
# Copies binary to /usr/local/bin/agent-native
```

### Grant Accessibility Access

On first run, macOS will prompt you. You can also grant it manually:

**System Settings → Privacy & Security → Accessibility → add Terminal.app / iTerm / your IDE**

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
agent-native apps --json                             # JSON output
agent-native open <app>                              # Launch by name or bundle ID
agent-native open "System Settings"
agent-native open com.apple.Safari
```

### Snapshot (primary workflow for agents)

```bash
agent-native snapshot <app>                          # Full AX tree with refs
agent-native snapshot <app> -i                       # Interactive elements only (recommended)
agent-native snapshot <app> -i -c                    # Interactive + compact
agent-native snapshot <app> -d 3                     # Limit depth
agent-native snapshot <app> -i --json                # JSON for tool-use
```

Output:
```
Snapshot: System Settings (pid 1234) — 42 elements
─────────────────────────────────────────────
AXButton "General" [AXPress] [ref=n1]
AXButton "Wi-Fi" [AXPress] [ref=n2]
AXSearchField (Search) = "" [AXConfirm, AXPress] [ref=n3]
AXCheckBox "Wi-Fi" = "1" [AXPress] [ref=n4]
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
agent-native action @n7 AXShowMenu                   # Show context menu
```

### Interaction (filter-based, without snapshot)

All interaction commands also accept an app name + filter flags instead of @ref:

```bash
agent-native click "System Settings" --title "Wi-Fi"
agent-native fill Safari "https://github.com" --label "Address"
agent-native check "System Settings" --title "Wi-Fi" --role AXCheckBox
agent-native click Safari --role AXButton --title "Downloads" --index 0
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
agent-native find <app> --role AXTextField --label "Search"  # Combine filters
agent-native inspect @n3                             # All attributes & actions
agent-native inspect Safari --role AXTextField --title "Address"
```

### Tree (raw AX tree, no refs)

```bash
agent-native tree <app>                              # Full tree
agent-native tree <app> --depth 3                    # Limited depth
agent-native tree <app> --format json                # JSON
```

### Wait

```bash
agent-native wait <app> --title "Apply" --timeout 5  # Wait for element
agent-native wait <app> --role AXSheet --timeout 10  # Wait for dialog
```

## Agent Mode

Use `--json` on any command for structured output:

```bash
agent-native snapshot "System Settings" -i --json | jq '.[0].ref'
agent-native get text @n1 --json
agent-native is enabled @n5 --json
```

### Optimal AI Workflow

```bash
# 1. Open and snapshot
agent-native open "System Settings"
agent-native snapshot "System Settings" -i --json    # Agent parses refs

# 2. Agent picks target refs from snapshot
# 3. Interact using refs
agent-native click @n2                               # Click "Wi-Fi"
agent-native snapshot "System Settings" -i --json    # Re-snapshot after navigation

# 4. Toggle something
agent-native check @n7                               # Toggle on
agent-native get value @n7 --json                    # Verify state
```

## Browser DOM Access

The macOS AX tree peers into web content. When you `snapshot Safari` or `snapshot "Google Chrome"` deep enough, you'll see `AXWebArea` nodes whose children map to the rendered DOM — headings, links, text, form controls. This means `agent-native` can interact with web content through the same AX interface as native UI.

```bash
agent-native open Safari
agent-native snapshot Safari --depth 10 -i --json
# Shows: AXWebArea → AXHeading "GitHub", AXLink "Sign in", AXTextField "Search"
agent-native click @n15                              # Click a web link via AX
```

## Example: Toggle Wi-Fi

```bash
agent-native open "System Settings"
agent-native snapshot "System Settings" -i
# Output shows: AXButton "Wi-Fi" [ref=n3], then deeper:
#   AXCheckBox "Wi-Fi" = "1" [ref=n12]

agent-native click @n3                               # Navigate to Wi-Fi pane
agent-native wait "System Settings" --role AXCheckBox --title "Wi-Fi" --timeout 5
agent-native snapshot "System Settings" -i           # Re-snapshot
agent-native uncheck @n8                             # Toggle Wi-Fi off
```

## Example: Safari Navigation

```bash
agent-native open Safari
agent-native snapshot Safari -i
agent-native fill @n3 "https://github.com"           # Fill address bar
agent-native action @n3 AXConfirm                    # Press enter
agent-native wait Safari --role AXWebArea --timeout 10
agent-native snapshot Safari -i --depth 8 --json     # Inspect loaded page
```

## Using as MCP Tools

This CLI maps cleanly to MCP tool definitions:

| MCP Tool | CLI |
|---|---|
| `list_apps` | `agent-native apps --json` |
| `open_app` | `agent-native open <app> --json` |
| `snapshot` | `agent-native snapshot <app> -i --json` |
| `click` | `agent-native click @ref --json` |
| `fill` | `agent-native fill @ref "text" --json` |
| `type` | `agent-native type @ref "text" --json` |
| `select` | `agent-native select @ref "option" --json` |
| `check` | `agent-native check @ref --json` |
| `uncheck` | `agent-native uncheck @ref --json` |
| `get_text` | `agent-native get text @ref --json` |
| `get_value` | `agent-native get value @ref --json` |
| `is_enabled` | `agent-native is enabled @ref --json` |
| `inspect` | `agent-native inspect @ref --json` |
| `wait` | `agent-native wait <app> [filters] --json` |

## Architecture

```
agent-native
├── Package.swift
├── Makefile
├── skills/agent-native/
│   └── SKILL.md                       # Agent skill (npx skills add)
├── TestFixture/
│   └── TestFixture.swift              # CI test fixture app
├── test/
│   └── integration.sh                 # Integration test suite
└── Sources/AgentNative
    ├── AgentNative.swift              # CLI entry point (ArgumentParser)
    ├── Core/
    │   ├── AXNode.swift               # Structured AX element representation
    │   ├── AXEngine.swift             # macOS Accessibility API wrapper
    │   ├── ElementResolver.swift      # @ref + filter-based element resolution
    │   ├── RefStore.swift             # Persists snapshot refs between CLI calls
    │   └── Output.swift               # JSON/text formatting
    └── Commands/
        ├── AppsCommand.swift          # List running apps
        ├── OpenCommand.swift          # Launch apps
        ├── SnapshotCommand.swift      # AX tree with refs (key command)
        ├── TreeCommand.swift          # Raw AX tree dump
        ├── FindCommand.swift          # Query elements by filters
        ├── InspectCommand.swift       # Deep attribute inspection
        ├── GetCommand.swift           # get text/value/attr/title
        ├── IsCommand.swift            # is enabled/focused
        ├── ClickCommand.swift         # Click/press
        ├── FillCommand.swift          # Clear + type
        ├── TypeCommand.swift          # Type (append)
        ├── SelectCommand.swift        # Select dropdown option
        ├── CheckCommand.swift         # Check checkbox
        ├── UncheckCommand.swift       # Uncheck checkbox
        ├── FocusCommand.swift         # Focus element
        ├── HoverCommand.swift         # Hover (cursor move)
        ├── ActionCommand.swift        # Arbitrary AX action
        ├── InteractionCommands.swift  # Shared interaction commands
        └── WaitCommand.swift          # Poll for element
```

## Using with AI Agents

### Install the skill

```bash
npx skills add yourname/agent-native
```

This works with Claude Code, Cursor, Codex, Gemini CLI, GitHub Copilot, and any agent that supports the [Agent Skills](https://github.com/vercel-labs/skills) spec.

### Or just tell the agent

```
Use agent-native to toggle Wi-Fi in System Settings. Run agent-native --help to see commands.
```

### AGENTS.md / CLAUDE.md

For more consistent results, add to your project or global instructions:

```markdown
## macOS App Automation

Use `agent-native` for controlling native macOS apps. Run `agent-native --help` for all commands.

Core workflow:
1. `agent-native open <app>` — Launch the app
2. `agent-native snapshot <app> -i` — Get interactive elements with refs (@n1, @n2)
3. `agent-native click @n1` / `fill @n2 "text"` — Interact using refs
4. Re-snapshot after page/pane changes
```

## Testing

Integration tests run against a custom test fixture app with known accessibility elements (buttons, text fields, checkboxes, dropdowns, sliders).

```bash
# Full test suite (requires accessibility permissions)
make test

# Build + CLI smoke tests only (no accessibility needed)
make test-quick

# Build just the test fixture
make fixture
.build/TestFixture &          # Launch it, then poke around:
agent-native snapshot "Agent Native Test Fixture" -i
```

CI runs on GitHub Actions macOS runners with accessibility permissions granted via TCC database injection.

## Acknowledgments

This project is inspired by [agent-browser](https://github.com/vercel-labs/agent-browser) by [Vercel Labs](https://github.com/vercel-labs) (Apache-2.0). The CLI design, snapshot-with-refs workflow, and agent-oriented philosophy are directly modeled after agent-browser's approach — adapted from web/CDP to macOS/Accessibility APIs.

See also [nut.js](https://github.com/nut-tree/nut.js) for cross-platform desktop automation with similar accessibility tree support.

## License

MIT

`````

### `./Sources/AgentNative/AgentNative.swift`

```swift
import ArgumentParser
import Foundation

@main
struct AgentNative: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent-native",
        abstract: "Control macOS native apps via the Accessibility tree — like agent-browser, but for desktop.",
        discussion: """
        Inspired by agent-browser (https://github.com/vercel-labs/agent-browser).
        Uses macOS Accessibility APIs instead of CDP/DOM to give AI agents
        structured control over native applications.

        Workflow:
          1. agent-native open "System Settings"
          2. agent-native snapshot "System Settings" -i
          3. agent-native click @n5
          4. agent-native fill @n3 "search query"
        """,
        version: "0.1.0",
        subcommands: [
            // Discovery
            AppsCommand.self,
            OpenCommand.self,

            // Inspection
            SnapshotCommand.self,
            TreeCommand.self,
            FindCommand.self,
            InspectCommand.self,

            // Read state
            GetCommand.self,
            IsCommand.self,

            // Interaction
            ClickCommand.self,
            FillCommand.self,
            TypeCommand.self,
            SelectCommand.self,
            CheckCommand.self,
            UncheckCommand.self,
            FocusCommand.self,
            HoverCommand.self,
            ActionCommand.self,

            // Waiting
            WaitCommand.self,
        ],
        defaultSubcommand: AppsCommand.self
    )
}
```

### `./Sources/AgentNative/Commands/ActionCommand.swift`

```swift
import ArgumentParser
import Foundation

struct ActionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "action",
        abstract: "Perform an arbitrary AX action on an element. Use @ref or filter flags."
    )

    @Argument(help: "Target: @ref (e.g. @n3) or app name")
    var target: String

    @Argument(help: "Action to perform (e.g. AXPress, AXConfirm, AXIncrement, AXShowMenu)")
    var action: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?

    @Option(name: .shortAndLong, help: "Filter by title (substring)")
    var title: String?

    @Option(name: .shortAndLong, help: "Filter by label (substring)")
    var label: String?

    @Option(name: .shortAndLong, help: "Filter by identifier (substring)")
    var identifier: String?

    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    @Option(name: .long, help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target,
            ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: identifier,
            index: index
        )

        let available = AXEngine.actions(el)
        if !available.contains(action) {
            print("Warning: '\(action)' not in available actions: \(available)")
        }

        let success = AXEngine.performAction(el, action: action)

        struct ActionResult: Codable {
            let action: String; let success: Bool; let element: AXNode
        }
        let effectiveFormat = json ? OutputFormat.json : format
        let result = ActionResult(action: action, success: success, element: node)
        if effectiveFormat == .text {
            print("\(success ? "✓" : "✗") \(action) on: \(node.description)")
        } else {
            Output.print(result, format: .json)
        }
        if !success { throw AXError.actionFailed(action, node.path) }
    }
}
```

### `./Sources/AgentNative/Commands/AppsCommand.swift`

```swift
import ArgumentParser
import Foundation

struct AppsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "List running GUI applications"
    )

    @Option(name: .long, help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() throws {
        let apps = AXEngine.listApps()
        Output.print(apps, format: format)
    }
}
```

### `./Sources/AgentNative/Commands/ClickCommand.swift`

```swift
import ArgumentParser
import Foundation

struct ClickCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "click",
        abstract: "Click (AXPress) an element. Use @ref from snapshot or filter flags."
    )

    @Argument(help: "Target: @ref (e.g. @n3) or app name for filter-based selection")
    var target: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?

    @Option(name: .shortAndLong, help: "Filter by title (substring)")
    var title: String?

    @Option(name: .shortAndLong, help: "Filter by label (substring)")
    var label: String?

    @Option(name: .shortAndLong, help: "Filter by identifier (substring)")
    var identifier: String?

    @Option(name: .long, help: "Which match if multiple (0-indexed)")
    var index: Int = 0

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    @Option(name: .long, help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target,
            ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: identifier,
            index: index
        )

        let acted = AXEngine.performAction(el, action: kAXPressAction as String)
            || AXEngine.performAction(el, action: kAXConfirmAction as String)

        struct ClickResult: Codable {
            let action: String; let success: Bool; let element: AXNode
        }
        let effectiveFormat = json ? OutputFormat.json : format
        let result = ClickResult(action: "AXPress", success: acted, element: node)
        if effectiveFormat == .text {
            print("\(acted ? "✓" : "✗") Clicked: \(node.description)")
        } else {
            Output.print(result, format: .json)
        }
        if !acted { throw AXError.actionFailed("AXPress", node.path) }
    }
}
```

### `./Sources/AgentNative/Commands/FindCommand.swift`

```swift
import ArgumentParser
import Foundation

struct FindCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "find",
        abstract: "Find accessibility elements matching filters"
    )

    @Argument(help: "App name")
    var app: String

    @Option(name: .shortAndLong, help: "Filter by role (e.g. AXButton, AXTextField)")
    var role: String?

    @Option(name: .shortAndLong, help: "Filter by title (substring match)")
    var title: String?

    @Option(name: .shortAndLong, help: "Filter by accessibility label (substring match)")
    var label: String?

    @Option(name: .shortAndLong, help: "Filter by identifier (substring match)")
    var identifier: String?

    @Option(name: .shortAndLong, help: "Filter by value (substring match)")
    var value: String?

    @Option(name: .long, help: "Max search depth")
    var depth: Int = 10

    @Option(name: .shortAndLong, help: "Max results")
    var max: Int = 20

    @Option(name: .long, help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() throws {
        guard AXEngine.checkAccess() else {
            AXEngine.requestAccess()
            throw AXError.accessDenied
        }

        guard let runningApp = AXEngine.findApp(app) else {
            throw AXError.appNotFound(app)
        }

        let element = AXEngine.appElement(pid: runningApp.processIdentifier)

        let results = AXEngine.findElements(
            root: element,
            role: role,
            title: title,
            label: label,
            identifier: identifier,
            value: value,
            maxDepth: depth,
            maxResults: max
        )

        let nodes = results.map(\.node)

        if format == .text {
            print("Found \(nodes.count) element(s) in \(runningApp.localizedName ?? app):")
            print("─────────────────────────────────────────────")
            for (i, node) in nodes.enumerated() {
                print("  [\(i)] \(node.description)")
                print("       path: \(node.path)")
            }
        } else {
            Output.print(nodes, format: format)
        }
    }
}
```

### `./Sources/AgentNative/Commands/GetCommand.swift`

```swift
import ArgumentParser
import ApplicationServices
import Foundation

struct GetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get text, value, or attribute from an element",
        subcommands: [GetText.self, GetValue.self, GetAttr.self, GetTitle.self]
    )
}

struct GetText: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "text",
        abstract: "Get the text content of an element"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: nil, index: index
        )

        // Try AXValue first, then AXTitle, then AXDescription
        let text = AXEngine.stringAttr(el, kAXValueAttribute as String)
            ?? AXEngine.stringAttr(el, kAXTitleAttribute as String)
            ?? AXEngine.stringAttr(el, kAXDescriptionAttribute as String)
            ?? ""

        struct GetResult: Codable { let text: String; let element: AXNode }
        if json {
            Output.print(GetResult(text: text, element: node), format: .json)
        } else {
            print(text)
        }
    }
}

struct GetValue: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "value",
        abstract: "Get the value of an input element"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: nil, index: index
        )

        var rawVal: AnyObject?
        AXUIElementCopyAttributeValue(el, kAXValueAttribute as String as CFString, &rawVal)
        let value: String
        if let s = rawVal as? String { value = s }
        else if let n = rawVal as? NSNumber { value = n.stringValue }
        else { value = "" }

        struct GetResult: Codable { let value: String; let element: AXNode }
        if json {
            Output.print(GetResult(value: value, element: node), format: .json)
        } else {
            print(value)
        }
    }
}

struct GetAttr: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "attr",
        abstract: "Get a specific attribute of an element"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Argument(help: "Attribute name (e.g. AXRole, AXValue, AXEnabled)")
    var attribute: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: nil, index: index
        )

        var rawVal: AnyObject?
        AXUIElementCopyAttributeValue(el, attribute as CFString, &rawVal)
        let value: String
        if let s = rawVal as? String { value = s }
        else if let n = rawVal as? NSNumber { value = n.stringValue }
        else if let arr = rawVal as? [AnyObject] { value = "[\(arr.count) items]" }
        else { value = rawVal.map { String(describing: $0) } ?? "(nil)" }

        struct GetResult: Codable { let attribute: String; let value: String; let element: AXNode }
        if json {
            Output.print(GetResult(attribute: attribute, value: value, element: node), format: .json)
        } else {
            print(value)
        }
    }
}

struct GetTitle: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "title",
        abstract: "Get the title of the frontmost window of an app"
    )

    @Argument(help: "App name")
    var app: String

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        guard let runningApp = AXEngine.findApp(app) else {
            throw AXError.appNotFound(app)
        }
        let el = AXEngine.appElement(pid: runningApp.processIdentifier)
        let windows: [AXUIElement] = AXEngine.children(el).filter {
            AXEngine.stringAttr($0, kAXRoleAttribute as String) == "AXWindow"
        }
        let title = windows.first.flatMap { AXEngine.stringAttr($0, kAXTitleAttribute as String) } ?? ""

        struct TitleResult: Codable { let title: String }
        if json {
            Output.print(TitleResult(title: title), format: .json)
        } else {
            print(title)
        }
    }
}
```

### `./Sources/AgentNative/Commands/InspectCommand.swift`

```swift
import ArgumentParser
import ApplicationServices
import Foundation

struct InspectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inspect",
        abstract: "Inspect all attributes and actions of an element. Use @ref or filter flags."
    )

    @Argument(help: "Target: @ref (e.g. @n3) or app name")
    var target: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?

    @Option(name: .shortAndLong, help: "Filter by title (substring)")
    var title: String?

    @Option(name: .shortAndLong, help: "Filter by label (substring)")
    var label: String?

    @Option(name: .shortAndLong, help: "Filter by identifier (substring)")
    var identifier: String?

    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    @Option(name: .long, help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target,
            ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: identifier,
            index: index
        )

        // Get all attribute names
        var attrNames: CFArray?
        AXUIElementCopyAttributeNames(el, &attrNames)
        let names = (attrNames as? [String]) ?? []

        var attrs: [String: String] = [:]
        for name in names {
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(el, name as CFString, &value)
            if result == .success, let v = value {
                if let s = v as? String { attrs[name] = s }
                else if let n = v as? NSNumber { attrs[name] = n.stringValue }
                else if let arr = v as? [AnyObject] { attrs[name] = "[\(arr.count) items]" }
                else { attrs[name] = String(describing: type(of: v)) }
            }
        }

        let actions = AXEngine.actions(el)

        struct InspectResult: Codable {
            let element: AXNode; let attributes: [String: String]; let actions: [String]
        }

        let effectiveFormat = json ? OutputFormat.json : format
        let result = InspectResult(element: node, attributes: attrs, actions: actions)

        if effectiveFormat == .text {
            print("Element: \(node.description)")
            print("Path: \(node.path)")
            print("─── Attributes ───")
            for (key, value) in attrs.sorted(by: { $0.key < $1.key }) {
                let truncated = value.count > 80 ? String(value.prefix(80)) + "…" : value
                print("  \(key): \(truncated)")
            }
            print("─── Actions ───")
            for action in actions { print("  \(action)") }
        } else {
            Output.print(result, format: .json)
        }
    }
}
```

### `./Sources/AgentNative/Commands/InteractionCommands.swift`

```swift
import ArgumentParser
import Foundation

// MARK: - Focus

struct FocusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "focus",
        abstract: "Focus an element"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .shortAndLong, help: "Filter by identifier")
    var identifier: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: identifier, index: index
        )
        let success = AXEngine.setFocus(el)

        struct Result: Codable { let action: String; let success: Bool; let element: AXNode }
        if json { Output.print(Result(action: "focus", success: success, element: node), format: .json) }
        else { print("\(success ? "✓" : "✗") Focused: \(node.description)") }
    }
}

// MARK: - Hover (raise/activate)

struct HoverCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hover",
        abstract: "Hover an element (moves cursor position via AX)"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: nil, index: index
        )

        // Move the cursor to the center of the element
        if let pos = AXEngine.position(el), let sz = AXEngine.size(el) {
            let center = CGPoint(x: pos.x + sz.width / 2, y: pos.y + sz.height / 2)
            CGWarpMouseCursorPosition(center)
        }

        struct Result: Codable { let action: String; let element: AXNode }
        if json { Output.print(Result(action: "hover", element: node), format: .json) }
        else { print("✓ Hovered: \(node.description)") }
    }
}

// MARK: - Check / Uncheck

struct CheckCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Check a checkbox / toggle (sets value to 1)"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: role ?? "CheckBox", title: title, label: label, identifier: nil, index: index
        )

        // If already checked (value == 1), skip
        var rawVal: AnyObject?
        AXUIElementCopyAttributeValue(el, kAXValueAttribute as String as CFString, &rawVal)
        let currentValue = (rawVal as? NSNumber)?.intValue ?? 0

        var success = true
        if currentValue == 0 {
            success = AXEngine.performAction(el, action: kAXPressAction as String)
        }

        struct Result: Codable { let action: String; let success: Bool; let element: AXNode }
        if json { Output.print(Result(action: "check", success: success, element: node), format: .json) }
        else { print("\(success ? "✓" : "✗") Checked: \(node.description)") }
    }
}

struct UncheckCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "uncheck",
        abstract: "Uncheck a checkbox / toggle (sets value to 0)"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: role ?? "CheckBox", title: title, label: label, identifier: nil, index: index
        )

        var rawVal: AnyObject?
        AXUIElementCopyAttributeValue(el, kAXValueAttribute as String as CFString, &rawVal)
        let currentValue = (rawVal as? NSNumber)?.intValue ?? 0

        var success = true
        if currentValue == 1 {
            success = AXEngine.performAction(el, action: kAXPressAction as String)
        }

        struct Result: Codable { let action: String; let success: Bool; let element: AXNode }
        if json { Output.print(Result(action: "uncheck", success: success, element: node), format: .json) }
        else { print("\(success ? "✓" : "✗") Unchecked: \(node.description)") }
    }
}

// MARK: - Fill (clear + type)

struct FillCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fill",
        abstract: "Clear a field and type new text (like agent-browser fill)"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Argument(help: "Text to fill")
    var text: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: isRef ? nil : (role ?? "TextField"),
            title: title, label: label, identifier: nil, index: index
        )

        AXEngine.setFocus(el)
        Thread.sleep(forTimeInterval: 0.1)

        // Clear first, then set
        AXEngine.setValue(el, value: "")
        let success = AXEngine.setValue(el, value: text)

        struct Result: Codable { let action: String; let success: Bool; let text: String; let element: AXNode }
        if json { Output.print(Result(action: "fill", success: success, text: text, element: node), format: .json) }
        else { print("\(success ? "✓" : "✗") Filled: \(node.description) with \"\(text)\"") }
    }
}

// MARK: - Select (for popup buttons / combo boxes)

struct SelectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "select",
        abstract: "Select an option from a popup button / combo box"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Argument(help: "Option to select (by title)")
    var option: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: isRef ? nil : (role ?? "PopUpButton"),
            title: title, label: label, identifier: nil, index: index
        )

        // Open the popup
        AXEngine.performAction(el, action: kAXPressAction as String)
        Thread.sleep(forTimeInterval: 0.5)

        // Find the menu item matching the option text
        let menuItems = AXEngine.findElements(
            root: el,
            role: "AXMenuItem",
            title: option,
            maxDepth: 5,
            maxResults: 1
        )

        var success = false
        if let (menuItem, _) = menuItems.first {
            success = AXEngine.performAction(menuItem, action: kAXPressAction as String)
        }

        struct Result: Codable { let action: String; let success: Bool; let option: String; let element: AXNode }
        if json { Output.print(Result(action: "select", success: success, option: option, element: node), format: .json) }
        else { print("\(success ? "✓" : "✗") Selected \"\(option)\" in: \(node.description)") }
    }
}
```

### `./Sources/AgentNative/Commands/IsCommand.swift`

```swift
import ArgumentParser
import ApplicationServices
import Foundation

struct IsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "is",
        abstract: "Check element state",
        subcommands: [IsEnabled.self, IsFocused.self]
    )
}

struct IsEnabled: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "enabled",
        abstract: "Check if an element is enabled"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, _, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: nil, index: index
        )
        let enabled = AXEngine.boolAttr(el, kAXEnabledAttribute as String)
        struct Result: Codable { let enabled: Bool }
        if json { Output.print(Result(enabled: enabled), format: .json) }
        else { print(enabled) }
    }
}

struct IsFocused: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "focused",
        abstract: "Check if an element is focused"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, _, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: nil, index: index
        )
        let focused = AXEngine.boolAttr(el, kAXFocusedAttribute as String)
        struct Result: Codable { let focused: Bool }
        if json { Output.print(Result(focused: focused), format: .json) }
        else { print(focused) }
    }
}
```

### `./Sources/AgentNative/Commands/OpenCommand.swift`

```swift
import ArgumentParser
import Foundation

struct OpenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Open/launch an application by name or bundle ID"
    )

    @Argument(help: "App name or bundle identifier (e.g. 'Safari' or 'com.apple.Safari')")
    var app: String

    @Option(name: .long, help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() throws {
        let pid = try AXEngine.openApp(app)

        struct Result: Codable {
            let app: String
            let pid: Int32
            let status: String
        }

        let result = Result(app: app, pid: pid, status: "launched")
        Output.print(result, format: format)

        if format == .text {
            print("✓ Opened \(app) (pid \(pid))")
        }
    }
}
```

### `./Sources/AgentNative/Commands/SnapshotCommand.swift`

```swift
import ArgumentParser
import ApplicationServices
import Foundation

struct SnapshotCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "snapshot",
        abstract: "Accessibility tree snapshot with refs (@n1, @n2) for interaction"
    )

    @Argument(help: "App name")
    var app: String

    @Flag(name: .shortAndLong, help: "Interactive elements only (buttons, inputs, checkboxes, links, etc.)")
    var interactive: Bool = false

    @Flag(name: .shortAndLong, help: "Compact output — remove empty structural elements")
    var compact: Bool = false

    @Option(name: .shortAndLong, help: "Max tree depth")
    var depth: Int = 8

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    @Option(name: .long, help: "Output format: text or json")
    var format: OutputFormat = .text

    /// Roles considered "interactive" (matching agent-browser's -i flag)
    static let interactiveRoles: Set<String> = [
        "AXButton", "AXTextField", "AXTextArea", "AXCheckBox",
        "AXRadioButton", "AXPopUpButton", "AXComboBox", "AXSlider",
        "AXMenuButton", "AXLink", "AXTab", "AXMenuItem",
        "AXMenuBarItem", "AXSwitch", "AXToggle", "AXSearchField",
        "AXSecureTextField", "AXStepper", "AXDisclosureTriangle",
        "AXIncrementor", "AXColorWell", "AXSegmentedControl",
    ]

    func run() throws {
        guard AXEngine.checkAccess() else {
            AXEngine.requestAccess()
            throw AXError.accessDenied
        }

        guard let runningApp = AXEngine.findApp(app) else {
            throw AXError.appNotFound(app)
        }

        let pid = runningApp.processIdentifier
        let element = AXEngine.appElement(pid: pid)
        let tree = AXEngine.walkTree(element, maxDepth: depth)

        // Assign refs to elements
        var refCounter = 0
        var refEntries: [RefStore.RefEntry] = []

        struct RefNode: Codable {
            let ref: String
            let role: String
            let title: String?
            let label: String?
            let value: String?
            let enabled: Bool
            let actions: [String]
            let depth: Int
        }

        var refNodes: [RefNode] = []

        for (node, d) in tree {
            // Skip non-interactive elements if -i flag
            if interactive && !Self.interactiveRoles.contains(node.role) {
                continue
            }

            // Skip empty structural elements if -c flag
            if compact && node.title == nil && node.label == nil
                && node.value == nil && node.actions.isEmpty
                && node.childCount > 0
            {
                continue
            }

            refCounter += 1
            let ref = "n\(refCounter)"

            refEntries.append(RefStore.RefEntry(
                ref: ref,
                pid: pid,
                role: node.role,
                title: node.title,
                label: node.label,
                identifier: node.identifier,
                pathHint: node.path
            ))

            refNodes.append(RefNode(
                ref: ref,
                role: node.role,
                title: node.title,
                label: node.label,
                value: node.value,
                enabled: node.enabled,
                actions: node.actions,
                depth: d
            ))
        }

        // Persist refs for later commands
        RefStore.save(refEntries)

        let effectiveFormat = json ? OutputFormat.json : format

        if effectiveFormat == .json {
            if let data = try? Output.jsonEncoder.encode(refNodes),
               let str = String(data: data, encoding: .utf8)
            {
                print(str)
            }
        } else {
            let appName = runningApp.localizedName ?? app
            print("Snapshot: \(appName) (pid \(pid)) — \(refNodes.count) elements")
            print("─────────────────────────────────────────────")
            for rn in refNodes {
                let indent = String(repeating: "  ", count: rn.depth)
                var line = "\(indent)\(rn.role)"
                if let t = rn.title { line += " \"\(t)\"" }
                else if let l = rn.label { line += " (\(l))" }
                if let v = rn.value {
                    let truncated = v.count > 40 ? String(v.prefix(40)) + "…" : v
                    line += " = \"\(truncated)\""
                }
                if !rn.actions.isEmpty {
                    line += " [\(rn.actions.joined(separator: ", "))]"
                }
                line += " [ref=\(rn.ref)]"
                if !rn.enabled { line += " (disabled)" }
                print(line)
            }
        }
    }
}
```

### `./Sources/AgentNative/Commands/TreeCommand.swift`

```swift
import ArgumentParser
import Foundation

struct TreeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tree",
        abstract: "Print the accessibility tree for an application"
    )

    @Argument(help: "App name (e.g. 'Safari', 'System Settings')")
    var app: String

    @Option(name: .shortAndLong, help: "Maximum tree depth to traverse")
    var depth: Int = 5

    @Option(name: .long, help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() throws {
        guard AXEngine.checkAccess() else {
            AXEngine.requestAccess()
            throw AXError.accessDenied
        }

        guard let runningApp = AXEngine.findApp(app) else {
            throw AXError.appNotFound(app)
        }

        let element = AXEngine.appElement(pid: runningApp.processIdentifier)
        let tree = AXEngine.walkTree(element, maxDepth: depth)

        if format == .text {
            print("Accessibility tree for \(runningApp.localizedName ?? app) (pid \(runningApp.processIdentifier)):")
            print("─────────────────────────────────────────────")
        }

        Output.printTree(tree, format: format)
    }
}
```

### `./Sources/AgentNative/Commands/TypeCommand.swift`

```swift
import ArgumentParser
import Foundation

struct TypeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Type text into an element. Use @ref from snapshot or filter flags."
    )

    @Argument(help: "Target: @ref (e.g. @n3) or app name")
    var target: String

    @Argument(help: "Text to type")
    var text: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?

    @Option(name: .shortAndLong, help: "Filter by title (substring)")
    var title: String?

    @Option(name: .shortAndLong, help: "Filter by label (substring)")
    var label: String?

    @Option(name: .shortAndLong, help: "Filter by identifier (substring)")
    var identifier: String?

    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    @Option(name: .long, help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() throws {
        let isRef = target.hasPrefix("@")

        // For non-ref, if no role specified, default to text input roles
        let searchRole = isRef ? nil : (role ?? "TextField")

        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target,
            ref: isRef ? target : nil,
            role: isRef ? nil : searchRole,
            title: title, label: label, identifier: identifier,
            index: index
        )

        AXEngine.setFocus(el)
        Thread.sleep(forTimeInterval: 0.1)
        let success = AXEngine.setValue(el, value: text)

        struct TypeResult: Codable {
            let action: String; let success: Bool; let text: String; let element: AXNode
        }
        let effectiveFormat = json ? OutputFormat.json : format
        let result = TypeResult(action: "setValue", success: success, text: text, element: node)
        if effectiveFormat == .text {
            print("\(success ? "✓" : "✗") Typed \"\(text)\" into: \(node.description)")
        } else {
            Output.print(result, format: .json)
        }
        if !success { throw AXError.actionFailed("setValue", node.path) }
    }
}
```

### `./Sources/AgentNative/Commands/WaitCommand.swift`

```swift
import ArgumentParser
import Foundation

struct WaitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wait",
        abstract: "Wait until an element matching the filters appears (polling)"
    )

    @Argument(help: "App name")
    var app: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?

    @Option(name: .shortAndLong, help: "Filter by title (substring)")
    var title: String?

    @Option(name: .shortAndLong, help: "Filter by label (substring)")
    var label: String?

    @Option(name: .shortAndLong, help: "Filter by identifier (substring)")
    var identifier: String?

    @Option(name: .long, help: "Timeout in seconds")
    var timeout: Double = 10.0

    @Option(name: .long, help: "Poll interval in seconds")
    var interval: Double = 0.5

    @Option(name: .long, help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() throws {
        guard AXEngine.checkAccess() else {
            AXEngine.requestAccess()
            throw AXError.accessDenied
        }

        guard let runningApp = AXEngine.findApp(app) else {
            throw AXError.appNotFound(app)
        }

        let element = AXEngine.appElement(pid: runningApp.processIdentifier)
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let results = AXEngine.findElements(
                root: element,
                role: role, title: title, label: label, identifier: identifier,
                maxResults: 1
            )

            if let (_, node) = results.first {
                struct WaitResult: Codable {
                    let found: Bool
                    let element: AXNode
                }
                let result = WaitResult(found: true, element: node)

                if format == .text {
                    print("✓ Found: \(node.description)")
                } else {
                    Output.print(result, format: format)
                }
                return
            }

            Thread.sleep(forTimeInterval: interval)
        }

        let filterDesc = [
            role.map { "role=\($0)" },
            title.map { "title=\($0)" },
            label.map { "label=\($0)" },
            identifier.map { "id=\($0)" },
        ].compactMap { $0 }.joined(separator: ", ")

        throw AXError.timeout("No element matching [\(filterDesc)] found within \(timeout)s")
    }
}
```

### `./Sources/AgentNative/Core/AXEngine.swift`

```swift
import AppKit
import ApplicationServices

// MARK: - Errors

enum AXError: Error, CustomStringConvertible {
    case appNotFound(String)
    case elementNotFound(String)
    case actionFailed(String, String)
    case accessDenied
    case attributeError(String)
    case timeout(String)

    var description: String {
        switch self {
        case .appNotFound(let name): return "App not found: \(name)"
        case .elementNotFound(let path): return "Element not found at path: \(path)"
        case .actionFailed(let action, let path): return "Action '\(action)' failed on: \(path)"
        case .accessDenied: return "Accessibility access denied. Enable in System Settings → Privacy & Security → Accessibility"
        case .attributeError(let msg): return "Attribute error: \(msg)"
        case .timeout(let msg): return "Timeout: \(msg)"
        }
    }
}

// MARK: - Engine

final class AXEngine {

    // MARK: - App discovery

    struct AppInfo: Codable {
        let name: String
        let bundleId: String?
        let pid: Int32
        let isActive: Bool
        let isHidden: Bool
    }

    /// List all running GUI applications.
    static func listApps() -> [AppInfo] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let name = app.localizedName else { return nil }
                return AppInfo(
                    name: name,
                    bundleId: app.bundleIdentifier,
                    pid: app.processIdentifier,
                    isActive: app.isActive,
                    isHidden: app.isHidden
                )
            }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Find a running app by name (case-insensitive prefix match).
    static func findApp(_ query: String) -> NSRunningApplication? {
        let q = query.lowercased()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .first { ($0.localizedName ?? "").lowercased().hasPrefix(q) }
            ?? NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .first { ($0.localizedName ?? "").lowercased().contains(q) }
    }

    /// Launch an app by name or bundle ID, returns its PID.
    static func openApp(_ nameOrBundleId: String) throws -> Int32 {
        // Try bundle ID first
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: nameOrBundleId) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            let semaphore = DispatchSemaphore(value: 0)
            var resultApp: NSRunningApplication?
            var resultError: Error?
            NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
                resultApp = app
                resultError = error
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 10)
            if let err = resultError { throw AXError.appNotFound("\(nameOrBundleId): \(err)") }
            if let app = resultApp { return app.processIdentifier }
        }

        // Try by name via `open -a`
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", nameOrBundleId]
        try process.run()
        process.waitUntilExit()

        // Wait briefly for the app to register
        Thread.sleep(forTimeInterval: 1.0)

        guard let app = findApp(nameOrBundleId) else {
            throw AXError.appNotFound(nameOrBundleId)
        }
        return app.processIdentifier
    }

    // MARK: - AX element helpers

    /// Get the AXUIElement for an app by PID.
    static func appElement(pid: Int32) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    /// Read a single attribute value from an element.
    static func attribute<T>(_ element: AXUIElement, _ attr: String) -> T? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard result == .success else { return nil }
        return value as? T
    }

    /// Read the string value of an attribute.
    static func stringAttr(_ element: AXUIElement, _ attr: String) -> String? {
        attribute(element, attr)
    }

    /// Read a boolean attribute.
    static func boolAttr(_ element: AXUIElement, _ attr: String) -> Bool {
        let val: AnyObject? = {
            var v: AnyObject?
            AXUIElementCopyAttributeValue(element, attr as CFString, &v)
            return v
        }()
        if let num = val as? NSNumber { return num.boolValue }
        return false
    }

    /// Get the position of an element.
    static func position(_ element: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as String as CFString, &value)
        guard result == .success, let val = value else { return nil }
        var point = CGPoint.zero
        if AXValueGetValue(val as! AXValue, .cgPoint, &point) { return point }
        return nil
    }

    /// Get the size of an element.
    static func size(_ element: AXUIElement) -> CGSize? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as String as CFString, &value)
        guard result == .success, let val = value else { return nil }
        var size = CGSize.zero
        if AXValueGetValue(val as! AXValue, .cgSize, &size) { return size }
        return nil
    }

    /// Get the children of an element.
    static func children(_ element: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as String as CFString, &value)
        guard result == .success, let arr = value as? [AXUIElement] else { return [] }
        return arr
    }

    /// Get available actions for an element.
    static func actions(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        let result = AXUIElementCopyActionNames(element, &names)
        guard result == .success, let arr = names as? [String] else { return [] }
        return arr
    }

    // MARK: - Build the tree

    /// Convert an AXUIElement into an AXNode (non-recursive snapshot).
    static func nodeFrom(_ element: AXUIElement, path: String) -> AXNode {
        let role = stringAttr(element, kAXRoleAttribute as String) ?? "AXUnknown"
        let subrole = stringAttr(element, kAXSubroleAttribute as String)
        let title = stringAttr(element, kAXTitleAttribute as String)
        let label = stringAttr(element, kAXDescriptionAttribute as String)
        let identifier = stringAttr(element, kAXIdentifierAttribute as String)
        let enabled = boolAttr(element, kAXEnabledAttribute as String)
        let focused = boolAttr(element, kAXFocusedAttribute as String)

        // Value can be many types — coerce to string
        var rawVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as String as CFString, &rawVal)
        let value: String? = rawVal.flatMap { v in
            if let s = v as? String { return s }
            if let n = v as? NSNumber { return n.stringValue }
            return nil
        }

        return AXNode(
            role: role,
            subrole: subrole,
            title: title,
            value: value,
            label: label,
            identifier: identifier,
            enabled: enabled,
            focused: focused,
            position: position(element),
            size: size(element),
            path: path,
            actions: actions(element),
            childCount: children(element).count
        )
    }

    /// Recursively walk the AX tree up to `maxDepth`, collecting AXNodes.
    static func walkTree(
        _ element: AXUIElement,
        path: String = "",
        depth: Int = 0,
        maxDepth: Int = 5
    ) -> [(node: AXNode, depth: Int)] {
        let role = stringAttr(element, kAXRoleAttribute as String) ?? "AXUnknown"
        let title = stringAttr(element, kAXTitleAttribute as String)
        let label = stringAttr(element, kAXDescriptionAttribute as String)

        // Build a path segment like AXButton[@title="OK"]
        var segment = role
        if let t = title { segment += "[@title=\"\(t)\"]" }
        else if let l = label { segment += "[@label=\"\(l)\"]" }

        let fullPath = path.isEmpty ? "/\(segment)" : "\(path)/\(segment)"
        let node = nodeFrom(element, path: fullPath)
        var results: [(AXNode, Int)] = [(node, depth)]

        guard depth < maxDepth else { return results }

        // Index children by role for disambiguation
        var roleCounts: [String: Int] = [:]
        for child in children(element) {
            let childRole = stringAttr(child, kAXRoleAttribute as String) ?? "AXUnknown"
            let childTitle = stringAttr(child, kAXTitleAttribute as String)
            let childLabel = stringAttr(child, kAXDescriptionAttribute as String)

            var childSegment = childRole
            if let t = childTitle { childSegment += "[@title=\"\(t)\"]" }
            else if let l = childLabel { childSegment += "[@label=\"\(l)\"]" }

            let idx = roleCounts[childSegment, default: 0]
            roleCounts[childSegment] = idx + 1

            let childPath = "\(fullPath)/\(childSegment)[\(idx)]"
            results += walkTree(child, path: fullPath, depth: depth + 1, maxDepth: maxDepth)
        }

        return results
    }

    // MARK: - Element resolution by path or query

    /// Find elements matching a filter in the subtree.
    static func findElements(
        root: AXUIElement,
        role: String? = nil,
        title: String? = nil,
        label: String? = nil,
        identifier: String? = nil,
        value: String? = nil,
        maxDepth: Int = 10,
        maxResults: Int = 50
    ) -> [(element: AXUIElement, node: AXNode)] {
        var results: [(AXUIElement, AXNode)] = []
        findElementsRecursive(
            element: root, parentPath: "",
            role: role, title: title, label: label,
            identifier: identifier, value: value,
            depth: 0, maxDepth: maxDepth,
            maxResults: maxResults, results: &results
        )
        return results
    }

    private static func findElementsRecursive(
        element: AXUIElement,
        parentPath: String,
        role: String?,
        title: String?,
        label: String?,
        identifier: String?,
        value: String?,
        depth: Int,
        maxDepth: Int,
        maxResults: Int,
        results: inout [(AXUIElement, AXNode)]
    ) {
        guard results.count < maxResults, depth <= maxDepth else { return }

        let elemRole = stringAttr(element, kAXRoleAttribute as String) ?? "AXUnknown"
        let elemTitle = stringAttr(element, kAXTitleAttribute as String)
        let elemLabel = stringAttr(element, kAXDescriptionAttribute as String)
        let elemId = stringAttr(element, kAXIdentifierAttribute as String)

        var rawVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as String as CFString, &rawVal)
        let elemValue = (rawVal as? String) ?? (rawVal as? NSNumber)?.stringValue

        var segment = elemRole
        if let t = elemTitle { segment += "[@title=\"\(t)\"]" }
        let currentPath = parentPath.isEmpty ? "/\(segment)" : "\(parentPath)/\(segment)"

        // Check if this element matches all provided filters
        var matches = true
        if let r = role, !elemRole.lowercased().contains(r.lowercased()) { matches = false }
        if let t = title, !(elemTitle ?? "").lowercased().contains(t.lowercased()) { matches = false }
        if let l = label, !(elemLabel ?? "").lowercased().contains(l.lowercased()) { matches = false }
        if let i = identifier, !(elemId ?? "").lowercased().contains(i.lowercased()) { matches = false }
        if let v = value, !(elemValue ?? "").lowercased().contains(v.lowercased()) { matches = false }

        if matches {
            let node = nodeFrom(element, path: currentPath)
            results.append((element, node))
        }

        for child in children(element) {
            findElementsRecursive(
                element: child, parentPath: currentPath,
                role: role, title: title, label: label,
                identifier: identifier, value: value,
                depth: depth + 1, maxDepth: maxDepth,
                maxResults: maxResults, results: &results
            )
        }
    }

    // MARK: - Actions

    /// Perform an accessibility action on an element.
    @discardableResult
    static func performAction(_ element: AXUIElement, action: String) -> Bool {
        let result = AXUIElementPerformAction(element, action as CFString)
        return result == .success
    }

    /// Set a value on an element (e.g., typing into a text field).
    @discardableResult
    static func setValue(_ element: AXUIElement, value: String) -> Bool {
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as String as CFString, value as CFTypeRef)
        return result == .success
    }

    /// Set focus on an element.
    @discardableResult
    static func setFocus(_ element: AXUIElement) -> Bool {
        let result = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as String as CFString, true as CFTypeRef)
        return result == .success
    }

    // MARK: - Convenience

    /// Check if we have accessibility permissions.
    static func checkAccess() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant accessibility access.
    static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
```

### `./Sources/AgentNative/Core/AXNode.swift`

```swift
import AppKit
import ApplicationServices

/// Lightweight, serializable representation of an AXUIElement node.
struct AXNode: Codable, CustomStringConvertible {
    let role: String
    let subrole: String?
    let title: String?
    let value: String?
    let label: String?  // accessibilityLabel / AXDescription
    let identifier: String?  // AXIdentifier
    let enabled: Bool
    let focused: Bool
    let position: CGPoint?
    let size: CGSize?
    let path: String  // addressable path e.g. /AXWindow[0]/AXButton[@title="OK"]
    let actions: [String]
    let childCount: Int

    var description: String {
        var parts: [String] = [role]
        if let title = title { parts.append("title=\"\(title)\"") }
        if let label = label { parts.append("label=\"\(label)\"") }
        if let value = value {
            let truncated = value.count > 60 ? String(value.prefix(60)) + "…" : value
            parts.append("value=\"\(truncated)\"")
        }
        if let identifier = identifier { parts.append("id=\"\(identifier)\"") }
        if !enabled { parts.append("disabled") }
        if focused { parts.append("focused") }
        if !actions.isEmpty { parts.append("actions=[\(actions.joined(separator: ","))]") }
        return parts.joined(separator: " ")
    }
}

// MARK: - CGPoint / CGSize Codable conformance for older toolchains
extension CGPoint: @retroactive Codable {
    enum CodingKeys: String, CodingKey { case x, y }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: try c.decode(CGFloat.self, forKey: .x),
                  y: try c.decode(CGFloat.self, forKey: .y))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
    }
}

extension CGSize: @retroactive Codable {
    enum CodingKeys: String, CodingKey { case width, height }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(width: try c.decode(CGFloat.self, forKey: .width),
                  height: try c.decode(CGFloat.self, forKey: .height))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
    }
}
```

### `./Sources/AgentNative/Core/ElementResolver.swift`

```swift
import ApplicationServices
import Foundation

/// Shared logic: resolve an element either by @ref or by filter flags.
struct ElementResolver {

    /// If the first positional arg starts with @, resolve via RefStore.
    /// Otherwise, resolve via AXEngine.findElements with the given filters.
    static func resolve(
        app: String?,
        ref: String?,
        role: String?,
        title: String?,
        label: String?,
        identifier: String?,
        index: Int = 0
    ) throws -> (element: AXUIElement, node: AXNode, appName: String) {

        // Ref-based resolution: @n1, @n5, etc.
        if let ref = ref, ref.hasPrefix("@") {
            let (el, node) = try RefStore.resolve(ref: ref)
            return (el, node, "")
        }

        // Filter-based resolution — requires app name
        guard let appName = app else {
            throw AXError.appNotFound("App name required when not using @ref")
        }

        guard AXEngine.checkAccess() else {
            AXEngine.requestAccess()
            throw AXError.accessDenied
        }

        guard let runningApp = AXEngine.findApp(appName) else {
            throw AXError.appNotFound(appName)
        }

        runningApp.activate()
        Thread.sleep(forTimeInterval: 0.3)

        let appElement = AXEngine.appElement(pid: runningApp.processIdentifier)
        let results = AXEngine.findElements(
            root: appElement,
            role: role, title: title, label: label, identifier: identifier
        )

        guard index < results.count else {
            let msg = "Found \(results.count) matches, requested index \(index)"
            throw AXError.elementNotFound(msg)
        }

        let (target, node) = results[index]
        return (target, node, runningApp.localizedName ?? appName)
    }
}
```

### `./Sources/AgentNative/Core/Output.swift`

```swift
import Foundation

enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
    case text
    case json

    // For ArgumentParser
    init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }
}

struct Output {
    static let jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static func print<T: Encodable>(_ value: T, format: OutputFormat) {
        switch format {
        case .json:
            if let data = try? jsonEncoder.encode(value),
               let str = String(data: data, encoding: .utf8) {
                Swift.print(str)
            }
        case .text:
            if let node = value as? AXNode {
                Swift.print(node.description)
            } else if let nodes = value as? [AXNode] {
                for n in nodes { Swift.print(n.description) }
            } else if let apps = value as? [AXEngine.AppInfo] {
                for app in apps {
                    let active = app.isActive ? " (active)" : ""
                    let hidden = app.isHidden ? " (hidden)" : ""
                    Swift.print("  \(app.name)  pid=\(app.pid)  \(app.bundleId ?? "")\(active)\(hidden)")
                }
            } else {
                // Fallback to JSON
                if let data = try? jsonEncoder.encode(value),
                   let str = String(data: data, encoding: .utf8) {
                    Swift.print(str)
                }
            }
        }
    }

    /// Print the accessibility tree with indentation.
    static func printTree(_ entries: [(node: AXNode, depth: Int)], format: OutputFormat) {
        switch format {
        case .json:
            let nodes = entries.map(\.node)
            if let data = try? jsonEncoder.encode(nodes),
               let str = String(data: data, encoding: .utf8) {
                Swift.print(str)
            }
        case .text:
            for (node, depth) in entries {
                let indent = String(repeating: "  ", count: depth)
                let actionStr = node.actions.isEmpty ? "" : " [\(node.actions.joined(separator: ", "))]"
                var desc = "\(indent)\(node.role)"
                if let t = node.title { desc += " \"\(t)\"" }
                else if let l = node.label { desc += " (\(l))" }
                if let v = node.value {
                    let truncated = v.count > 40 ? String(v.prefix(40)) + "…" : v
                    desc += " = \"\(truncated)\""
                }
                desc += actionStr
                if node.childCount > 0 { desc += "  ↳ \(node.childCount) children" }
                Swift.print(desc)
            }
        }
    }
}

// Import for ExpressibleByArgument
import ArgumentParser
```

### `./Sources/AgentNative/Core/RefStore.swift`

```swift
import ApplicationServices
import Foundation

/// Manages ref → element mappings from snapshots.
/// Refs are persisted to a temp file so they survive between CLI invocations
/// (each `agent-native` command is a separate process).
final class RefStore {
    /// Stored mapping: ref string → serializable element locator
    struct RefEntry: Codable {
        let ref: String
        let pid: Int32
        let role: String
        let title: String?
        let label: String?
        let identifier: String?
        let pathHint: String  // used for re-resolution
    }

    private static let storePath: URL = {
        let tmp = FileManager.default.temporaryDirectory
        return tmp.appendingPathComponent("agent-native-refs.json")
    }()

    /// Save ref entries to disk.
    static func save(_ entries: [RefEntry]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(entries) {
            try? data.write(to: storePath)
        }
    }

    /// Load ref entries from disk.
    static func load() -> [RefEntry] {
        guard let data = try? Data(contentsOf: storePath),
              let entries = try? JSONDecoder().decode([RefEntry].self, from: data)
        else { return [] }
        return entries
    }

    /// Resolve a ref like "@n5" back to a live AXUIElement.
    /// Re-walks the app tree and matches by role+title+label+identifier.
    static func resolve(ref: String) throws -> (element: AXUIElement, node: AXNode) {
        let entries = load()
        let cleanRef = ref.hasPrefix("@") ? String(ref.dropFirst()) : ref

        guard let entry = entries.first(where: { $0.ref == cleanRef }) else {
            throw AXError.elementNotFound("Unknown ref: @\(cleanRef). Run `snapshot` first.")
        }

        let appElement = AXEngine.appElement(pid: entry.pid)

        // Try to find the element by matching attributes
        let results = AXEngine.findElements(
            root: appElement,
            role: entry.role.isEmpty ? nil : entry.role,
            title: entry.title,
            label: entry.label,
            identifier: entry.identifier,
            maxDepth: 15,
            maxResults: 50
        )

        // Try exact match first
        if let match = results.first(where: { _, node in
            node.role == entry.role
                && node.title == entry.title
                && node.label == entry.label
                && node.identifier == entry.identifier
        }) {
            return match
        }

        // Fallback: first result that matches role
        if let match = results.first {
            return match
        }

        throw AXError.elementNotFound("Could not re-resolve @\(cleanRef). The UI may have changed — run `snapshot` again.")
    }
}
```

### `./TestFixture/TestFixture.swift`

```swift
// TestFixture — a minimal AppKit app with known AX elements for CI testing.
// Build:  swiftc -o TestFixture TestFixture.swift -framework Cocoa
// Run:    ./TestFixture &

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 400, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Agent Native Test Fixture"

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        // ── Label ──
        let label = NSTextField(labelWithString: "Hello from TestFixture")
        label.frame = NSRect(x: 20, y: 340, width: 360, height: 24)
        label.accessibilityIdentifier = "greeting-label"
        contentView.addSubview(label)

        // ── Text Field ──
        let textField = NSTextField(frame: NSRect(x: 20, y: 300, width: 260, height: 24))
        textField.placeholderString = "Type here"
        textField.accessibilityIdentifier = "main-input"
        textField.accessibilityLabel = "Main Input"
        contentView.addSubview(textField)

        // ── Buttons ──
        let submitButton = NSButton(title: "Submit", target: self, action: #selector(submitClicked))
        submitButton.frame = NSRect(x: 290, y: 298, width: 90, height: 28)
        submitButton.accessibilityIdentifier = "submit-button"
        contentView.addSubview(submitButton)

        let resetButton = NSButton(title: "Reset", target: self, action: #selector(resetClicked))
        resetButton.frame = NSRect(x: 290, y: 260, width: 90, height: 28)
        resetButton.accessibilityIdentifier = "reset-button"
        contentView.addSubview(resetButton)

        // ── Checkbox ──
        let checkbox = NSButton(checkboxWithTitle: "Enable notifications", target: nil, action: nil)
        checkbox.frame = NSRect(x: 20, y: 260, width: 250, height: 24)
        checkbox.state = .off
        checkbox.accessibilityIdentifier = "notifications-checkbox"
        contentView.addSubview(checkbox)

        // ── Second Checkbox (starts checked) ──
        let checkbox2 = NSButton(checkboxWithTitle: "Dark mode", target: nil, action: nil)
        checkbox2.frame = NSRect(x: 20, y: 230, width: 250, height: 24)
        checkbox2.state = .on
        checkbox2.accessibilityIdentifier = "darkmode-checkbox"
        contentView.addSubview(checkbox2)

        // ── Popup Button (dropdown) ──
        let popup = NSPopUpButton(frame: NSRect(x: 20, y: 190, width: 200, height: 28))
        popup.addItems(withTitles: ["Option A", "Option B", "Option C"])
        popup.accessibilityIdentifier = "options-popup"
        contentView.addSubview(popup)

        // ── Slider ──
        let slider = NSSlider(value: 50, minValue: 0, maxValue: 100, target: nil, action: nil)
        slider.frame = NSRect(x: 20, y: 150, width: 260, height: 24)
        slider.accessibilityIdentifier = "volume-slider"
        slider.accessibilityLabel = "Volume"
        contentView.addSubview(slider)

        // ── Status label (updated by buttons) ──
        let statusLabel = NSTextField(labelWithString: "Status: idle")
        statusLabel.frame = NSRect(x: 20, y: 110, width: 360, height: 24)
        statusLabel.accessibilityIdentifier = "status-label"
        statusLabel.tag = 999
        contentView.addSubview(statusLabel)

        // ── Disabled button ──
        let disabledButton = NSButton(title: "Disabled Action", target: nil, action: nil)
        disabledButton.frame = NSRect(x: 20, y: 70, width: 150, height: 28)
        disabledButton.isEnabled = false
        disabledButton.accessibilityIdentifier = "disabled-button"
        contentView.addSubview(disabledButton)

        // ── Search field ──
        let searchField = NSSearchField(frame: NSRect(x: 20, y: 30, width: 260, height: 24))
        searchField.placeholderString = "Search..."
        searchField.accessibilityIdentifier = "search-field"
        contentView.addSubview(searchField)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
    }

    @objc func submitClicked() {
        if let statusLabel = window.contentView?.viewWithTag(999) as? NSTextField {
            statusLabel.stringValue = "Status: submitted"
        }
    }

    @objc func resetClicked() {
        if let statusLabel = window.contentView?.viewWithTag(999) as? NSTextField {
            statusLabel.stringValue = "Status: reset"
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
```

### `./skills/agent-native/SKILL.md`

`````
---
name: agent-native
description: macOS native app automation CLI for AI agents. Use when the user needs to interact with macOS desktop applications, including opening apps, clicking buttons, toggling settings, filling forms, reading UI state, automating System Settings, controlling Finder, Safari, or any native app. Triggers include requests to "open an app", "click a button in System Settings", "toggle Wi-Fi", "automate a Mac app", "read what's on screen", "fill in a form in a desktop app", "check if a setting is enabled", or any task requiring programmatic control of macOS native applications via the Accessibility tree.
---

# agent-native

macOS native app automation via the Accessibility tree. Like agent-browser, but for desktop apps.

## Prerequisites

- macOS 13+ with Accessibility permissions granted to your terminal
- Binary at `agent-native` (install via `swift build -c release && cp .build/release/agent-native /usr/local/bin/`)

## Core Workflow

The primary workflow mirrors agent-browser: **snapshot → read refs → interact by ref → re-snapshot**.

```bash
agent-native open "System Settings"
agent-native snapshot "System Settings" -i    # Get interactive elements with @refs
agent-native click @n5                        # Interact using refs
agent-native snapshot "System Settings" -i    # Re-snapshot after UI changes
```

Always re-snapshot after actions that change the UI (navigation, clicking tabs, opening dialogs). Refs are invalidated when the UI structure changes.

## Commands

### Navigation

```bash
agent-native open <app>                          # Open by name or bundle ID
agent-native open "System Settings"
agent-native open com.apple.Safari
```

### Snapshot (recommended for agents)

```bash
agent-native snapshot <app>                      # Full AX tree with refs
agent-native snapshot <app> -i                   # Interactive elements only (recommended)
agent-native snapshot <app> -i -c                # Interactive + compact
agent-native snapshot <app> -d 3                 # Limit depth
agent-native snapshot <app> -i --json            # JSON for parsing
```

Output example:
```
AXButton "General" [AXPress] [ref=n1]
AXButton "Wi-Fi" [AXPress] [ref=n2]
AXSearchField (Search) = "" [AXConfirm, AXPress] [ref=n3]
AXCheckBox "Wi-Fi" = "1" [AXPress] [ref=n4]
```

| Flag | Description |
|---|---|
| `-i` | Interactive elements only (buttons, inputs, checkboxes, links, etc.) |
| `-c` | Compact — remove empty structural elements |
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
agent-native action @n7 AXShowMenu               # Context menu
```

### Interaction (filter-based, no snapshot needed)

```bash
agent-native click "System Settings" --title "Wi-Fi"
agent-native fill Safari "https://github.com" --label "Address"
agent-native check "System Settings" --title "Wi-Fi" --role AXCheckBox
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

## Chaining

Commands can be chained with `&&`:

```bash
agent-native open Safari && sleep 1 && agent-native snapshot Safari -i
```

Run commands separately when you need to parse output first (snapshot to discover refs, then interact).

## Common Patterns

### Toggle a System Settings switch

```bash
agent-native open "System Settings"
agent-native snapshot "System Settings" -i
# Find the section, e.g. Wi-Fi [ref=n3]
agent-native click @n3
sleep 1
agent-native snapshot "System Settings" -i       # Re-snapshot the pane
# Find the toggle, e.g. AXCheckBox "Wi-Fi" = "1" [ref=n8]
agent-native uncheck @n8                         # Idempotent — won't toggle if already off
```

### Fill a form

```bash
agent-native snapshot <app> -i
agent-native fill @n2 "user@example.com"
agent-native fill @n3 "password123"
agent-native click @n5                           # Submit button
```

### Navigate Safari

```bash
agent-native open Safari
agent-native snapshot Safari -i
agent-native fill @n3 "https://github.com"       # Address bar
agent-native action @n3 AXConfirm                # Press Enter
agent-native wait Safari --role AXWebArea --timeout 10
agent-native snapshot Safari -i -d 8 --json      # Inspect loaded page
```

### Read a value and branch

```bash
VALUE=$(agent-native get value @n4)
if [ "$VALUE" = "1" ]; then
  echo "Already enabled"
else
  agent-native check @n4
fi
```

## Tips

- **Always use `-i` with snapshot** — full trees are noisy and waste tokens.
- **Re-snapshot after navigation** — refs point to elements from the last snapshot. If the UI changed, old refs may not resolve.
- **Use `--json` for parsing** — all commands support it. Pipe through `jq` for field extraction.
- **`check`/`uncheck` are idempotent** — they read current state first and only toggle if needed.
- **`fill` clears first, `type` appends** — use `fill` for replacing field content, `type` for appending.
- **AX tree peers into browsers** — Safari and Chrome expose web content as AX nodes (`AXWebArea` → headings, links, form controls). You can interact with web content without CDP.
- **Accessibility permissions are required** — the terminal or IDE running agent-native must be granted access in System Settings → Privacy & Security → Accessibility.
- **App names are fuzzy-matched** — "System Settings", "system settings", and "System" all work. Use `agent-native apps` to see exact names.
- **Common AX roles:** `AXButton`, `AXTextField`, `AXTextArea`, `AXCheckBox`, `AXRadioButton`, `AXPopUpButton`, `AXComboBox`, `AXSlider`, `AXLink`, `AXTab`, `AXMenuItem`, `AXSearchField`, `AXSwitch`, `AXWebArea`.
- **Common AX actions:** `AXPress` (click), `AXConfirm` (enter/submit), `AXIncrement`/`AXDecrement` (sliders/steppers), `AXShowMenu` (context menu), `AXPick` (select).

`````

### `./test/integration.sh`

```bash
#!/usr/bin/env bash
# test/integration.sh — Integration tests for agent-native
# Runs against TestFixture app. Requires macOS with accessibility permissions.
#
# Usage:
#   ./test/integration.sh           # Run all tests
#   ./test/integration.sh --quick   # Build + basic tests only (no AX)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$ROOT_DIR/.build/release/agent-native"
FIXTURE_SRC="$ROOT_DIR/TestFixture/TestFixture.swift"
FIXTURE_BIN="$ROOT_DIR/.build/TestFixture"
FIXTURE_PID=""

# ── Helpers ──────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { ((PASS++)); echo -e "  ${GREEN}✓${RESET} $1"; }
fail() { ((FAIL++)); echo -e "  ${RED}✗${RESET} $1"; echo "    $2"; }
skip() { ((SKIP++)); echo -e "  ${YELLOW}○${RESET} $1 (skipped)"; }

# Check if a command succeeds
assert_ok() {
    local desc="$1"; shift
    if output=$("$@" 2>&1); then
        pass "$desc"
    else
        fail "$desc" "exit=$?, output: $output"
    fi
}

# Check if output contains a substring
assert_contains() {
    local desc="$1"; local needle="$2"; shift 2
    if output=$("$@" 2>&1); then
        if echo "$output" | grep -qi "$needle"; then
            pass "$desc"
        else
            fail "$desc" "output did not contain '$needle': $output"
        fi
    else
        fail "$desc" "command failed (exit=$?): $output"
    fi
}

# Check if JSON output is valid
assert_json() {
    local desc="$1"; shift
    if output=$("$@" 2>&1); then
        if echo "$output" | python3 -m json.tool > /dev/null 2>&1; then
            pass "$desc"
        else
            fail "$desc" "invalid JSON: $output"
        fi
    else
        fail "$desc" "command failed (exit=$?): $output"
    fi
}

# Check if output equals expected value (trimmed)
assert_equals() {
    local desc="$1"; local expected="$2"; shift 2
    if output=$("$@" 2>&1); then
        local trimmed
        trimmed=$(echo "$output" | xargs)
        if [[ "$trimmed" == "$expected" ]]; then
            pass "$desc"
        else
            fail "$desc" "expected '$expected', got '$trimmed'"
        fi
    else
        fail "$desc" "command failed (exit=$?): $output"
    fi
}

cleanup() {
    if [[ -n "$FIXTURE_PID" ]]; then
        kill "$FIXTURE_PID" 2>/dev/null || true
        wait "$FIXTURE_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ── Build ────────────────────────────────────────────────────

echo -e "\n${BOLD}Building agent-native...${RESET}"
cd "$ROOT_DIR"
swift build -c release 2>&1 | tail -1
if [[ ! -f "$BIN" ]]; then
    echo -e "${RED}Build failed${RESET}"
    exit 1
fi
echo -e "${GREEN}Build OK${RESET}\n"

# ── Test Group: CLI basics ───────────────────────────────────

echo -e "${BOLD}CLI basics${RESET}"
assert_ok      "version flag"          "$BIN" --version
assert_ok      "help flag"             "$BIN" --help
assert_contains "help lists commands"  "snapshot" "$BIN" --help
assert_contains "help lists commands"  "click"    "$BIN" --help

# ── Test Group: apps command ─────────────────────────────────

echo -e "\n${BOLD}apps command${RESET}"
assert_ok       "apps runs"            "$BIN" apps
assert_json     "apps --json"          "$BIN" apps --format json
assert_contains "apps shows Finder"    "Finder" "$BIN" apps

# ── Quick mode stops here ────────────────────────────────────

if [[ "${1:-}" == "--quick" ]]; then
    echo -e "\n${BOLD}Quick mode — skipping AX tests${RESET}"
    echo -e "\n${BOLD}Results:${RESET} ${GREEN}$PASS passed${RESET}, ${RED}$FAIL failed${RESET}, ${YELLOW}$SKIP skipped${RESET}"
    [[ $FAIL -eq 0 ]] && exit 0 || exit 1
fi

# ── Check accessibility permissions ──────────────────────────

echo -e "\n${BOLD}Checking accessibility permissions...${RESET}"
# The `apps` command doesn't need AX, but `tree` does.
# Try a simple AX operation to see if we have permissions.
if ! "$BIN" tree Finder --depth 1 > /dev/null 2>&1; then
    echo -e "${YELLOW}Accessibility access not granted. Skipping AX tests.${RESET}"
    echo -e "Grant access: System Settings → Privacy & Security → Accessibility"
    echo -e "\n${BOLD}Results:${RESET} ${GREEN}$PASS passed${RESET}, ${RED}$FAIL failed${RESET}, ${YELLOW}$SKIP skipped${RESET}"
    exit 0
fi
echo -e "${GREEN}Accessibility OK${RESET}\n"

# ── Build & launch test fixture ──────────────────────────────

echo -e "${BOLD}Building test fixture...${RESET}"
swiftc -o "$FIXTURE_BIN" "$FIXTURE_SRC" -framework Cocoa 2>&1
echo -e "${GREEN}Fixture built${RESET}"

echo -e "${BOLD}Launching test fixture...${RESET}"
"$FIXTURE_BIN" &
FIXTURE_PID=$!
sleep 2  # Give it time to launch and render

# Verify it's running
if ! kill -0 "$FIXTURE_PID" 2>/dev/null; then
    echo -e "${RED}Fixture failed to launch${RESET}"
    exit 1
fi
echo -e "${GREEN}Fixture running (pid $FIXTURE_PID)${RESET}\n"

APP="Agent Native Test Fixture"

# ── Test Group: tree ─────────────────────────────────────────

echo -e "${BOLD}tree command${RESET}"
assert_ok       "tree runs"                "$BIN" tree "$APP"
assert_ok       "tree --depth 2"           "$BIN" tree "$APP" --depth 2
assert_json     "tree --format json"       "$BIN" tree "$APP" --format json
assert_contains "tree shows window title"  "Agent Native Test Fixture" "$BIN" tree "$APP"

# ── Test Group: snapshot ─────────────────────────────────────

echo -e "\n${BOLD}snapshot command${RESET}"
assert_ok       "snapshot runs"            "$BIN" snapshot "$APP"
assert_ok       "snapshot -i"              "$BIN" snapshot "$APP" -i
assert_ok       "snapshot -i -c"           "$BIN" snapshot "$APP" -i -c
assert_json     "snapshot --json"          "$BIN" snapshot "$APP" --json
assert_contains "snapshot has refs"        "ref=" "$BIN" snapshot "$APP" -i
assert_contains "snapshot shows Submit"    "Submit" "$BIN" snapshot "$APP" -i
assert_contains "snapshot shows checkbox"  "notifications" "$BIN" snapshot "$APP" -i

# ── Test Group: find ─────────────────────────────────────────

echo -e "\n${BOLD}find command${RESET}"
assert_ok       "find buttons"             "$BIN" find "$APP" --role AXButton
assert_ok       "find by title"            "$BIN" find "$APP" --title "Submit"
assert_ok       "find checkboxes"          "$BIN" find "$APP" --role AXCheckBox
assert_contains "find Submit button"       "Submit" "$BIN" find "$APP" --title "Submit"
assert_json     "find --format json"       "$BIN" find "$APP" --role AXButton --format json

# ── Test Group: inspect ──────────────────────────────────────

echo -e "\n${BOLD}inspect command${RESET}"
assert_ok       "inspect by title"         "$BIN" inspect "$APP" --title "Submit"
assert_contains "inspect shows actions"    "AXPress" "$BIN" inspect "$APP" --title "Submit"
assert_contains "inspect shows role"       "AXButton" "$BIN" inspect "$APP" --title "Submit"

# ── Test Group: snapshot → @ref interaction ──────────────────

echo -e "\n${BOLD}snapshot → ref workflow${RESET}"

# Take a snapshot to generate refs
"$BIN" snapshot "$APP" -i > /dev/null 2>&1

# Find the ref for "Submit" button
SUBMIT_REF=$("$BIN" snapshot "$APP" -i 2>/dev/null | grep -i "Submit" | grep -o 'ref=n[0-9]*' | head -1 | sed 's/ref=//')
if [[ -n "$SUBMIT_REF" ]]; then
    pass "found Submit ref: @$SUBMIT_REF"
    assert_ok "click @ref" "$BIN" click "@$SUBMIT_REF"
else
    fail "could not find Submit ref" "snapshot output did not contain Submit with ref"
fi

# Find a checkbox ref
CHECKBOX_REF=$("$BIN" snapshot "$APP" -i 2>/dev/null | grep -i "notifications" | grep -o 'ref=n[0-9]*' | head -1 | sed 's/ref=//')
if [[ -n "$CHECKBOX_REF" ]]; then
    pass "found checkbox ref: @$CHECKBOX_REF"
    assert_ok "check @ref"   "$BIN" check "@$CHECKBOX_REF"
    assert_ok "uncheck @ref" "$BIN" uncheck "@$CHECKBOX_REF"
else
    skip "checkbox ref interaction"
fi

# ── Test Group: get ──────────────────────────────────────────

echo -e "\n${BOLD}get command${RESET}"
assert_ok       "get title"               "$BIN" get title "$APP"
assert_contains "get title value"         "Agent Native Test Fixture" "$BIN" get title "$APP"
assert_ok       "get text by title"       "$BIN" get text "$APP" --title "Submit"

# ── Test Group: is ───────────────────────────────────────────

echo -e "\n${BOLD}is command${RESET}"
assert_ok       "is enabled (Submit)"      "$BIN" is enabled "$APP" --title "Submit"
assert_equals   "Submit is enabled"        "true" "$BIN" is enabled "$APP" --title "Submit"

# ── Test Group: fill / type ──────────────────────────────────

echo -e "\n${BOLD}fill / type commands${RESET}"

# Find the main text field ref
"$BIN" snapshot "$APP" -i > /dev/null 2>&1
INPUT_REF=$("$BIN" snapshot "$APP" -i 2>/dev/null | grep -i "Main Input\|main-input\|Type here" | grep -o 'ref=n[0-9]*' | head -1 | sed 's/ref=//')
if [[ -n "$INPUT_REF" ]]; then
    pass "found input ref: @$INPUT_REF"
    assert_ok "fill @ref"  "$BIN" fill "@$INPUT_REF" "hello world"
    assert_ok "type @ref"  "$BIN" type "@$INPUT_REF" "appended"
else
    # Fallback: try filter-based
    assert_ok "fill by label" "$BIN" fill "$APP" "hello world" --label "Main Input"
fi

# ── Test Group: focus / hover ────────────────────────────────

echo -e "\n${BOLD}focus / hover commands${RESET}"
assert_ok       "focus by title"           "$BIN" focus "$APP" --title "Submit"

# ── Test Group: wait ─────────────────────────────────────────

echo -e "\n${BOLD}wait command${RESET}"
assert_ok       "wait for existing element" "$BIN" wait "$APP" --title "Submit" --timeout 2

# ── Test Group: JSON output ──────────────────────────────────

echo -e "\n${BOLD}JSON output consistency${RESET}"
assert_json     "snapshot --json valid"    "$BIN" snapshot "$APP" -i --json
assert_json     "find --json valid"        "$BIN" find "$APP" --role AXButton --format json
assert_json     "apps --json valid"        "$BIN" apps --format json
assert_json     "get title --json valid"   "$BIN" get title "$APP" --json
assert_json     "is enabled --json valid"  "$BIN" is enabled "$APP" --title "Submit" --json

# ── Test Group: error handling ───────────────────────────────

echo -e "\n${BOLD}error handling${RESET}"
# These should fail gracefully, not crash
if ! "$BIN" tree "NonExistentApp12345" > /dev/null 2>&1; then
    pass "tree nonexistent app fails gracefully"
else
    fail "tree nonexistent app should fail" ""
fi

if ! "$BIN" click "@n99999" > /dev/null 2>&1; then
    pass "click invalid ref fails gracefully"
else
    fail "click invalid ref should fail" ""
fi

if ! "$BIN" wait "$APP" --title "NonExistent" --timeout 1 > /dev/null 2>&1; then
    pass "wait timeout fails gracefully"
else
    fail "wait timeout should fail" ""
fi

# ── Results ──────────────────────────────────────────────────

echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BOLD}Results:${RESET} ${GREEN}$PASS passed${RESET}, ${RED}$FAIL failed${RESET}, ${YELLOW}$SKIP skipped${RESET}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

---

## Git Setup

After creating all files:

```bash
cd agent-native
git init
git branch -m main
chmod +x test/integration.sh
git add -A
git commit -m "Initial commit: agent-native CLI

Swift CLI for controlling macOS native apps via Accessibility APIs.
Inspired by agent-browser (vercel-labs/agent-browser).

Commands: apps, open, snapshot, tree, find, inspect, get, is,
click, fill, type, select, check, uncheck, focus, hover, action, wait.
All commands support @ref from snapshot and --json output.
Includes CI with macOS integration tests and agent skill (SKILL.md)."
```

## Verify

```bash
swift build -c release
.build/release/agent-native --help
.build/release/agent-native apps
```

## Push

```bash
gh repo create agent-native --public --source . --push
```

## Test Locally

```bash
make test        # Full suite (needs AX permissions)
make test-quick  # Build + CLI smoke tests only
```
