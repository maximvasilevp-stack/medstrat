shader_type canvas_item;

// Dark wooden planks for the frame around the map.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = FRAGCOORD.xy;
	float plank = floor(p.y / 96.0);
	float seam = smoothstep(0.0, 3.0, abs(mod(p.y, 96.0) - 1.5));
	float grain = noise(vec2(p.x * 0.015 + plank * 13.0, p.y * 0.3)) * 0.55 + noise(vec2(p.x * 0.004, p.y * 0.06 + plank * 7.0)) * 0.45;
	vec3 col = mix(vec3(0.15, 0.10, 0.06), vec3(0.31, 0.20, 0.11), grain);
	col *= mix(0.55, 1.0, seam);
	COLOR = vec4(col, 1.0);
}
