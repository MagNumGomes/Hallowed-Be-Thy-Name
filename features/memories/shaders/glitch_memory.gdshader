shader_type canvas_item;
render_mode unshaded, blend_disabled;

// Godot 4: a tela anterior é capturada antes de desenhar este ColorRect.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Todos os efeitos passam por este controle; zero é a imagem original.
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float chromatic_aberration : hint_range(0.0, 12.0, 0.1) = 3.0; // pixels
uniform float scanline_strength : hint_range(0.0, 0.25, 0.005) = 0.06;
uniform float scanline_spacing : hint_range(2.0, 8.0, 0.5) = 3.0; // pixels
uniform float distortion_amount : hint_range(0.0, 100.0, 0.5) = 24.0; // pixels
uniform float block_probability : hint_range(0.0, 1.0) = 0.18;
uniform vec2 block_size = vec2(64.0, 12.0); // pixels; mínimo efetivo: 1
uniform float glitch_speed : hint_range(1.0, 60.0, 1.0) = 14.0;
uniform float seed : hint_range(0.0, 100.0) = 7.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 screen_clamp(vec2 uv, vec2 pixel_size) {
	vec2 margin = pixel_size * 0.5;
	return clamp(uv, margin, vec2(1.0) - margin);
}

void fragment() {
	float intensity = clamp(glitch_intensity, 0.0, 1.0);
	vec4 original = texture(screen_texture, SCREEN_UV);
	if (intensity <= 0.0) {
		COLOR = original;
	} else {
		vec2 pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;
		float tick = floor(TIME * max(glitch_speed, 1.0));
		vec2 block = floor(pixel / max(block_size, vec2(1.0)));
		vec2 key = block + vec2(tick * 17.0 + seed, tick * 3.0);
		float active = 1.0 - step(clamp(block_probability, 0.0, 1.0) * intensity, hash21(key));
		float displacement = (hash21(key + 41.0) * 2.0 - 1.0)
			* distortion_amount * intensity * active;
		vec2 displaced_uv = SCREEN_UV + vec2(displacement * SCREEN_PIXEL_SIZE.x, 0.0);

		// Separação RGB aleatória por faixa, estável entre os ticks do glitch.
		float chroma = (hash21(vec2(tick + seed, block.y + 93.0)) * 2.0 - 1.0)
			* chromatic_aberration * intensity * SCREEN_PIXEL_SIZE.x;
		vec4 center = texture(screen_texture, screen_clamp(displaced_uv, SCREEN_PIXEL_SIZE));
		vec3 color = vec3(
			texture(screen_texture, screen_clamp(displaced_uv + vec2(chroma, 0.0), SCREEN_PIXEL_SIZE)).r,
			center.g,
			texture(screen_texture, screen_clamp(displaced_uv - vec2(chroma, 0.0), SCREEN_PIXEL_SIZE)).b
		);
		float scanline = 0.5 + 0.5 * sin(pixel.y * 6.2831853 / max(scanline_spacing, 2.0));
		color *= 1.0 - scanline * clamp(scanline_strength, 0.0, 0.25) * intensity;
		COLOR = vec4(color, center.a);
	}
}
