shader_type canvas_item;
// Look da videocassetta: toni freddi, vignetta, grana, righe, brina da congelamento.
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float frost = 0.0;
uniform float dread = 0.0;
uniform float vhs = 1.0;
uniform float flash = 0.0;
uniform float fade = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	float row = floor(uv.y * 240.0);
	float glitch = step(0.9975 - dread * 0.01, fract(sin(row * 12.7 + floor(t * 13.0) * 3.1) * 43758.5));
	uv.x += glitch * 0.006 * vhs;
	float ca = (0.0011 + dread * 0.0025) * vhs;
	vec3 c;
	c.r = texture(screen, uv + vec2(ca, 0.0)).r;
	c.g = texture(screen, uv).g;
	c.b = texture(screen, uv - vec2(ca, 0.0)).b;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(vec3(l), c, 0.84);
	c *= vec3(0.93, 0.99, 1.09);
	vec2 d = uv - 0.5;
	float v = smoothstep(0.86, 0.22, length(d * vec2(1.0, 1.15)));
	c *= mix(0.42, 1.0, v);
	float g = fract(sin(dot(uv * vec2(1280.0, 720.0) + t * 61.0, vec2(12.9898, 78.233))) * 43758.5453);
	c += (g - 0.5) * 0.055 * vhs;
	c *= 1.0 - 0.035 * vhs * sin(uv.y * 720.0 * 3.14159);
	float fr = frost * smoothstep(0.22, 0.72, length(d) * 1.25 + (g - 0.5) * 0.18);
	c = mix(c, vec3(0.82, 0.90, 1.0), fr * 0.8);
	c += flash;
	c = mix(c, vec3(0.0), fade);
	COLOR = vec4(c, 1.0);
}
