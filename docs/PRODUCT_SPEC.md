# Touch Colour App - Product Spec (Draft v0.2)

Status: decisions from round 1 applied. Remaining open items in section 11.

## 1. Core concept

A full-screen canvas. Every touch produces a colour/light effect, similar to a reactive RGB keyboard. Touches interact with each other (e.g. overlapping ripples), and rapid tapping speeds up and intensifies the response.

## 2. Decisions log

| # | Topic | Decision | Consequence |
|---|---|---|---|
| D1 | Audience | Children, young adults, neurodivergent users. First users: ages 5 and 1. | Child-safety design is the baseline, not an add-on. Google Play Families policy and Apple Kids Category rules apply. |
| D2 | Business model | Free. Support link (Buy Me a Coffee or charity) under its own banner in the menu. | No ads, no analytics, no in-app purchases. Support link sits behind a parental gate. See section 8. |
| D3 | Platforms | Android first, iOS planned. | Cross-platform engine chosen now (section 5). iOS builds require a Mac and an Apple Developer account. |
| D4 | Canvas exit | Hold a corner. | Single corner, 3 s hold, visible progress ring. Exits to the child-safe home, never directly to settings or links. |

## 3. Access layers

Three layers, so a 1 year old cannot get anywhere harmful, a 5 year old can choose styles alone, and only an adult reaches settings and external links.

| Layer | Who | Contents | Gate |
|---|---|---|---|
| Canvas | Everyone | Full-screen effects | None |
| Home | Child (picture-based, no reading required) | Large tiles: Simple (preselected), style pictures (Watercolour, Disco, Anime, Space) | Corner hold (3 s) from canvas |
| Grown-ups | Adult | Custom settings, sound, haptics, timers, accessibility, Support banner | Parental gate |

### 3.1 Parental gate
- Example: "Hold three fingers on the screen for 3 seconds", or a multiplication question with written numbers.
- Must not ask for or store age, name, or any personal data.
- Required in front of: Custom settings, Support banner (external links), any link out of the app.

### 3.2 Locking the device to the app
Immersive mode and the corner hold do **not** stop a child from leaving the app: the system Home/Recents gestures cannot be fully blocked by an app.
- Android: guide the parent to enable **App pinning** (Settings > Security > App pinning) with an in-app help screen.
- iOS: guide the parent to enable **Guided Access**.
- Show this guidance once on first launch and keep it in the Grown-ups area.

## 4. Feature model

Three independent axes, combined at render time. Presets are curated combinations; Custom exposes the axes directly.

| Axis | Examples | Implementation |
|---|---|---|
| Effect (what a touch does) | Ripple, Burst, Glow pulse, Trail, Shockwave | Touch event spawns an effect instance with position, start time, intensity, type |
| Art style (how it looks) | Watercolour, Disco, Anime, Space | Shader pass: palette, texture, post-processing, persistence |
| Palette | Rainbow cycle, Neon, Pastel, Mono, Bedtime (warm, dim), User-picked | Colour ramp passed to the shader |

### 4.1 Interaction rules
- **Overlap:** ripples rendered as waves and summed per pixel, producing interference (bright crossings, dark bands).
- **Saturation control:** tone mapping so many touches never turn the screen solid white.
- **Energy:** one global value that rises with tap rate and decays over 1-2 s. Drives effect speed, saturation, size and sound tempo. Hard ceiling so whole-hand slapping by a toddler stays pleasant, not chaotic.
- **Cap:** max 64 active effect instances; oldest recycled first.

### 4.2 Art styles - technical meaning

| Style | Look | Technical requirement |
|---|---|---|
| Watercolour | Soft bleeding edges, pigment pooling, paper grain | Persistent feedback buffer (ping-pong render targets) with diffusion + paper texture |
| Disco | Saturated colour, mirror-ball sparkle, beat pulses | Beat clock; flash limits enforced (section 7) |
| Anime | Cel-shaded bands, outlines, speed lines, petals/sparkles | Colour quantisation + edge pass + particle sprites |
| Space | Starfield, nebula noise, touches act as gravity wells | Procedural noise + particle field + bloom |

## 5. Technology choice

Because iOS is planned, a native Kotlin build would be rewritten for iOS. Options compared:

| Criterion | Godot 4 (recommended) | Flutter | Native Kotlin + Swift |
|---|---|---|---|
| GPU shaders | Native, first-class | Fragment shaders supported, more limited | Full control |
| Frame feedback (Watercolour/Space) | Easy (SubViewport render targets) | Awkward (render to image each frame) | Full control |
| Multi-touch | Built in | Built in | Built in |
| Low-latency audio, polyphony | Built in | Third-party plugin | Platform APIs |
| Settings/tiles UI | Adequate | Excellent | Excellent |
| One codebase for Android + iOS | Yes | Yes | No (two apps) |
| Licence / fees | MIT, no fees | BSD, no fees | n/a |
| Test on PC without a phone | Yes (mouse/touchscreen) | Partly | Emulator only |

Recommendation: **Godot 4 (current 4.x stable)**. The product is mostly a real-time effect engine with a small settings UI, which is the profile Godot is built for. Flutter is the fallback if the settings/UI side grows significantly.

### 5.1 Project structure (Godot)

```
project/
  scenes/
    canvas/       Full-screen effect canvas, corner-hold exit
    home/         Child-safe picture tiles
    grownups/     Parental gate, Custom settings, Support banner, help
  engine/
    touch_input   Pointer tracking, IntensityResolver
    energy        Tap-rate energy model
    effect_pool   Active effect instances (cap 64)
  render/
    effects/      Ripple, burst, glow, trail, shockwave shaders
    styles/       Watercolour, disco, anime, space post-process shaders
    palettes/     Colour ramps
  audio/          SoundEngine interface, placeholder no-op, voice limiter
  haptics/        Intensity-scaled vibration
  settings/       Persistent settings + presets
```

## 6. Touch intensity - hardware reality

Most Android phones and all current iPhones do **not** report true finger pressure. Intensity is a blended signal:

| Signal | Reliability |
|---|---|
| Hold duration ("charge up") | High, all devices |
| Swipe velocity | High, all devices |
| Tap rate | High, all devices |
| Contact size | Medium, device-dependent; optional calibration |
| True pressure | Stylus only |

**Palm rejection is off by default.** A 1 year old slapping with a whole hand is valid input. Adult/tablet profile can enable it.

## 7. Safety, sensory and wellbeing

### 7.1 Photosensitivity
- No flashing above 3 per second over large screen areas (WCAG 2.3.1 threshold), in every style including Disco. Hard-coded limit, not a setting.
- Large luminance jumps smoothed over at least 100 ms.

### 7.2 Sensory (neurodivergent users)
- Default preset is **calm**: slow effects, soft palette, gentle sound.
- "Low stimulation" setting: reduced motion, reduced saturation, no sudden sound onsets.
- Predictable behaviour: the same touch gives the same result.
- Respect the system reduce-motion / remove-animations setting.

### 7.3 Hearing
- Master volume capped in-app (default maximum around 60% of device volume), adjustable only in Grown-ups.
- Every sound has a soft attack (no click or sharp onset).

### 7.4 Session wellbeing
- Optional play timer set by the parent: effects slowly fade to dark and sound fades out at the end ("wind down"), rather than an abrupt stop.
- Bedtime palette: warm, dim colours.
- Note for the parent: WHO and AAP guidance recommends no or very limited screen time under age 2. A wind-down timer is the product's honest answer to this, and the Grown-ups help can mention it.

## 8. Privacy, monetisation and store compliance

### 8.1 Privacy
- **No data collected.** No analytics, no crash reporting SDK, no ads SDK, no accounts.
- **No internet permission.** External links open in the system browser, which works without the permission.
- Store data-safety forms: "No data collected / no data shared".
- A short privacy policy page is still required by both stores for apps aimed at children. It states the above.

### 8.2 Support banner
- Location: Grown-ups area only, behind the parental gate, under its own banner. Never prompted, never shown to the child, never time-limited or nagging.
- Charity link: donations to registered charities are exempt from store billing requirements on Google Play and permitted via an external link on iOS. Lowest compliance risk.
- Buy Me a Coffee (developer tip): store rules on external links for tips have changed repeatedly and differ by region, especially on iOS. Recommended: charity link in-app; Buy Me a Coffee on the store listing and website. Re-check current policies before each store submission.

### 8.3 Store readiness
- Google Play: Families policy self-declaration (target age groups), content rating questionnaire, privacy policy URL. New personal developer accounts must run a closed test with testers for a minimum period before production release; check the current requirement when the account is created.
- Apple: Kids Category rules (parental gate before links out, no third-party analytics/ads), Apple Developer Program membership, Mac with Xcode for builds.

## 9. Device and platform considerations

### 9.1 Screen sizes
- Effect sizes defined in physical units (dp/points), so ripples are the same physical size on phone and tablet.
- Aspect-corrected shader coordinates: circles stay round in any orientation.
- Home tiles: large targets (at least 2x the standard 48 dp minimum for toddlers). Phone: 2 columns. Tablet: 3-4 columns.
- Handle rotation, foldables and split-screen without losing canvas state. Option to lock orientation.

### 9.2 Multi-touch
- Track up to 10 pointers.

### 9.3 Performance and thermals
- Target 60 fps sustained on a mid-range 2022 device; higher refresh where available.
- Render effects at 50-100% resolution and upscale; auto-reduce when the device heats up.
- Stop rendering when nothing is animating.
- Keep shader time values small to avoid precision artifacts on low-end GPUs.

### 9.4 Minimum OS
- Android 8.0+ and current Play target API at publish time. iOS: to be set when the iOS build starts.

## 10. Sound (placeholder scope)

- Settings: on/off, volume (capped), sound pack per art style, interaction sounds (when effects overlap).
- Mapping: horizontal position to pitch, intensity to volume, energy to tempo/density.
- Pitch snapped to a pentatonic scale so any tapping sounds musical.
- Maximum 8 simultaneous voices.
- All sounds original or CC0-licensed.

## 11. Open items

1. Which charity (if the charity route is taken).
2. Play timer default (off, or e.g. 15 minutes).
3. Lock orientation by default, or follow the device?
4. Extras for later: live wallpaper mode, music-reactive mode (needs microphone permission, so excluded from the children's version unless behind the gate).

## 12. Development setup (when the PC is connected)

- Godot 4 (current stable) with Android export templates; Android SDK + JDK 17 (Godot's Android export docs list exact versions).
- A physical Android device with USB debugging enabled. Test on one low-end phone and one tablet before any release.
- iOS later: Mac with Xcode, Apple Developer Program membership.
