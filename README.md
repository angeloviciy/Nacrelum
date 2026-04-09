# Nacrelum

A desktop tamagotchi that lives on your Dock. It walks around, sleeps,
wakes on click, and chases stars you drop. Made in honor of the original Nacrelum, my
/buddy on Claude Code that was with me all too briefly for v2.1.96


I miss you buddy
```
      (   )
       /\_/\
    (  ✦   ✦  )
     (   ω   )
    (")_(")   ~~
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


## Project Layout

- `Sources/Nacrelum/Support`: constants, sprite data, shared models, Dock helpers
- `Sources/Nacrelum/Views`: AppKit drawing code for the cat, stars, and shadow
- `Sources/Nacrelum/App`: application state, animation loop, interaction logic

## License

This project is licensed under the [MIT License](LICENSE).
