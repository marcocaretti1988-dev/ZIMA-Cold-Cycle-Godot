shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Impronta di stivale: tacco + suola, bordo chiaro di neve smossa.
varying vec4 inst;
float rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void vertex() { inst = INSTANCE_CUSTOM; }
void fragment() {
	vec2 p = UV - 0.5;
	float sole = rbox(p - vec2(0.0, -0.11), vec2(0.21, 0.27), 0.17);
	float heel = rbox(p - vec2(0.0, 0.33), vec2(0.17, 0.11), 0.09);
	float d = min(sole, heel);
	float inside = smoothstep(0.03, -0.03, d);
	float rim = smoothstep(0.11, 0.03, d) * (1.0 - inside);
	vec3 dark = vec3(0.20, 0.25, 0.36);
	vec3 light = vec3(0.86, 0.90, 0.96);
	ALBEDO = mix(light, dark, inside);
	ROUGHNESS = 0.9;
	ALPHA = (inside * 0.82 + rim * 0.35) * inst.r;
}
