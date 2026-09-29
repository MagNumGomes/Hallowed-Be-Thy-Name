shader_type canvas_item;
render_mode blend_mix;

// 1 = íntegra; 0 = quebrada. O controlador converte current / maximum.
uniform float durability : hint_range(0.0, 1.0) = 1.0;
uniform float corrosion_intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec4 rust_color : source_color = vec4(0.46, 0.17, 0.065, 1.0);
uniform vec4 patina_color : source_color = vec4(0.12, 0.39, 0.32, 1.0);
uniform vec4 electric_color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float rust_strength : hint_range(0.0, 1.0) = 0.85;
uniform float patina_strength : hint_range(0.0, 1.0) = 0.65;
uniform float noise_scale : hint_range(2.0, 64.0, 1.0) = 12.0; // pixels por mancha
uniform float electric_strength : hint_range(0.0, 1.0) = 0.7;
uniform float electric_speed : hint_range(1.0, 60.0, 1.0) = 18.0;
uniform float seed : hint_range(0.0, 100.0) = 13.0;

varying vec4 item_tint;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x),
		f.y
	);
}

void vertex() {
	// Captura modulate/self_modulate antes da multiplicação pela textura.
	item_tint = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float wear = (1.0 - clamp(durability, 0.0, 1.0)) * clamp(corrosion_intensity, 0.0, 1.0);
	vec3 color = base.rgb;
	if (wear > 0.0) {
		// A corrosão fica presa à textura, sem deslizar quando a sprite se move.
		vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
		vec2 p = pixel / max(noise_scale, 2.0) + vec2(seed);
		float patches = value_noise(p) * 0.7 + value_noise(p * 2.7) * 0.3;
		float threshold = mix(1.0, 0.15, wear);
		float rust = smoothstep(threshold - 0.12, threshold + 0.12, patches) * wear;
		float patina = smoothstep(0.48, 0.78, value_noise(p * 0.8 + vec2(31.0))) * rust;
		float grain = hash21(floor(pixel) + vec2(seed));
		float shading = mix(0.55, 1.15, dot(base.rgb, vec3(0.299, 0.587, 0.114)));
		color = mix(color, rust_color.rgb * shading, rust * rust_strength);
		color = mix(color, patina_color.rgb * shading, patina * patina_strength);
		color *= 1.0 - grain * rust * 0.18;

		// Centelhas esparsas, mais frequentes e fortes perto da quebra.
		float tick = floor(TIME * max(electric_speed, 1.0));
		vec2 electric_cell = floor(pixel / vec2(3.0, 1.0));
		float spark = step(1.0 - 0.08 * wear * wear,
			hash21(electric_cell + vec2(tick * 7.0 + seed, tick * 13.0)));
		float pulse = step(0.55, hash21(vec2(tick, seed + 57.0)));
		color += electric_color.rgb * spark * pulse * electric_strength * wear;
	}
	// Mantém transparência e tint da sprite; nenhuma centelha fora da silhueta.
	COLOR = vec4(color, base.a) * item_tint;
}
