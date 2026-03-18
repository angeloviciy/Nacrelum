# Architecture

PixelClaw is a single-process AppKit accessory app: your macOS pet on your Dock.

## Runtime Model

- `main.swift` creates `NSApplication`, installs `AppController` as the delegate, and runs the event loop.
- `AppController` owns all mutable state for the crab, apples, and window lifecycle.
- A `Timer` running at 60 Hz advances animation, movement, and apple physics.
- `CrabView`, `ShadowView`, and `AppleView` handle drawing only. They do not own game state.

## Source Map

- `Support/AppConstants.swift`: colors, sprite grids, and sizing constants
- `Support/AppMetadata.swift`: project name, version info, and GitHub URLs
- `Support/AppVersion.swift`: semantic version parsing and comparison
- `Support/DockInfo.swift`: Dock geometry lookup through AppKit and accessibility APIs
- `Support/Models.swift`: enums and lightweight state containers
- `Views/*.swift`: sprite rendering
- `App/AppController.swift`: state declarations for the main controller
- `App/AppController+Core.swift`: Dock bounds refresh, targeting helpers, and debug logging
- `App/AppController+Movement.swift`: walking, sleep/wake state, jumping, and visual animation
- `App/AppController+Apples.swift`: apple spawning, physics, collisions, and click interactions
- `App/AppController+Accessibility.swift`: accessibility permission flow, status bar menu, window setup, and launch sequence
- `App/AppController+Updates.swift`: automatic update checks and install flow
- `App/AppUpdater.swift`: GitHub release fetching, download, and self-update logic
- `App/AboutWindowController.swift`: About window UI

## Current Constraints

- Rendering is CPU-driven AppKit drawing rather than a sprite/layer pipeline.
- There are no automated tests yet; verification is currently compile-based plus manual runtime checks.
- The app depends on macOS-specific APIs and is not portable to non-Apple platforms.
