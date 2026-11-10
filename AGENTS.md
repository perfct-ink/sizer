# AGENTS.md — Sizer

Sizer is a macOS window-sizing utility with global keyboard shortcuts, written in AppKit and compiled straight with `swiftc` (no Xcode project, no package).

## Commands

- `make dev`: build `build/Sizer.app` and open it.
- `make test`: type-check all sources, then compile and run `Tests/AnimationTests.swift` against `Sources/Animation.swift`.
- `make build`: optimized bundle in `dist/`. `make install` / `make open` / `make uninstall` / `make reinstall`: manage `/Applications/Sizer.app`.
- `make close` / `make clean` / `make icon`.
- `make bump [MSG="…"]`: bump the patch version in `Info.plist`, commit, tag, and **push**. Only run it when asked.

## Layout

- `Sources/main.swift`: app entry, status item, and window actions (Accessibility API).
- `Sources/Animation.swift`: window animation scheduling. Keep it free of AppKit so the test can compile it alone.
- `Sources/BindingStore.swift`: stored shortcut bindings (Carbon key codes); hot keys are registered in `main.swift`.
- `Sources/SettingsWindowController.swift`: settings window (General and Shortcuts tabs).
- `Info.plist`: bundle metadata and version.

## Conventions

- Every `.swift` file in `Sources/` is compiled together, so keep it flat. If you add testable logic, add a test in `Tests/` and include it in the `test` target.
- Accessibility calls can be slow or fail; never block the main thread waiting on them.

## Design principles

Follow the [design principles](docs/rules/design-principles.md) for any UI work.

## After changing code

1. `make test`
2. `make dev`

Commit messages are one short, imperative line, like the existing history.
