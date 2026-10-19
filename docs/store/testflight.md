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

- [ ] TestFlight → Internal Testing: create a group, add yourself, pick the build.
- [ ] Install from the TestFlight app. Check the icon in default, dark, clear and tinted
      home-screen styles, the launch colour in light and dark, and that the tone plays with
      the silent switch on.
- [ ] TestFlight → External Testing: create the group "Friends", add the build, turn on
      Public Link, copy the link into `web/src/lib/site.ts` (`GET_APP`: label "Join the
      TestFlight"), commit, `bun run test` in `web/`, then `git push dokku main` so the live page
      shows the button before review.
- [ ] Submit the group for Beta App Review only after the web page is live: the review asks
      for the privacy policy URL, `https://morse-code.huyakhuyak.productions/privacy`.
