# Morse Lamp

Personal iPhone Morse trainer. SwiftUI, iOS 26, Swift 6. Two targets: the app
(`MorseLamp/`) and the pure logic package (`Packages/MorseCore`: codes, timing,
progression, pickers, playback schedules). Unit tests use Swift Testing, UI tests use XCTest.

## Build and test

```bash
xcodebuild test -project MorseLamp.xcodeproj -scheme MorseLamp \
  -destination 'platform=iOS Simulator,id=<booted simulator id>' \
  -parallel-testing-enabled NO [-only-testing:MorseLampTests]
```

- Run UI tests on a **booted** simulator with `-parallel-testing-enabled NO`: the XCUITest
  runner times out initialising on simulator clones.
- A simulator that has been up for hours degrades (tests stall for minutes in "Set Up",
  "Timed out while preparing execution worker"). Shut it down and boot it again.
- Do not edit source files while an `xcodebuild` run is in progress: the synchronized groups
  pick new files up at build time and a half-written test breaks the run.
- Launch arguments for tests and screenshots live in `MorseLamp/LaunchConfiguration.swift`:
  `--fixture <fresh|aboutToUnlock|tenUnlocked|complete>`, `--screen <keying|listening|settings|controls>`,
  `--first-target <char>`, `--rng-seed <n>`, `--silent-audio`, `--reset-state`.

## Concurrency

The app target builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Anything that is
pure data or runs off the main actor must be declared `nonisolated` (persistence types,
launch configuration, copy enums, the tone protocol and its renderer). Closures handed to
system threads (audio render block, haptic engine handlers) must be `@Sendable`.

## UI and accessibility gotchas

- Icon-only buttons need an explicit `accessibilityIdentifier`; otherwise the SF Symbol name
  becomes the identifier and label lookups in UI tests fail.
- `LampSwitch` carries `.isToggle`, so UI tests find it under `app.switches`, not `app.buttons`.
- Screen headers (`DrillTopBar`, Settings, Home) are `accessibilityElement(children: .contain)`.
  Without the container, a re-render under a dismissing sheet let the back button's
  accessibility node adopt the content below it and grow to the full screen.
- Hiding a container of bare shapes needs `.accessibilityElement(children: .ignore)` before
  `.accessibilityHidden(true)`, or an unlabeled element stays in the tree.
- Every text change crossfades (`CrossfadeText`); the only instant text is the live keying
  pattern. Destructive actions use the custom confirm sheet, never a system alert.
- The accessibility audit UI test filters Dynamic Type findings on purpose: the spec caps body
  text at xxLarge and keeps glyphs fixed.

## Audio

One `ToneEngine` is shared by the home sheet, both drills and Settings. Drills start it on
appear and stop it on disappear; the app stops it on background and the shared
`onBackgroundReturn` modifier restarts it. The letter sheet must not stop it when it hands
over to the practice drill (the sheet's disappearance fires after the drill has started).
