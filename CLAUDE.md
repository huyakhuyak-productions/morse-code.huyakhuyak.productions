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

## Release assets

The app icon is an Icon Composer bundle, `MorseLamp/AppIcon.icon`: a JSON manifest plus one PNG
per layer, compiled by actool because `ASSETCATALOG_COMPILER_APPICON_NAME` matches its basename.
The PNGs are rendered from the SVGs in `design/icon/` by `scripts/render-icon.sh`; never edit them
by hand. `UIImage(named: "AppIcon")` throws for a layered icon, so `BundleTests` checks the flat
fallback file that `CFBundleIconFiles` names. A layer whose alpha fades under glass shows a hard
seam where the glass mask ends, so only the opaque dot has glass on.

## Deploying to an iPhone

The bundle id is `productions.huyakhuyak.MorseLamp` (capital M and L). The team registered that
capitalisation from the Xcode template, and Apple compares App IDs case-insensitively, so the
lowercase spelling cannot coexist with it. The `LampLog.subsystem` string mirrors the id and a
unit test keeps them equal.

```bash
xcodebuild build -project MorseLamp.xcodeproj -scheme MorseLamp \
  -destination 'platform=iOS,id=<device id from: xcrun devicectl list devices>' -allowProvisioningUpdates
xcrun devicectl device install app --device <device id> <DerivedData>/Build/Products/Debug-iphoneos/MorseLamp.app
xcrun devicectl device process launch --device <device id> productions.huyakhuyak.MorseLamp
```

A new phone needs Developer Mode on and `xcrun devicectl manage pair --device <id>` first;
`-allowProvisioningUpdates` registers its UDID with the team. Launching fails with
`BSErrorCodeDescription = Locked` while the phone is locked.
