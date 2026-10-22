shader_type spatial;

// Rocha com projeção triplanar (não precisa de UV) e musgo nas faces viradas para cima.

uniform sampler2D rock_texture : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_texture : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 moss_tint : source_color = vec3(0.75, 0.9, 0.7);
uniform float tile_size = 2.5;
uniform float moss_amount : hint_range(0.0, 1.0) = 0.5;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = world_position / tile_size;
	vec3 n = normalize(world_normal);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 rock = (texture(rock_texture, p.zy).rgb * w.x + texture(rock_texture, p.xz).rgb * w.y + texture(rock_texture, p.xy).rgb * w.z) * tint;
	vec3 moss = texture(moss_texture, p.xz * 1.3).rgb * moss_tint;
	float moss_noise = dot(moss, vec3(0.333)) - 0.25;
	float moss_w = step(0.5, smoothstep(0.45, 0.9, n.y) * moss_amount + moss_noise);
	ALBEDO = mix(rock, moss, moss_w);
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
