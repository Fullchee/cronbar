# Claude Code tooling for a native macOS Swift app

Researched 2026-11-27 for Cronbar: a SwiftPM-only `MenuBarExtra` app with Swift Testing and ad-hoc signed releases.
Machine: Xcode 27.2 (27B52) at `/Applications/Xcode.app`.

## Recommendation

Install these four. Everything else is optional or a poor fit.

| # | Tool | Why | Install |
|---|---|---|---|
| 1 | **swift-lsp** plugin (Anthropic) | Go-to-definition, references and diagnostics through `sourcekit-lsp`, which Xcode already ships. | `/plugin install swift-lsp@claude-plugins-official` |
| 2 | **Sosumi** plugin (NSHipster) | Apple docs search, docs pages, HIG and WWDC transcripts as Markdown. | `/plugin marketplace add NSHipster/sosumi.ai` then `/plugin install sosumi@sosumi-ai` |
| 3 | **Swift Concurrency** skill (Antoine van der Lee) | Swift 6 strict concurrency: `Sendable`, actor isolation, `@MainActor`. Fits `launchctl` shell-outs from a SwiftUI app. | `/plugin marketplace add AvdLee/Swift-Concurrency-Agent-Skill` then `/plugin install swift-concurrency@swift-concurrency-agent-skill` |
| 4 | **Peekaboo** CLI (OpenClaw) | Lists and clicks menu bar extras (`peekaboo menubar list` / `click`), then screenshots. The only tool found with a dedicated status-item command. | `brew install openclaw/tap/peekaboo` |

- **Skip build MCPs for now**: `swift build` and `swift test` through Bash do the job for a SwiftPM-only project.
- **Try later**: Apple's `xcode` plugin. It bundles Apple-written skills (`swiftui-specialist`, `modernize-tests`) plus Xcode's MCP. Xcode must be running with the package open.

## Already have

| Item | State | Source |
|---|---|---|
| `claude-plugins-official` marketplace | Added. Lists `swift-lsp` and Apple's `xcode` plugin. | `claude plugin list`, `~/.claude/plugins/marketplaces/` |
| `swift-lsp` plugin | **Not installed**. Only `pyright-lsp` is enabled. | `enabledPlugins` in `~/.claude/settings.json` |
| `sourcekit-lsp` binary | Present: `/usr/bin/sourcekit-lsp` (Xcode toolchain). | `xcrun --find sourcekit-lsp` |
| `xcrun mcpbridge` | Present in Xcode 27.2. | `xcrun --find mcpbridge` |
| `orca-computer-use` skill | Installed. Drives native app windows via accessibility tree and screenshots. | `~/.claude/skills/orca-computer-use` |
| Swift/Apple MCP servers | None. `claude mcp list` shows only claude.ai connectors and `data` plugin servers. | `claude mcp list` |
| Swift skills | None in `~/.claude/skills`. | `ls ~/.claude/skills` |

Side effect: running `xcrun agent plugin path --plugin-format claude` to inspect Apple's plugin exported its files to `~/Library/Developer/Xcode/CodingAssistant/ExportedPlugins/27B52/claude`. Nothing was installed into Claude Code.

## 1. Build and test MCPs

| Tool | What it does | Maintenance | Install | Worth it here? |
|---|---|---|---|---|
| **Xcode MCP** (`xcrun mcpbridge`, Apple) | Bridges Claude Code to Xcode's MCP tools: build, issues, previews, docs search. Needs Xcode open with the project, and the setting "Allow External Agents to Use Xcode Tools" turned on. [Apple docs](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode) | Ships with Xcode (26.3+; 27.2 here). | `claude mcp add --transport stdio xcode -- xcrun mcpbridge` | **Maybe.** Useful for SwiftUI preview rendering. Requires opening `Package.swift` in Xcode, which this project otherwise avoids. |
| **`xcode` plugin** (Apple, in Anthropic's marketplace) | Packages the Xcode MCP above plus ~17 Apple skills, e.g. `swiftui-specialist`, `modernize-tests` (XCTest to Swift Testing), `xctrace`, `app-intents-specialist`. Content comes from the local Xcode via `xcrun agent plugin path`. [marketplace.json](https://github.com/anthropics/claude-plugins-official/blob/main/.claude-plugin/marketplace.json) | Versioned with Xcode; marketplace updated 2026-11-24. | `/plugin install xcode@claude-plugins-official` | **Maybe.** The skills are the draw. The MCP part has the same "Xcode must be open" cost. |
| **MobileBuildMCP** (Sentry; formerly XcodeBuildMCP) | MCP server and CLI for xcodebuild. Has a `swift-package` workflow (`swift_package_build/test/run`) and a `macos` workflow. Only `simulator` is on by default. UI automation is iOS-only. [repo](https://github.com/getsentry/MobileBuildMCP), [workflows](https://github.com/getsentry/MobileBuildMCP/tree/main/manifests/workflows) | Active. 6.6k stars, 24 open issues, v2.7.1 (2026-09-23), pushed 2026-11-19. Sends Sentry error telemetry by default ([privacy](https://github.com/getsentry/xcodebuildmcp.com/blob/main/app/docs/_content/privacy.mdx)). | `claude mcp add MobileBuildMCP -- npx -y mobilebuildmcp@latest mcp` ([clients](https://github.com/getsentry/xcodebuildmcp.com/blob/main/app/docs/_content/clients.mdx)) | **No.** Wraps `swift build`/`swift test`, which Bash already runs. Pays off for `.xcodeproj` and iOS simulator work. |
| **Plain SwiftPM via Bash** | `swift build`, `swift test`, `swift run`. | Ships with the toolchain. | None | **Yes.** Default path. |

## 2. Apple docs lookup

| Tool | What it does | Maintenance | Install | Worth it here? |
|---|---|---|---|---|
| **Sosumi** (NSHipster) | Hosted MCP and CLI. Tools: `searchAppleDocumentation`, `fetchAppleDocumentation`, `fetchAppleVideoTranscript` (WWDC), `fetchExternalDocumentation` (any DocC site). Its own eval: Claude models pass 12–30 points more Swift tasks than with web search, at half the cost. [repo](https://github.com/NSHipster/sosumi.ai) | Active. 498 stars, 0 open issues, v1.1.1 (2026-11-09), pushed 2026-11-25. | `/plugin marketplace add NSHipster/sosumi.ai` then `/plugin install sosumi@sosumi-ai` | **Yes.** Adds search and WWDC transcripts, which plain fetches lack. |
| **Apple's own `.md` pages** | developer.apple.com now serves Markdown: append `.md` to a docs URL (e.g. [MenuBarExtra.md](https://developer.apple.com/documentation/swiftui/menubarextra.md)). The HTML page links it as "View Markdown". | First-party. | None. WebFetch or `curl` the `.md` URL. | **Yes, free fallback.** Good when you know the page. No search. |
| **Plain WebFetch of HTML** | The HTML page body says "This page requires JavaScript". The content is not in the response. Checked with `curl` on [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra). | n/a | n/a | **No.** Use the `.md` URL instead. |
| **apple-docs-mcp** (kimsungwhee) | Local MCP for Apple docs search, framework indexes and WWDC. [repo](https://github.com/kimsungwhee/apple-docs-mcp) | **Stale: last commit 2026-03-17 (8+ months).** Last release v1.0.26 (2025-09-15). 1.4k stars, 16 open issues. | `claude mcp add apple-docs -- npx -y @kimsungwhee/apple-docs-mcp@latest` | **No.** Unmaintained, and Sosumi covers the same ground. |
| **Xcode MCP docs search** | Xcode's MCP includes documentation search ([MobileBuildMCP bridge docs](https://github.com/getsentry/xcodebuildmcp.com/blob/main/app/docs/_content/xcode-ide.mdx)). | Ships with Xcode. | See area 1. | Only if you already run the Xcode MCP. |

## 3. Swift LSP

| Tool | What it does | Maintenance | Install | Worth it here? |
|---|---|---|---|---|
| **swift-lsp** (Anthropic) | Registers `sourcekit-lsp` for `.swift` files, so Claude's `LSP` tool gets definitions, references and diagnostics. Needs `sourcekit-lsp` on `PATH` (present). [plugin](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/swift-lsp) | Official marketplace; plugin dir last changed 2026-11-06. Marketplace repo: 48k stars. | `/plugin install swift-lsp@claude-plugins-official` (marketplace already added) | **Yes.** Zero extra deps. Run `swift build` once so sourcekit-lsp has an index. |
| **sourcekit-lsp** (swiftlang) | The server itself. [repo](https://github.com/swiftlang/sourcekit-lsp) | Active. 3.9k stars, 175 open issues, pushed 2026-11-27. | Ships with Xcode. | Comes with the plugin above. |

## 4. UI automation and screenshots

Goal: let the agent open Cronbar's menu bar item, read the menu and screenshot it.

| Tool | What it does | Maintenance | Install | Worth it here? |
|---|---|---|---|---|
| **Peekaboo** (OpenClaw; formerly steipete) | macOS CLI and MCP for screenshots, accessibility trees and clicks. `peekaboo menubar list` lists status items; `peekaboo menubar click <name> --foreground --verify` opens one and confirms the popover. Needs Screen Recording and Accessibility. [repo](https://github.com/openclaw/Peekaboo), [menubar docs](https://github.com/openclaw/Peekaboo/blob/main/docs/commands/menubar.md) | Active. 5.6k stars, 5 open issues, v4.9.10 (2026-11-21). macOS 15+. | `brew install openclaw/tap/peekaboo`. Optional MCP: `claude mcp add peekaboo -- peekaboo mcp` ([MCP docs](https://github.com/openclaw/Peekaboo/blob/main/docs/MCP.md)) | **Yes.** Only tool found with a dedicated menu bar extra command. The CLI via Bash is enough; skip the MCP. |
| **Claude Code computer use** (built-in) | Built-in `computer-use` MCP: screenshots, clicks, typing in approved apps. Docs use "build a macOS menu bar app" as the example. [docs](https://code.claude.com/docs/en/computer-use) | First-party research preview. | `/mcp` → `computer-use` → Enable | **Check plan first.** Pro, Max or Ultra only; not on Team or Enterprise, and not with `-p`. |
| **orca-computer-use** skill | Drives native app windows through the accessibility tree and screenshots, in the background. | Local skill. | Already installed. | **Already have.** Try it before adding Peekaboo. Menu bar extras live outside app windows, so test that first. |
| **`screencapture`** (macOS) | Built-in screenshot CLI. `screencapture -x out.png` captures silently; `-R x,y,w,h` crops. See `man screencapture`. | Ships with macOS. | None | **Yes, for screenshots only.** Cannot click. Needs Screen Recording for the terminal. |
| **macos-automator-mcp** (steipete) | AppleScript/JXA runner over MCP. [repo](https://github.com/steipete/macos-automator-mcp) | **Archived** (last push 2026-09-13). | n/a | **No.** Archived. |
| **automation-mcp** (ashwwwin) | Mouse, keyboard and screenshot MCP. [repo](https://github.com/ashwwwin/automation-mcp) | **Stale: last push 2025-06-11 (17 months).** | n/a | **No.** |
| **Terminator** (mediar-ai) | Cross-platform desktop automation SDK and MCP, Windows-first. [repo](https://github.com/mediar-ai/terminator) | Last push 2026-06-02 (just under 6 months). | n/a | **No.** Peekaboo is macOS-native. |
| **MobileBuildMCP `ui-automation`** | Tap, swipe, screenshot. | See area 1. | n/a | **No.** iOS simulator only ([manifest](https://github.com/getsentry/MobileBuildMCP/blob/main/manifests/workflows/ui-automation.yaml)). |

## 5. Swift and SwiftUI skills

| Tool | What it does | Maintenance | Install | Worth it here? |
|---|---|---|---|---|
| **Swift Concurrency Expert** (Antoine van der Lee) | Swift 6+ strict concurrency: migration, `Sendable`, actors, data-race triage. [repo](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill) | Active. 1.7k stars, v2.3.1 (2026-11-06). | `/plugin marketplace add AvdLee/Swift-Concurrency-Agent-Skill` then `/plugin install swift-concurrency@swift-concurrency-agent-skill` | **Yes.** Swift 6.4 strict mode plus `Process` calls is where agents slip. |
| **SwiftUI Expert** (Antoine van der Lee) | SwiftUI state, performance and modern APIs. [repo](https://github.com/AvdLee/SwiftUI-Agent-Skill) | Active. 3.9k stars, v5.3.0 (2026-11-06). | `/plugin marketplace add AvdLee/SwiftUI-Agent-Skill` then `/plugin install swiftui-expert@swiftui-expert-skill` | Optional. The UI is a small menu. |
| **SwiftUI Pro** (Paul Hudson) | SwiftUI review skill, targets Swift 6.4+. [repo](https://github.com/twostraws/SwiftUI-Agent-Skill) | Active. 6.6k stars, v2.0.0 (2026-10-09). | `/plugin marketplace add twostraws/SwiftUI-Agent-Skill` then `/plugin install swiftui-pro@swiftui-agent-skill` | Optional. Pick this or AvdLee's, not both. |
| **Swift Testing Expert** (Antoine van der Lee) | Swift Testing patterns and XCTest migration. [repo](https://github.com/AvdLee/Swift-Testing-Agent-Skill) | Active. 483 stars, v1.2.0 (2026-04-22), pushed 2026-09-14. | `/plugin marketplace add AvdLee/Swift-Testing-Agent-Skill` then `/plugin install swift-testing-expert@swift-testing-agent-skill` | Optional. Apple's `modernize-tests` skill overlaps. |
| **Swift Concurrency Pro / Swift Testing Pro** (Paul Hudson) | Same topics as AvdLee's. [concurrency](https://github.com/twostraws/Swift-Concurrency-Agent-Skill), [testing](https://github.com/twostraws/Swift-Testing-Agent-Skill) | **Stale: both last pushed 2026-05-17 (6+ months).** | `npx skills add <repo-url>` | **No.** Prefer AvdLee's active versions. |
| **Apple skills in the `xcode` plugin** | `swiftui-specialist`, `swiftui-whats-new-27`, `modernize-tests`, `xctrace`, accessibility audits. Apple calls them "authoritative". Read from the local export. | Versioned with Xcode 27.2. | `/plugin install xcode@claude-plugins-official` | **Maybe.** First-party and current, but bundled with the Xcode MCP. |
| **Dimillian/Skills** (Thomas Ricouard) | Includes `macos-spm-app-packaging` (build, package, sign a SwiftPM macOS app without Xcode), `macos-menubar-tuist-app`, `swift-concurrency-expert`. [repo](https://github.com/Dimillian/Skills) | **Stale: last push 2026-03-29 (8 months).** 4k stars. Written for Codex (`$CODEX_HOME/skills`). | Copy the skill folder into `~/.claude/skills/` | **Read, don't install.** `macos-spm-app-packaging` matches Cronbar's release flow; borrow ideas. |
| **Swift-Agent-Skills** (Paul Hudson) | Curated index of community Swift skills, not a skill. [repo](https://github.com/twostraws/Swift-Agent-Skills) | Active (pushed 2026-11-25). | n/a | Use to find more. |
| **anthropics/skills** | Anthropic's skill repo. No Swift or Apple skill in it. [skills dir](https://github.com/anthropics/skills/tree/main/skills) | Active. | n/a | **No.** Nothing Swift-specific. |

## 6. Release and CI (lower priority)

| Tool | What it does | Maintenance | Install | Worth it here? |
|---|---|---|---|---|
| **GitHub-hosted macOS runners** | `macos-15`, `macos-26` and an Xcode 27 arm64 image. [runner-images](https://github.com/actions/runner-images/tree/main/images/macos) | Active (pushed 2026-11-27). | `runs-on: macos-26` | **Yes.** Pick an image whose Xcode matches Swift 6.4. |
| **`codesign --sign -`** | Ad-hoc signing; no identity or developer account needed. See `man codesign` ("If identity is the single letter "-" (dash), ad-hoc signing is performed"). | Ships with Xcode. | None | **Yes.** Matches the current release plan. |
| **maxim-lobanov/setup-xcode** | Selects an Xcode version on the runner. [repo](https://github.com/maxim-lobanov/setup-xcode) | Last push 2026-03-18 (8 months). **Stale.** | Workflow step | Optional. `sudo xcode-select -s` does the same. |
| **Apple-Actions/import-codesign-certs** | Imports a .p12 into the runner keychain. [repo](https://github.com/Apple-Actions/import-codesign-certs) | Active (pushed 2026-11-15). | Workflow step | **No.** Needs a Developer ID cert. |
| **rcodesign** (apple-platform-rs) | Sign and notarize from any OS. [repo](https://github.com/indygreg/apple-platform-rs) | Active (pushed 2026-10-17), 126 open issues. | `cargo install apple-codesign` | **No.** Notarization needs a paid Developer account. |

No MCP or Claude Code plugin for GitHub Actions macOS builds or notarization turned up. The `gh` CLI covers run logs.

## Sources checked locally

- `claude mcp list`, `claude plugin list`, `~/.claude/settings.json` (`enabledPlugins`), `ls ~/.claude/skills`.
- `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/swift-lsp/`.
- `xcrun mcpbridge --help`, `xcrun agent plugin path --plugin-format claude`, and the exported `.mcp.json` (runs `xcrun mcpbridge`).
- GitHub metadata via `gh api repos/<owner>/<repo>` on 2026-11-27.
