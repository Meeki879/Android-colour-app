shader_type canvas_item;
render_mode unshaded, blend_mix;

// Effect slots, filled by scenes/canvas/canvas.gd. Array size must match MAX_EFFECTS there.
// fx_a: position x, position y (canvas units), start time (s), intensity (0..1)
// fx_b: kind (0 ripple, 1 burst, 2 glow), hue offset, speed (cm/s), end time (s, glow release)
uniform vec4 fx_a[64];
uniform vec4 fx_b[64];
uniform int fx_count = 0;

uniform float time_now = 0.0;
uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform float units_per_cm = 60.0;
uniform float energy = 0.0;
uniform int style = 0; // 0 watercolour, 1 disco, 2 anime, 3 space
uniform float persistence = 0.0;
uniform float saturation = 1.0;
uniform float master = 1.0; // wind-down timer fade

uniform vec3 pal_a = vec3(0.5);
uniform vec3 pal_b = vec3(0.5);
uniform vec3 pal_c = vec3(1.0);
uniform vec3 pal_d = vec3(0.0, 0.33, 0.67);

// Lifetimes must match canvas.gd.
const float RIPPLE_LIFE = 3.0;
const float BURST_LIFE = 1.2;
const float GLOW_FADE = 0.8;
const float WAVELENGTH_CM = 1.4;

vec3 palette(float t) {
	return pal_a + pal_b * cos(TAU * (pal_c * t + pal_d));
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

void fragment() {
	// Work in centimetres so effects are the same physical size on phone and tablet.
	vec2 p = UV * rect_size / units_per_cm;

	float wave = 0.0;   // signed: ripples interfere (crossings add or cancel)
	float light = 0.0;  // unsigned glow and bursts
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
		float d = distance(p, a.xy / units_per_cm);
		float amp = a.w;
		float contrib = 0.0;
		int kind = int(b.x + 0.5);

		if (kind == 0) {
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
			float x = d - age * b.z * 1.8;
			if (abs(x) > 1.0) {
				continue;
			}
			float life_k = 1.0 - clamp(age / BURST_LIFE, 0.0, 1.0);
			contrib = exp(-(x * x) / 0.12) * amp * life_k * life_k;
			light += contrib;
		} else {
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

	vec3 col;
	if (style == 0) {
		// Watercolour: pigment multiplied onto grainy paper. Trails come from persistence.
		vec3 paper = vec3(0.96, 0.94, 0.89) * (0.94 + 0.06 * value_noise(p * 6.0));
		float bleed = 0.85 + 0.15 * value_noise(p * 2.0 + time_now * 0.05);
		col = paper * mix(vec3(1.0), pig, clamp(smoothstep(0.0, 0.9, v) * bleed, 0.0, 1.0));
	} else if (style == 1) {
		// Disco. Photosensitivity rule (spec 7.1): only smooth modulation at 1 Hz, never strobing.
		float beat = 0.9 + 0.1 * sin(time_now * TAU);
		vec2 cell = floor(p * 2.5);
		float seed = hash21(cell);
		float twinkle = 0.5 + 0.5 * sin(time_now * 1.5 + seed * TAU);
		float dot_k = 1.0 - smoothstep(0.0, 0.35, distance(fract(p * 2.5), vec2(0.5)));
		float sparkle = step(0.93, seed) * twinkle * dot_k;
		col = vec3(0.03, 0.0, 0.06) + pig * v * beat * 1.2 + vec3(sparkle) * 0.35 * (0.3 + energy);
	} else if (style == 2) {
		// Anime: cel-shaded bands with dark outlines on a soft sky.
		float bands = floor(v * 4.0 + 0.5) / 4.0;
		vec3 sky = mix(vec3(1.0, 0.86, 0.9), vec3(0.75, 0.85, 1.0), UV.y);
		col = mix(sky, pig, bands * 0.9);
		col *= 1.0 - 0.5 * clamp(fwidth(bands) * 4.0, 0.0, 1.0);
	} else {
		// Space: twinkling stars, faint nebula, touches glow like stars being born.
		float seed = hash21(floor(p * 3.0));
		float star = step(0.97, seed) * (1.0 - smoothstep(0.0, 0.12, distance(fract(p * 3.0), vec2(0.5))));
		star *= 0.6 + 0.4 * sin(time_now * 0.7 + seed * 40.0);
		float neb = value_noise(p * 0.35 + time_now * 0.01) * 0.12;
		col = vec3(0.01, 0.01, 0.03) + palette(0.6 + neb) * neb + vec3(star) * 0.8 + pig * v * 1.1;
	}

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation) * master;
	// Alpha < 1 blends over the previous frame (the viewport is never cleared), giving trails.
	COLOR = vec4(col, 1.0 - persistence);
}
