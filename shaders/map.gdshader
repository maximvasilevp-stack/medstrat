shader_type canvas_item;

// Soft cartoon map: terrain class per cell (R8), owner per cell (R8, 0 = nobody),
// owner colours in a 256x1 palette. One texel = one map cell.
uniform sampler2D terrain_tex : filter_nearest, repeat_disable;
uniform sampler2D owner_tex : filter_nearest, repeat_disable;
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform ivec2 map_size = ivec2(640, 768);
uniform int human_id = 1;
uniform int hover_owner = 0;

const vec3 C_DEEP = vec3(0.29, 0.54, 0.84);
const vec3 C_SHALLOW = vec3(0.55, 0.745, 0.925);
const vec3 C_GRASS = vec3(0.61, 0.80, 0.48);
const vec3 C_SAND = vec3(0.90, 0.86, 0.69);
const vec3 C_SNOW = vec3(0.93, 0.95, 0.96);
const vec3 C_MOUNTAIN = vec3(0.95, 0.95, 0.95);
const vec3 C_MOUNTAIN_EDGE = vec3(0.78, 0.78, 0.80);
const vec3 C_RIVER = vec3(0.43, 0.67, 0.90);
const vec3 C_LAKE = vec3(0.36, 0.60, 0.86);
const vec3 C_VOID = vec3(0.63, 0.67, 0.59);

int terrain_at(ivec2 c) {
	c = clamp(c, ivec2(0), map_size - 1);
	return int(texelFetch(terrain_tex, c, 0).r * 255.0 + 0.5);
}

int owner_at(ivec2 c) {
	c = clamp(c, ivec2(0), map_size - 1);
	return int(texelFetch(owner_tex, c, 0).r * 255.0 + 0.5);
}

float hash(ivec2 c) {
	return fract(sin(dot(vec2(c), vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	ivec2 c = clamp(ivec2(UV * vec2(map_size)), ivec2(0), map_size - 1);
	int t = terrain_at(c);
	int o = owner_at(c);
	vec3 col;
	if (t == 0) {
		col = C_DEEP;
	} else if (t == 1) {
		col = C_SHALLOW;
	} else if (t == 3) {
		col = C_SAND;
	} else if (t == 4) {
		col = C_SNOW;
	} else if (t == 5) {
		bool edge = terrain_at(c + ivec2(1, 0)) != 5 || terrain_at(c - ivec2(1, 0)) != 5
			|| terrain_at(c + ivec2(0, 1)) != 5 || terrain_at(c - ivec2(0, 1)) != 5;
		col = edge ? C_MOUNTAIN_EDGE : C_MOUNTAIN;
	} else if (t == 6) {
		col = C_RIVER;
	} else if (t == 7) {
		col = C_LAKE;
	} else if (t == 8) {
		col = C_VOID;
	} else {
		col = C_GRASS;
	}
	if (t >= 2 && t <= 6) {
		col += vec3((hash(c) - 0.5) * 0.05);
	}
	if (o > 0) {
		vec3 oc = texelFetch(palette, ivec2(o, 0), 0).rgb;
		col = mix(col, oc, 0.78);
		if (o == human_id && ((c.x + c.y) & 1) == 0) {
			col *= 0.90;
		}
		bool edge = owner_at(c + ivec2(1, 0)) != o || owner_at(c - ivec2(1, 0)) != o
			|| owner_at(c + ivec2(0, 1)) != o || owner_at(c - ivec2(0, 1)) != o;
		if (edge) {
			col *= 0.55;
		}
		if (o == hover_owner) {
			col = mix(col, vec3(1.0), 0.12);
		}
	}
	COLOR = vec4(col, 1.0);
}
