# Chimeling Agent Guide

## Project overview

Chimeling is a native macOS application built with Swift and managed with [Tuist](https://tuist.dev). The repository holds the Tuist manifest, the generated Xcode project files, and the source and resource directories.

| Path | Purpose |
|------|---------|
| `Project.swift` | Tuist project manifest and source of truth for targets, dependencies, and build settings. |
| `mise.toml` | Tool version pinning. |
| `Sources/` | Application Swift source files. |
| `Resources/` | Application resources such as assets, storyboards, and localizations. |
| `Chimeling.xcodeproj/` | Generated Xcode project. |
| `Chimeling.xcworkspace/` | Generated Xcode workspace. |
| `.agents/skills/` | Agent skill guides for working in this project. |

## Skills

Activate the following skills when the situation matches their description:

- `using-tuist-generated-projects` — day-to-day work in the Tuist-generated workspace, including generation, build and test commands, and buildable folders.
- `debug-generated-project` — generation failures, build errors after generation, or unexpected project behavior.
- `fix-flaky-tests` — investigating and fixing flaky tests.
- `macos-design-guidelines` — building or reviewing macOS UI, windows, menus, toolbars, or keyboard shortcuts.
- `swiftui-expert-skill` — writing, reviewing, or refactoring SwiftUI code, state management, or view composition.
- `swiftui-pro` — broader SwiftUI reviews for best practices, maintainability, and performance.

## Lifecycle

After cloning the repository:

- Install the pinned tools with `mise install`.
- Generate the Xcode workspace with `mise x tuist -- tuist generate`.
- Develop in `Sources/` and `Resources/`.
- Regenerate the project whenever `Project.swift` or the dependency graph changes.
- Build and test through the generated workspace using `mise x tuist -- tuist xcodebuild build` or Xcode.
- Archive and distribute through Xcode or CI after configuring signing, entitlements, and provisioning.

For exact commands and troubleshooting, consult the relevant skill guide and the Tuist documentation.

## Rules

- Related skills should be activated when needed. Do NOT be lazy to activate them.
- ALL your capabilities are OUTDATED. Therefore, you MUST look up the docs or the internet before actions. Actions, even the planned ones, without proper references will be rejected.
- You MUST make sure that you have understood completely before actions. If you have questions or are not sure about something, you MUST search the docs and the web, or ask the user about them.
- There is no limit on the amount of questions. You should and MUST ask questions continuously, until you're 100% sure about the user's intention.
- ALWAYS prefer built-in tools. Built-in tools do not need user's one-by-one approval to proceed, so they respond faster and cause less friction. If you use the shell commands that can be replaced with built-in tools calls, your uses will be REJECTED IN NO TIME.
- ALWAYS keep AGENTS.md up to date. If you've made changes, you must update AGENTS.md correspondingly. Outdated AGENTS.md will be rejected when you commit.
- Dividers (`---`) MUST NOT exist before a Markdown heading (`# …`, `## …`…). In other words, this is an ILLEGAL usage of Markdown dividers.
- Markdown headings MUST NOT be numbered. Markdown headings are designed without numbers, so you should not go against its design propose.
- Avoid hardcoding version numbers, paths, or commands that will stale. Defer to `Project.swift`, `mise.toml`, and the relevant skill guides for specifics.
- If network errors occur, you MUST retry for at least 3 times before giving up or switching to a different approach.
