# Nacrelum

A golden cat desktop tamagotchi that lives on your Dock. It walks around, sleeps,
wakes on click, and chases stars you drop.

```
      (   )
       /\_/\
    (  ✦   ✦  )
     (   ω   )
    (")_(")~
```

Forked from [PixelClaw](https://github.com/masasron/PixelClaw) by Ron Masas.

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
open Dist/Nacrelum.app
```

You can also build directly with Swift Package Manager:

```sh
swift build
swift run Nacrelum
```

## Permissions

Nacrelum uses Accessibility access to read your Dock position and respond to
clicks. The first time you launch it, macOS may ask for permission. If your pet
is not lining up with the Dock correctly, check
`System Settings > Privacy & Security > Accessibility`.

## Controls

| Action | Effect |
|--------|--------|
| `Option+F` | Drop a star |
| Click (awake) | Make it hop |
| Click (sleeping) | Wake it up |
| Click a star | Toss it |

## Features

- Golden cat with halo, star eyes, omega nose, and wagging tail
- Walks on Dock and ground, jumps between levels
- Falls asleep after idle time, dims when drowsy
- Chases falling stars with excited hops
- Breathing animation, blinking, eye tracking
- Halo floats with a gentle lag behind the cat

## Project Layout

- `Sources/Nacrelum/Support`: constants, sprite data, shared models, Dock helpers
- `Sources/Nacrelum/Views`: AppKit drawing code for the cat, stars, and shadow
- `Sources/Nacrelum/App`: application state, animation loop, interaction logic

## License

This project is licensed under the [MIT License](LICENSE).
