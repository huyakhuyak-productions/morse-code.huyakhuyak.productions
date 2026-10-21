# TestFlight

## What to test (shown to testers)

> Learn Morse in idle minutes. Try keying a letter on the paddle, then try a listening
> round. Tell me if the paddle ever misreads a dit as a dah, if the sound stutters, or if
> anything is unclear without reading instructions.

## One-time setup (owner, App Store Connect web UI)

- [x] Apps → New App: platform iOS, name "Morse Lamp: Learn Morse Code" ("Morse Lamp" was taken;
      the name on the phone stays "Morse Lamp"), primary language English (U.S.), bundle id
      `productions.huyakhuyak.MorseLamp`, SKU `morse-lamp`. Record id 6824568488. Done 2026-10-19;
      build 2 was the first upload.
- [ ] If `scripts/release.sh` cannot authenticate: Users and Access → Integrations → Team Keys,
      create a key with the App Manager role, save the `.p8` outside the repo, and run the
      script again with `ASC_KEY_PATH`, `ASC_KEY_ID` and `ASC_ISSUER_ID` exported.

## Every upload

1. Commit everything; `scripts/release.sh` refuses a dirty tree.
2. Run `scripts/release.sh`. It bumps the build number, commits `🔖 Build <n>`, archives and
   uploads. Processing on Apple's side takes a few minutes; the build then appears under
   TestFlight → iOS Builds.
3. `git push origin main` so the build commit is on GitHub.

## First build only (owner)

- [x] TestFlight → Internal Testing: group "Owner" (automatic distribution on), owner invited
      2026-10-20, build 2 attached.
- [ ] Install from the TestFlight app. Check the icon in default, dark, clear and tinted
      home-screen styles, the launch colour in light and dark, and that the tone plays with
      the silent switch on.
- [x] TestFlight → External Testing: group "Friends" with build 2 and the Public Link
      `https://testflight.apple.com/join/w4vFmtRW` (open to anyone, no tester limit). The link is
      `TESTFLIGHT_URL` in `web/src/lib/site.ts` and `GET_APP` points at it; the site went live on
      dokku the same day.
- [x] Build 2 submitted for Beta App Review on 2026-10-20 ("Waiting for Review"); the review
      reads the privacy policy at `https://morse-code.huyakhuyak.productions/privacy`.
- [x] Beta App Review passed; builds 2 and 3 are Testing in "Friends". Build 4 (2026-10-21)
      carries swipe back and the codes-on-letters fix.
- [ ] When the review passes, send friends the public link. Each later `scripts/release.sh`
      upload reaches "Owner" automatically; add it to "Friends" by hand (Builds → +).
