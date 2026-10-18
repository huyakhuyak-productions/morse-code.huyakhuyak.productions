# Morse Lamp

A personal iPhone app for learning Morse code in idle minutes. You key letters on one
big paddle, listen to patterns and name them, and unlock the alphabet one character at a
time. No accounts, no streaks, no nagging: progress lives on the phone and shows itself
only when you look.

## How it works

- **Keying.** The app shows a character. Press the paddle: a short press is a dit, a long
  one a dah. It shows what it heard and whether it matched. The app learns your natural
  dit length from your first presses and judges relative to it.
- **Listening.** The app plays a pattern on a 600 Hz tone and lights the lamp in time with
  it. You answer from a short row of candidates at first, and from a keyboard of your
  unlocked set once you know ten characters.
- **Unlocking.** Koch method: you start with K and M, drill only what you have unlocked,
  and the next character is revealed with a listen-and-guess moment when your recent
  accuracy is high. Letters first, then digits, punctuation and two prosigns. Weak
  characters come up more often.
- **Strict timing** is an optional setting that also checks dah length and the gaps
  between elements, with a tolerance band.
- **Sound is optional.** The lamp and haptics carry the signal when the phone is silent.

## Project layout

| Path | What it is |
| --- | --- |
| `MorseLamp/` | The SwiftUI app: screens, design system, audio and haptics |
| `Packages/MorseCore/` | Pure logic with no UI: codes, timing, progression, pickers, playback schedules |
| `MorseLampTests/` | Swift Testing unit tests for the app target |
| `MorseLampUITests/` | XCTest UI tests, including an accessibility audit of every screen |

Requires Xcode 26 and targets iOS 26. Swift 6 with main-actor isolation by default.

## Build and test

```bash
xcodebuild test -project MorseLamp.xcodeproj -scheme MorseLamp \
  -destination 'platform=iOS Simulator,id=<booted simulator id>' \
  -parallel-testing-enabled NO
```

Add `-only-testing:MorseLampTests` to skip the UI tests. The UI tests need a booted
simulator and serial execution. `CLAUDE.md` records the build and testing gotchas in
more detail, including the launch arguments that put the app into fixed states for tests
and screenshots.

## Installing on a phone

```bash
xcrun devicectl list devices
xcodebuild build -project MorseLamp.xcodeproj -scheme MorseLamp \
  -destination 'platform=iOS,id=<device id>' -allowProvisioningUpdates
xcrun devicectl device install app --device <device id> \
  <DerivedData>/Build/Products/Debug-iphoneos/MorseLamp.app
```

The phone needs Developer Mode on and must be paired with `xcrun devicectl manage pair`.

## Licence

MIT, see `LICENSE`. The app uses [Archivo](https://github.com/Omnibus-Type/Archivo) by Omnibus-Type, bundled
under the SIL Open Font License (`MorseLamp/Resources/Fonts/OFL.txt`).
