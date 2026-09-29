shader_type canvas_item;

// Province id per cell (R8, 0 = water), terrain class per cell (R8), owner palette (256x1 RGBA8),
// and per-province flags (256x1 RGBA8: r = attackable highlight).
uniform sampler2D ids : filter_nearest, repeat_disable;
uniform sampler2D terrain_tex : filter_nearest, repeat_disable;
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform sampler2D flags : filter_nearest, repeat_disable;
uniform ivec2 map_size = ivec2(640, 768);
uniform int hovered_id = 0;
uniform int selected_id = 0;
uniform float owner_mix = 0.55;

const vec3 COL_DEEP = vec3(0.094, 0.204, 0.376);
const vec3 COL_SHALLOW = vec3(0.204, 0.376, 0.580);
const vec3 COL_GRASS = vec3(0.376, 0.549, 0.282);
const vec3 COL_SAND = vec3(0.769, 0.675, 0.439);
const vec3 COL_SNOW = vec3(0.839, 0.863, 0.886);
const vec3 COL_MOUNTAIN = vec3(0.471, 0.439, 0.392);

int id_at(ivec2 c) {
	c = clamp(c, ivec2(0), map_size - ivec2(1));
	return int(texelFetch(ids, c, 0).r * 255.0 + 0.5);
}

void fragment() {
	ivec2 c = ivec2(UV * vec2(map_size));
	c = clamp(c, ivec2(0), map_size - ivec2(1));
	int id = id_at(c);
	int t = int(texelFetch(terrain_tex, c, 0).r * 255.0 + 0.5);
	float checker = float((c.x + c.y) & 1) * 0.035;
	vec3 base;
	if (t == 0) {
		base = COL_DEEP;
	} else if (t == 1) {
		base = COL_SHALLOW;
	} else if (t == 3) {
		base = COL_SAND;
	} else if (t == 4) {
		base = COL_SNOW;
	} else if (t == 5) {
		base = COL_MOUNTAIN;
	} else {
		base = COL_GRASS;
	}
	base += vec3(checker);
	if (t <= 1) {
		// sparse animated glints on the water
		float w = sin(TIME * 1.2 + float(c.x) * 0.9 + float(c.y) * 1.7) * sin(TIME * 0.7 + float(c.y) * 0.5);
		base += vec3(0.10, 0.12, 0.14) * step(0.985, w);
	}
	if (id == 255) {
		// land outside the playable area: muted terrain, no owner
		base = mix(base, vec3(0.42, 0.40, 0.38), 0.5);
	} else if (id > 0) {
		vec4 own = texelFetch(palette, ivec2(id, 0), 0);
		base = mix(base, own.rgb, owner_mix);
		bool border = id_at(c + ivec2(1, 0)) != id || id_at(c - ivec2(1, 0)) != id
			|| id_at(c + ivec2(0, 1)) != id || id_at(c - ivec2(0, 1)) != id;
		if (border) {
			base *= 0.40;
		}
		vec4 fl = texelFetch(flags, ivec2(id, 0), 0);
		if (fl.r > 0.5) {
			base = mix(base, vec3(1.0, 0.85, 0.25), 0.30 + 0.15 * sin(TIME * 6.0));
		}
		if (id == selected_id) {
			base = mix(base, vec3(1.0), 0.30);
		} else if (id == hovered_id) {
			base = mix(base, vec3(1.0), 0.15);
		}
	}
	COLOR = vec4(base, 1.0);
}
