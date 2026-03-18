# PixelClaw

A tiny animated pet that lives on your Dock.

## Requirements

- macOS 12 or later
- Swift 5.9+ toolchain or Xcode with Swift Package Manager support

## Build

```sh
make
```

To run the app:

```sh
make run
```

To build a launchable macOS app bundle:

```sh
make app
open Dist/PixelClaw.app
```

To build and sign the app with an Apple certificate:

```sh
cp .signing.env.example .signing.env
$EDITOR .signing.env
make sign
```

To build a GitHub-release-ready zip for the updater:

```sh
make zip
```

If you keep the same bundle identifier and Team ID across updates, macOS is much more likely to retain previously granted permissions such as Accessibility access when you replace the app in place.

To launch with debug logging enabled:

```sh
make debug
```

You can also build directly with Swift Package Manager:

```sh
swift build
swift run PixelClaw --debug
```

## Permissions

PixelClaw uses Accessibility access to read your Dock position and respond to clicks. The first time you launch it, macOS may ask for permission. If your pet is not lining up with the Dock correctly, check `System Settings > Privacy & Security > Accessibility`.

## Controls

- `Option+F`: drop an apple
- Click your pet while it is awake: make it hop in place
- Click your pet while it is sleeping: wake it up
- Click an apple: toss it again

## Project Layout

- `Package.swift`: Swift Package Manager manifest
- `Sources/PixelClaw/Support`: constants, sprite data, shared models, Dock geometry helpers
- `Sources/PixelClaw/Views`: AppKit drawing code for the crab, apples, and floor shadow
- `Sources/PixelClaw/App`: application state, update loop, interaction logic, and entry point
- `Docs/ARCHITECTURE.md`: high-level structure for contributors

## License

This project is licensed under the [MIT License](LICENSE).
