# Touch Colours

A touch-reactive colour and light app for children, young adults and neurodivergent users. Every touch produces colour effects (ripples, bursts, glows) in a chosen art style, similar to a reactive RGB keyboard.

- Product spec and decisions: [docs/PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md)
- Engine: Godot 4 (GL Compatibility renderer), one codebase for Android and iOS
- Status: Phase 1 skeleton

## Run on a PC

1. Install Godot 4.3 or newer (standard build, not .NET) from godotengine.org.
2. In Godot: Import > select `app/project.godot` > Import & Edit.
3. Press F5. The window opens at phone proportions.
4. Mouse clicks act as touches (hold the button to charge a ripple, drag for trails). Multi-touch needs a real touchscreen or phone.
5. Leave the play screen by holding the top-left corner for 3 seconds.
6. Grown-ups area: tap Custom, then answer the multiplication question.

## Run on an Android phone

1. Enable Developer options and USB debugging on the phone, connect it by USB.
2. Godot: Editor > Manage Export Templates > Download and Install.
3. Install Android SDK + JDK 17 and set their paths in Editor Settings > Export > Android (see Godot docs: "Exporting for Android").
4. Project > Export > Add > Android. Enable permission **Vibrate**. Keep Immersive Mode on.
5. Use the one-click deploy (Android icon, top right of the editor) to run on the phone.

## Layout

```
app/
  main.gd               Screen router (Back ignored on canvas)
  settings/settings.gd  Persistent settings, play timer, charity link (autoload: Settings)
  scenes/home/          Child-safe home tiles
  scenes/canvas/        Touch canvas, corner-hold exit
  scenes/grownups/      Parental gate + Custom settings + help
  engine/               Energy (tap tempo), intensity resolver
  render/               Effect shader (ripples, bursts, glow, 4 art styles)
  audio/sfx.gd          Placeholder pentatonic tone, 8-voice cap (autoload: Sfx)
  haptics/haptics.gd    Intensity-scaled vibration (autoload: Haptics)
  ui/ui_kit.gd          Large-tile UI helpers
```

## Known limitations (Phase 1)

- Untested in the Godot editor at time of writing: scripts were syntax-checked only. Report any editor errors.
- Ripples are analytic and do not yet reflect off objects (Phase 2: GPU wave simulation + obstacles).
- One placeholder tone; real sound packs come in Phase 3.
- No app icon or store assets yet.
