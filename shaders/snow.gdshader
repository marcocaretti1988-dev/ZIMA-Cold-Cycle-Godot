shader_type spatial;
// Neve: colore a chiazze, cristalli che brillano, piccoli rilievi.
uniform vec3 snow_col : source_color = vec3(0.80, 0.84, 0.90);
uniform vec3 shade_col : source_color = vec3(0.52, 0.60, 0.74);
uniform float detail = 1.0;
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float field(vec2 p) {
	return noise(p * 0.33) * 0.55 + noise(p * 1.7) * 0.3 + noise(p * 6.3) * 0.15;
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = field(wpos.xz);
	vec3 col = mix(shade_col, snow_col, smoothstep(0.25, 0.8, n)) * COLOR.rgb;
	ALBEDO = col;
	ROUGHNESS = 0.72;
	SPECULAR = 0.35;
	if (detail > 0.5) {
		float e = 0.09;
		float hx = field(wpos.xz + vec2(e, 0.0)) - field(wpos.xz - vec2(e, 0.0));
		float hz = field(wpos.xz + vec2(0.0, e)) - field(wpos.xz - vec2(0.0, e));
		vec3 nw = normalize(vec3(-hx * 2.2, 1.0, -hz * 2.2));
		NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(nw, 0.0)).xyz, 0.7));
		float sp = step(0.992, hash(floor(wpos.xz * 55.0)));
		EMISSION = vec3(0.55, 0.62, 0.75) * sp * 0.35 * COLOR.r;
	}
}
