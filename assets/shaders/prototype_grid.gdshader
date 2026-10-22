shader_type spatial;

// Grade de protótipo em coordenadas de mundo: dá noção de escala e de
// movimento sem precisar de textura. Use só em blockout.

uniform vec3 base_color : source_color = vec3(0.36, 0.42, 0.36);
uniform vec3 line_color : source_color = vec3(0.27, 0.32, 0.27);
uniform float cell_size : hint_range(0.1, 10.0) = 1.0;
uniform float line_width : hint_range(0.001, 0.5) = 0.03;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	// Projeta a grade no plano dominante da face.
	vec3 n = abs(world_normal);
	vec2 uv;
	if (n.y >= n.x && n.y >= n.z) {
		uv = world_position.xz;
	} else if (n.x >= n.z) {
		uv = world_position.zy;
	} else {
		uv = world_position.xy;
	}
	vec2 dist = abs(fract(uv / cell_size + 0.5) - 0.5) * cell_size;
	float d = min(dist.x, dist.y);
	float aa = fwidth(d);
	float line = 1.0 - smoothstep(line_width - aa, line_width + aa, d);
	ALBEDO = mix(base_color, line_color, line);
	ROUGHNESS = 0.85;
}
