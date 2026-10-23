# Touch Colour App - Product Spec (Draft v0.1)

Status: discussion draft. Nothing here is locked until the open decisions in section 9 are answered.

## 1. Core concept

A full-screen canvas. Every touch produces a colour/light effect, similar to a reactive RGB keyboard. Touches interact with each other (e.g. overlapping ripples), and rapid tapping speeds up and intensifies the response.

## 2. Screens

| Screen | Purpose |
|---|---|
| Home | Two large tiles: **Simple** (preselected) and **Custom**. One tap on Simple goes straight to the canvas. |
| Custom | Tiles for: Palette, Effect, Art Style, Light Behaviour, Interaction, Sound, Haptics, Performance. Live preview strip at the top. |
| Canvas | Full-screen, immersive (system bars hidden). Exit via a deliberate gesture (see 6.3). |

## 3. Feature model

Three independent axes, combined at render time. Presets are curated combinations; Custom exposes the axes directly.

| Axis | Examples | Implementation |
|---|---|---|
| Effect (what a touch does) | Ripple, Burst, Glow pulse, Trail, Shockwave | Touch event spawns an effect instance with position, start time, intensity, type |
| Art style (how it looks) | Watercolour, Disco, Anime, Space | Shader pass: palette, texture, post-processing, persistence |
| Palette | Rainbow cycle, Neon, Pastel, Mono, User-picked | Uniform colour ramp passed to the shader |

### 3.1 Interaction rules

- **Overlap:** ripples are rendered as waves and summed per pixel, so crossings produce interference (constructive bright spots, destructive dark bands). This is physically correct, cheap on GPU, and looks better than alpha-stacking.
- **Saturation control:** additive light saturates to white with many touches. A tone-mapping step is required.
- **Tap tempo ("energy"):** a single global value that rises with tap rate and decays over ~1-2 s. It drives effect speed, saturation, spawn size, and sound tempo. One scalar, many outputs: simple to tune.
- **Cap:** max active effect instances (target 64). Oldest instance is recycled when the cap is hit.

### 3.2 Art styles - technical meaning

| Style | Look | Technical requirement |
|---|---|---|
| Watercolour | Soft bleeding edges, pigment pooling, paper grain | Persistent feedback buffer (ping-pong framebuffers) with diffusion + paper texture |
| Disco | Hard saturated colour, strobes, mirror-ball sparkle | Beat clock; **strobe must respect photosensitivity limits (section 7)** |
| Anime | Cel-shaded bands, outlines, speed lines, petals/sparkles | Colour quantisation + edge pass + particle sprites |
| Space | Starfield, nebula noise, touches act as gravity wells / supernovas | Procedural noise + particle field + bloom |

Watercolour and Space both need persistence between frames, which drives the rendering choice in section 5.

## 4. Touch intensity - hardware reality

Most current Android phones do **not** report true touch pressure. `MotionEvent.getPressure()` on most devices returns a constant or a value derived from contact area. Intensity must therefore be a blended signal:

| Signal | Source | Reliability |
|---|---|---|
| Contact size | `getTouchMajor()` / `getSize()` | Medium: varies by device, needs calibration |
| Hold duration | down-to-up time ("charge up") | High on all devices |
| Swipe velocity | `VelocityTracker` | High on all devices |
| Tap rate | time between taps | High on all devices |
| True pressure | Stylus (S Pen, etc.) only | High, but only with stylus |

Plan: an `IntensityResolver` that combines these, plus a one-time optional calibration ("tap softly, then firmly").

## 5. Architecture

- **Language/UI:** Kotlin, Jetpack Compose for Home and Custom screens.
- **Renderer:** OpenGL ES 3.0 via `GLSurfaceView` (or `SurfaceView` + EGL). All effects computed in fragment shaders on the GPU; CPU only manages a small list of touch events.
  - Why not Compose Canvas: draw calls are issued per shape from the CPU; fine for dozens of shapes, poor for per-pixel interference and feedback buffers.
  - Why not AGSL (`RuntimeShader`): requires Android 13+, and has no convenient frame-to-frame feedback for Watercolour/Space.
  - Why not Vulkan: far more code for no visible gain at this scale.
- **Render loop:** vsync-driven, time-based animation (works at 60/90/120 Hz). Render continuously only while effects are alive; idle otherwise to save battery.
- **Resolution scaling:** render to an off-screen buffer at 50-100% of screen resolution and upscale. Biggest single lever for battery and heat on tablets.
- **Settings:** Jetpack DataStore. Presets exportable as JSON (later: share via QR code).
- **Sound:** `SoundEngine` interface with a no-op placeholder now. Real implementation via `SoundPool` (samples) first; Oboe (native, low latency) only if latency proves unacceptable.
- **Haptics:** `VibrationEffect` scaled by intensity; haptic primitives on Android 11+.

### 5.1 Module sketch

```
app/
  ui/home        Home tiles (Simple / Custom)
  ui/custom      Settings tiles + live preview
  canvas/        GL surface, render loop, touch input
  engine/        TouchEvent model, IntensityResolver, Energy, effect pool
  render/        Shaders per effect and per art style, framebuffer manager
  audio/         SoundEngine interface + NoOp + SoundPool implementation
  haptics/       HapticEngine
  settings/      DataStore, presets
```

## 6. Device and platform considerations

### 6.1 Screen sizes
- Effect sizes defined in dp, not pixels, so a ripple is the same physical size on phone and tablet.
- Shader coordinates aspect-corrected so circles stay round in any orientation.
- Settings layout adapts via `WindowSizeClass` (phone: single column; tablet/foldable: grid with live preview alongside).
- Handle rotation, foldable hinge/posture changes, and split-screen without losing canvas state.

### 6.2 Multi-touch
- Track up to 10 pointers. Palm rejection on tablets (ignore very large contact areas).

### 6.3 System gesture conflicts
- With gesture navigation, edge swipes trigger Back/Home. Use immersive mode and `setSystemGestureExclusionRects` (Android limits exclusion to 200 dp per vertical edge, so the full edge cannot be claimed).
- Exit gesture from canvas must be deliberate and unlikely to fire by accident: e.g. hold a corner for 2 s, or two-finger long press. Decision needed (section 9).

### 6.4 Performance and thermals
- Target: 60 fps sustained on a mid-range 2022 device; 120 fps where available.
- Use `PowerManager` thermal headroom to step down resolution/frame rate before the OS throttles.
- Low-end GPU risk (Mali/PowerVR): `mediump` float precision causes artifacts when time values grow large. Keep shader time wrapped/rebased.

### 6.5 Minimum Android version
- Proposed `minSdk 26` (Android 8.0): OpenGL ES 3.0 and modern audio/haptics available, near-full device coverage. `targetSdk` per current Google Play requirement at publish time.

## 7. Safety and compliance

- **Photosensitive epilepsy:** flashing more than 3 times per second over a large area is a recognised seizure trigger (WCAG 2.3.1). Required: first-launch warning, a "Reduce flashing" setting on by default, and a hard cap on strobe frequency and luminance delta in Disco mode.
- **Reduce motion:** respect the system animation-scale / remove-animations setting.
- **Children:** if the target audience includes children, Google Play Families policy applies (ad and analytics SDK restrictions, data handling, a parental gate in front of settings and purchases). Decision needed (section 9).
- **Assets:** all sounds, textures and fonts must be original or licensed (e.g. CC0). "Anime" is a visual style only: no third-party characters or trademarks.

## 8. Sound (placeholder scope)

- Settings now: master volume, on/off, sound pack per art style, "interaction sounds" toggle (sounds when effects collide/overlap).
- Mapping idea: horizontal position maps to pitch, intensity maps to volume, energy maps to tempo/density.
- Quantise pitch to a pentatonic scale so random tapping always sounds musical rather than dissonant.
- Polyphony cap (e.g. 8 voices) to prevent noise when tapping fast.

## 9. Open decisions

1. **Target audience:** adults (relaxation, visual toy), young children (sensory/cause-and-effect), or neurodivergent sensory use? Changes policy obligations, UI locking, and monetisation.
2. **Business model:** free, one-off paid, or free with paid style packs? (Ads strongly not recommended: they break the full-screen experience and, for children, are heavily restricted.)
3. **Canvas exit gesture:** corner hold, two-finger long press, or other.
4. **Platform scope:** Android only, or iOS later? (If iOS is likely within 12 months, Flutter with fragment shaders is worth reconsidering before code is written.)
5. **Extras:** live wallpaper mode (reuses the same renderer, low extra cost), screen-saver mode, music-reactive mode (microphone, adds a permission).

## 10. Development setup (when the PC is connected)

- Android Studio (current stable), Android SDK, JDK 17+.
- A **physical device** with USB debugging enabled. The emulator does not represent real GPU performance and makes multi-touch testing awkward.
- Ideally test on one low-end phone and one tablet before any release.
