shader_type canvas_item;
uniform bool enabled = true;

void fragment() {
	vec4 tint = COLOR;
	float burst = enabled ? step(0.94, sin(TIME * 2.3)) : 0.0;
	float band = step(0.5, sin(UV.y * 91.0 + floor(TIME * 14.0)));
	vec2 offset = vec2(0.004 * burst * band * sin(TIME * 47.0), 0.0);
	vec4 base = texture(TEXTURE, UV + offset);
	base.r = mix(base.r, texture(TEXTURE, UV - offset).r, burst);
	COLOR = base * tint;
}
