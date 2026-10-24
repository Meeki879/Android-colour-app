shader_type canvas_item;
render_mode unshaded, blend_mix;

// Effect slots, filled by scenes/canvas/canvas.gd. Array size must match MAX_EFFECTS there.
// fx_a: position x, position y (canvas units), start time (s), intensity (0..1)
// fx_b: kind (0 ripple, 1 cross lines, 2 glow), hue offset, speed (cm/s), end time (s, glow release)
uniform vec4 fx_a[64];
uniform vec4 fx_b[64];
uniform int fx_count = 0;

uniform float time_now = 0.0;
uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform float units_per_cm = 60.0;
uniform float energy = 0.0;
uniform int theme = 0;   // 0 simple, 1 watercolour, 2 disco, 3 anime, 4 space
uniform int ambient = 0; // 0 off, 1 breathing, 2 wave, 3 spectrum
uniform float persistence = 0.0;
uniform float saturation = 1.0;
uniform float master = 1.0; // wind-down timer fade

uniform vec3 pal[5];
uniform int pal_n = 5;

// Lifetimes must match canvas.gd.
const float RIPPLE_LIFE = 3.0;
const float CROSS_LIFE = 2.0;
const float GLOW_FADE = 0.8;
const float WAVELENGTH_CM = 1.4;

// Colour stops blended in a loop.
vec3 palette(float t) {
	float x = fract(t) * float(pal_n);
	int i = int(floor(x));
	int j = i + 1;
	if (j >= pal_n) {
		j = 0;
	}
	return mix(pal[i], pal[j], smoothstep(0.0, 1.0, fract(x)));
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float disc(vec2 q, vec2 c, float r, float aa) {
	return 1.0 - smoothstep(r - aa, r + aa, distance(q, c));
}

float box(vec2 q, vec2 lo, vec2 hi, float aa) {
	vec2 a = smoothstep(lo - aa, lo + aa, q) * (1.0 - smoothstep(hi - aa, hi + aa, q));
	return a.x * a.y;
}

// ---- Theme backgrounds (procedural placeholders until illustrated art replaces them) ----

vec3 bg_paper(vec2 p) {
	float grain = value_noise(p * 9.0);
	float fibre = value_noise(vec2(p.x * 1.5, p.y * 14.0));
	return vec3(0.97, 0.955, 0.92) * (0.96 + 0.03 * grain + 0.02 * fibre);
}

vec3 bg_canvas(vec2 p) {
	float weave = sin(p.x * TAU * 10.0) * sin(p.y * TAU * 10.0);
	float threads = 0.5 + 0.5 * sin(p.x * TAU * 10.0 + value_noise(p * 3.0) * 2.0);
	return vec3(0.93, 0.905, 0.85) * (0.94 + 0.03 * weave + 0.02 * threads + 0.02 * value_noise(p * 4.0));
}

// Classic bathroom tiles: light and slightly darker grey checkerboard, 2.5 cm squares.
vec3 bg_tiles(vec2 p) {
	float size = 2.5;
	vec2 cell = floor(p / size);
	vec2 f = fract(p / size);
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 tile = mix(vec3(0.86), vec3(0.74), checker);
	tile += 0.05 * (1.0 - f.y) * (1.0 - f.x);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * size;
	float grout = 1.0 - smoothstep(0.04, 0.08, edge);
	return mix(tile, vec3(0.62), grout);
}

vec3 cherry_tree(vec3 col, vec2 b, float x, float aa) {
	col = mix(col, vec3(0.52, 0.38, 0.3), box(b, vec2(x - 0.015, 0.2), vec2(x + 0.015, 0.42), aa));
	float bloom = max(max(disc(b, vec2(x, 0.47), 0.1, aa), disc(b, vec2(x - 0.08, 0.42), 0.075, aa)),
		disc(b, vec2(x + 0.08, 0.42), 0.075, aa));
	return mix(col, vec3(1.0, 0.79, 0.85) - 0.05 * value_noise(b * 60.0), bloom);
}

// Faded school building and courtyard. b: x centred, y up from the bottom, in short-side units.
vec3 bg_schoolyard(vec2 b, float aa) {
	vec3 col = mix(vec3(0.93, 0.95, 1.0), vec3(0.62, 0.79, 0.96), clamp((b.y - 0.3) / 1.2, 0.0, 1.0));
	float cloud = smoothstep(0.55, 0.75, value_noise(vec2(b.x * 3.0 + time_now * 0.01, b.y * 6.0)));
	col = mix(col, vec3(1.0), cloud * smoothstep(0.85, 1.05, b.y) * 0.8);

	vec3 yard = vec3(0.87, 0.81, 0.69) * (0.97 + 0.03 * step(0.9, fract(b.x * 8.0)));
	col = mix(col, yard, 1.0 - smoothstep(0.28 - aa, 0.28 + aa, b.y));

	vec3 wall = vec3(0.95, 0.92, 0.84);
	vec3 roof = vec3(0.55, 0.6, 0.68);
	vec2 w = vec2(fract(b.x / 0.12), fract((b.y - 0.3) / 0.1));
	float win = step(0.25, w.x) * step(w.x, 0.75) * step(0.3, w.y) * step(w.y, 0.8)
		* step(0.31, b.y) * step(b.y, 0.6);
	vec3 front = mix(mix(wall, vec3(0.68, 0.8, 0.9), win), roof, step(0.6, b.y));
	col = mix(col, front, box(b, vec2(-0.8, 0.28), vec2(0.8, 0.62), aa));
	col = mix(col, vec3(0.6, 0.5, 0.45), box(b, vec2(-0.06, 0.28), vec2(0.06, 0.38), aa));

	col = mix(col, wall, box(b, vec2(-0.11, 0.62), vec2(0.11, 0.8), aa));
	col = mix(col, roof, box(b, vec2(-0.13, 0.8), vec2(0.13, 0.83), aa));
	vec2 cc = vec2(0.0, 0.71);
	col = mix(col, vec3(0.35, 0.38, 0.45), disc(b, cc, 0.065, aa));
	col = mix(col, vec3(1.0), disc(b, cc, 0.055, aa));
	vec2 d = b - cc;
	col = mix(col, vec3(0.3), box(d, vec2(-0.004, 0.0), vec2(0.004, 0.042), aa));
	col = mix(col, vec3(0.3), box(d, vec2(0.0, -0.004), vec2(0.03, 0.004), aa));

	col = cherry_tree(col, b, -0.42, aa);
	col = cherry_tree(col, b, 0.42, aa);
	col = cherry_tree(col, b, -0.95, aa);
	col = cherry_tree(col, b, 0.95, aa);
	return mix(col, vec3(1.0), 0.3);
}

// Cartoon solar system: sun at the left edge, planets swinging along their orbits.
// q: short-side units with y down; extent: screen size in the same units.
vec3 bg_solar(vec2 q, vec2 extent, vec2 p, float aa) {
	vec3 col = vec3(0.04, 0.05, 0.14);
	float seed = hash21(floor(p * 3.0));
	float star = step(0.97, seed) * (1.0 - smoothstep(0.0, 0.1, distance(fract(p * 3.0), vec2(0.5))));
	col += vec3(star) * (0.5 + 0.3 * sin(time_now * 0.7 + seed * 40.0));

	vec2 sun = vec2(-0.12, extent.y * 0.5);
	float ds = distance(q, sun);
	col += vec3(1.0, 0.6, 0.2) * exp(-max(ds - 0.34, 0.0) * 8.0) * 0.35;
	vec3 sun_col = mix(vec3(1.0, 0.9, 0.45), vec3(1.0, 0.65, 0.2), smoothstep(0.1, 0.34, ds));
	col = mix(col, sun_col, disc(q, sun, 0.34, aa));

	for (int k = 0; k < 6; k++) {
		float fk = float(k);
		float orbit = 0.55 + fk * 0.32;
		col = mix(col, vec3(0.45, 0.5, 0.75), (1.0 - smoothstep(0.0, 0.004 + aa, abs(ds - orbit))) * 0.35);
		float ang = 1.0 * sin(hash21(vec2(fk, 7.0)) * TAU + time_now * 0.05 / (1.0 + 0.3 * fk));
		vec2 pc = sun + orbit * vec2(cos(ang), sin(ang));
		float pr = 0.035 + 0.05 * hash21(vec2(fk, 3.0));
		vec3 pcol = 0.55 + 0.45 * cos(TAU * (hash21(vec2(fk, 11.0)) + vec3(0.0, 0.33, 0.67)));
		vec2 n = (q - pc) / pr;
		float shade = clamp(0.65 + 0.45 * dot(normalize(sun - pc), n), 0.4, 1.1);
		float ring = 0.0;
		if (k == 3) {
			float rl = length((q - pc) / vec2(pr * 2.2, pr * 0.6));
			ring = (1.0 - smoothstep(0.85, 1.0, rl)) * smoothstep(0.65, 0.75, rl);
			col = mix(col, vec3(0.9, 0.82, 0.6), ring * 0.9);
		}
		col = mix(col, pcol * shade, disc(q, pc, pr, aa));
		col = mix(col, vec3(0.9, 0.82, 0.6), ring * 0.9 * step(0.0, q.y - pc.y));
	}
	return col;
}

void fragment() {
	vec2 px = UV * rect_size;
	float s = min(rect_size.x, rect_size.y);
	float aa = 1.5 / s;
	// Effects work in centimetres so they are the same physical size on phone and tablet.
	vec2 p = px / units_per_cm;
	// Backgrounds work in short-side units so the scene composes to the screen.
	vec2 q = px / s;
	vec2 qb = vec2((px.x - rect_size.x * 0.5) / s, (rect_size.y - px.y) / s);

	float wave = 0.0;   // signed: ripples interfere (crossings add or cancel)
	float light = 0.0;  // unsigned: cross lines and glows
	float hue_acc = 0.0;
	float hue_w = 0.0;

	for (int i = 0; i < 64; i++) {
		if (i >= fx_count) {
			break;
		}
		vec4 a = fx_a[i];
		vec4 b = fx_b[i];
		float age = time_now - a.z;
		if (age < 0.0) {
			continue;
		}
		vec2 c = a.xy / units_per_cm;
		float amp = a.w;
		float contrib = 0.0;
		int kind = int(b.x + 0.5);

		if (kind == 0) {
			float d = distance(p, c);
			float r = age * b.z;
			float width = 0.5 + 0.8 * amp;
			float x = d - r;
			if (abs(x) > 3.0 * width) {
				continue;
			}
			float life_k = 1.0 - clamp(age / RIPPLE_LIFE, 0.0, 1.0);
			float env = exp(-(x * x) / (width * width)) * amp * life_k * life_k / (1.0 + 0.15 * r);
			wave += sin(x * TAU / WAVELENGTH_CM) * env;
			contrib = env;
		} else if (kind == 1) {
			// Cross lines: a pulse runs out along the horizontal and vertical lines through the touch.
			vec2 dv = abs(p - c);
			float half_w = 0.12 + 0.12 * amp;
			if (min(dv.x, dv.y) > 3.0 * half_w) {
				continue;
			}
			float r = age * b.z * 1.5;
			float life_k = 1.0 - clamp(age / CROSS_LIFE, 0.0, 1.0);
			float hx = (dv.x - r) / 1.2;
			float hy = (dv.y - r) / 1.2;
			float arm_h = exp(-(dv.y * dv.y) / (half_w * half_w)) * (exp(-hx * hx) + 0.2 * step(dv.x, r));
			float arm_v = exp(-(dv.x * dv.x) / (half_w * half_w)) * (exp(-hy * hy) + 0.2 * step(dv.y, r));
			contrib = (arm_h + arm_v) * amp * life_k * life_k;
			light += contrib;
		} else {
			float d = distance(p, c);
			float held = min(b.w - a.z, 3.0);
			float rad = 0.7 + held * 0.5;
			if (d > rad * 3.0) {
				continue;
			}
			float fade = 1.0 - clamp((time_now - b.w) / GLOW_FADE, 0.0, 1.0);
			float pulse = 0.85 + 0.15 * sin(age * 3.0);
			contrib = exp(-(d * d) / (rad * rad)) * amp * fade * pulse;
			light += contrib * 0.7;
		}
		hue_acc += b.y * contrib;
		hue_w += contrib;
	}

	light += abs(wave);
	// Tone map: many overlapping touches approach full brightness instead of clipping to white.
	float v = 1.0 - exp(-light * 1.6);
	float hue = hue_acc / max(hue_w, 0.0001) + wave * 0.08 + time_now * 0.02 * (1.0 + energy);
	vec3 pig = palette(hue);

	// Background animation. All slow and smooth: photosensitivity rule (spec 7.1).
	float amb = 0.0;
	float amb_hue = 0.0;
	if (ambient == 1) {
		amb = 0.2 * (0.5 + 0.5 * sin(time_now * TAU * 0.2));
		amb_hue = time_now * 0.02;
	} else if (ambient == 2) {
		amb = 0.22;
		amb_hue = (p.x + p.y) * 0.04 - time_now * 0.08;
	} else if (ambient == 3) {
		amb = 0.18;
		amb_hue = time_now * 0.05;
	}
	vec3 amb_col = palette(amb_hue);
	vec3 lightc = pig * v + amb_col * amb;

	vec3 col;
	if (theme == 0) {
		// Simple: colour inked onto paper (multiply).
		vec3 ink = mix(vec3(1.0), pig, clamp(v * 0.9, 0.0, 1.0));
		col = bg_paper(p) * ink * mix(vec3(1.0), amb_col, amb);
	} else if (theme == 1) {
		// Watercolour: pigment bleeding into canvas. Trails come from persistence.
		float bleed = 0.85 + 0.15 * value_noise(p * 2.0 + time_now * 0.05);
		vec3 ink = mix(vec3(1.0), pig, clamp(smoothstep(0.0, 0.9, v) * bleed, 0.0, 1.0));
		col = bg_canvas(p) * ink * mix(vec3(1.0), amb_col, amb);
	} else if (theme == 2) {
		// Disco: coloured light falling on bathroom tiles, plus mirror-ball sparkles.
		float beat = 0.95 + 0.05 * sin(time_now * TAU);
		float seed = hash21(floor(p * 2.5));
		float twinkle = 0.5 + 0.5 * sin(time_now * 1.5 + seed * TAU);
		float dot_k = 1.0 - smoothstep(0.0, 0.3, distance(fract(p * 2.5), vec2(0.5)));
		float sparkle = step(0.94, seed) * twinkle * dot_k * (0.3 + energy);
		col = bg_tiles(p) * (0.85 * beat + 1.2 * lightc) + lightc * 0.15 + vec3(sparkle) * 0.3;
	} else if (theme == 3) {
		// Anime: cel-shaded light bands with outlines over a faded schoolyard.
		float lv = clamp(v + amb, 0.0, 1.0);
		float bands = floor(lv * 4.0 + 0.5) / 4.0;
		vec3 tint = mix(amb_col, pig, clamp(v / max(lv, 0.001), 0.0, 1.0));
		col = mix(bg_schoolyard(qb, aa), tint, bands * 0.85);
		col *= 1.0 - 0.5 * clamp(fwidth(bands) * 4.0, 0.0, 1.0);
	} else {
		// Space: touches glow like light over a cartoon solar system.
		col = bg_solar(q, rect_size / s, p, aa) + lightc * 1.1;
	}

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation) * master;
	// Alpha < 1 blends over the previous frame (the viewport is never cleared), giving trails.
	COLOR = vec4(col, 1.0 - persistence);
}
