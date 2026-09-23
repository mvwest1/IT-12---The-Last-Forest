// Burnt -> green blend driven by ONE global value.
// Apply as a ShaderMaterial to the TileMapLayer, props, and background layers.
// Requires Project Settings > Shader Globals: "restoration" (float, default 0.0).
shader_type canvas_item;

global uniform float restoration;

// Char/ash palette for the fully burnt look.
uniform vec3 burnt_tint : source_color = vec3(0.42, 0.33, 0.28);
uniform float burnt_brightness : hint_range(0.2, 1.0) = 0.6;
// Stagger per node (0..0.3) so everything doesn't turn green at the same instant.
uniform float delay : hint_range(0.0, 0.5) = 0.0;

vec3 burn(vec3 c) {
	float gray = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(vec3(gray), burnt_tint * gray * 1.8, 0.65) * burnt_brightness;
}

void fragment() {
	// In Godot 4, COLOR here already = texture color * modulate.
	float t = clamp((restoration - delay) / max(1.0 - delay, 0.001), 0.0, 1.0);
	COLOR.rgb = mix(burn(COLOR.rgb), COLOR.rgb, t);
}
