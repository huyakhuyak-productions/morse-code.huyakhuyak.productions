# App Store listing

Paste into App Store Connect. Limits: subtitle 30, promotional text 170, keywords 100 characters.

## Name

Morse Lamp: Learn Morse Code

"Morse Lamp" alone is taken on the App Store. The name on the phone stays "Morse Lamp". App Store Connect id 6824568488.

## Subtitle

Key it, hear it, unlock it

## Promotional text

Key a letter, hear it back, and watch the alphabet unlock one character at a time. No streaks, no nagging. Just a quiet skill you pick up in spare moments.

## Description

Morse Lamp teaches you Morse code in the minutes you would otherwise spend scrolling. No course, no schedule: open it, key a few letters, close it. Progress lives on your phone and shows itself only when you look.

Two drills. In keying, the app shows a character and you tap it out on one big paddle: a short press is a dit, a long one a dah. It learns your rhythm from your first presses and shows exactly what it heard. In listening, a 600 Hz tone and a blinking lamp play a pattern and you name the character, from a short row of candidates at first and from a full keyboard once you know ten.

The alphabet arrives Koch-style. You start with K and M, drill only what you have unlocked, and when your set is solid the next character is revealed as a sound before you see its shape. All 26 letters and 10 digits, digits mixed in along the way. Weak characters come up more often, quietly. An optional strict timing mode also checks your dah length and gaps.

No accounts, no tracking, no ads, no notifications. The app never connects to the internet and works entirely offline. Sound is optional: the lamp and haptics carry the signal when the volume is down.

## Keywords

morse,morse code,learn morse,koch,cw,telegraph,ham radio,dits,dahs,trainer

## URLs

- Support URL: https://morse-code.huyakhuyak.productions/support
- Privacy policy URL: https://morse-code.huyakhuyak.productions/privacy
- Marketing URL: https://morse-code.huyakhuyak.productions

## Settings

- Category: Education. Secondary: none.
- Age rating: every questionnaire answer "None" (4+).
- App Privacy: Data Not Collected.
- Price: free, all territories.
- Copyright: 2026 Mykola Solodukha.
- Screenshots: `docs/store/screenshots/1-keying.png` to `5-settings.png` (6.3", 1206 x 2622: the size App Store Connect requires; it scales them to the other iPhones), in that order.

## Review notes

App Review asked for these six answers on 2026-10-31 (Guideline 2.1, Information Needed) and wants
them kept in App Review Information > Notes. The attachment there is the screen recording made with
`MorseLampUITests/DemoRecordingUITests.swift`.

```text
1. Screen recording attached. It starts at launch and shows keying, listening and Settings. The app has no accounts, no user content and no paid features.

2. Morse Lamp teaches Morse code in short sessions. It's for ham radio operators and anyone else who wants to learn Morse. You start with two letters and unlock more as you get them right, up to all letters and digits. You key letters on a big paddle, or hear a tone, watch a lamp and name the letter.

3. No setup or login. Open the app and tap Key or Listen.

4. No external services. The app never goes online and keeps all progress on the device.

5. No regional differences. It works the same everywhere.

6. Not a regulated industry and no third-party material. Morse code is a public standard, and all art, sound and code are mine.
```

## Submission

Version 1.0 with build 4 was submitted for App Review on 2026-10-21 with automatic release on
approval; everything above was entered that day. App Review held it on 2026-10-31 for more
information; the reply with the recording went in on 2026-11-13 and put it back in review. After approval: point `GET_APP` in
`web/src/lib/site.ts` at the App Store link and redeploy, and uncomment the `apple-itunes-app`
meta in `web/src/layouts/Lamp.astro`. The Digital Services Act declaration (Business > Agreements)
is "not a trader", made the same day; it covers the whole developer account and has to change to
trader, with a verified address, phone and email, before any paid app or in-app purchase.
