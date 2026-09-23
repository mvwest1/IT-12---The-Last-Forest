// The demo's wind_sway shader (vertex) + the restoration blend (fragment).
// Use this INSTEAD of level/props/wind_sway.tres on grass/ferns/vines/trees,
// otherwise those props keep their green colors while the tiles are burnt.
// Original wind shader: Maujoe (godot-simple-wind-shader-2d), modified by HungryProton.
shader_type canvas_item;
render_mode blend_mix;

global uniform float restoration;

uniform float speed = 1.0;
uniform float minStrength : hint_range(0.0, 1.0) = 0.05;
uniform float maxStrength : hint_range(0.0, 1.0) = 0.01;
uniform float strengthScale = 100.0;
uniform float interval = 3.5;
uniform float detail = 1.0;
uniform float distortion : hint_range(0.0, 1.0);
uniform float heightOffset : hint_range(0.0, 1.0);
uniform float offset = 0;

uniform vec3 burnt_tint : source_color = vec3(0.42, 0.33, 0.28);
uniform float burnt_brightness : hint_range(0.2, 1.0) = 0.6;
uniform float delay : hint_range(0.0, 0.5) = 0.0;
// Burnt plants barely move in the wind (no leaves) — sway grows with restoration.
uniform float burnt_sway : hint_range(0.0, 1.0) = 0.15;

float getWind(vec2 vertex, vec2 uv, float time) {
	float diff = pow(maxStrength - minStrength, 2.0);
	float strength = clamp(minStrength + diff + sin(time / interval) * diff, minStrength, maxStrength) * strengthScale;
	return (sin(time) + cos(time * detail)) * strength * max(0.0, (1.0 - uv.y) - heightOffset);
}

void vertex() {
	float time = TIME * speed + offset;
	VERTEX.x += getWind(VERTEX.xy, UV, time) * mix(burnt_sway, 1.0, clamp(restoration, 0.0, 1.0));
}

vec3 burn(vec3 c) {
	float gray = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(vec3(gray), burnt_tint * gray * 1.8, 0.65) * burnt_brightness;
}

void fragment() {
	float t = clamp((restoration - delay) / max(1.0 - delay, 0.001), 0.0, 1.0);
	COLOR.rgb = mix(burn(COLOR.rgb), COLOR.rgb, t);
}
