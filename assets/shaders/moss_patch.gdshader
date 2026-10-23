shader_type spatial;
render_mode cull_disabled;

// Mancha de musgo colada na parede: a borda é roída por ruído em degraus de pixel (não é
// um retângulo) e a cor é a do musgo das rochas. UV = textura; UV2 = posição na mancha (0..1).

uniform sampler2D moss_texture : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D edge_noise : filter_linear, repeat_enable;
uniform vec3 moss_tint : source_color = vec3(0.78, 1.0, 0.5);
// Pixels da borda ao longo da mancha (degraus do recorte).
uniform float edge_pixels = 56.0;
// Quanto o ruído come da borda.
uniform float edge_bite = 0.55;

void fragment() {
	vec2 cell = floor(UV2 * edge_pixels) / edge_pixels;
	// Superelipse: quase retângulo no meio, cantos arredondados.
	vec2 q = abs(cell * 2.0 - 1.0);
	float d = pow(pow(q.x, 3.0) + pow(q.y, 3.0), 1.0 / 3.0);
	float n = texture(edge_noise, cell * vec2(1.7, 1.1)).r;
	float limit = 0.95 - edge_bite * n;
	if (d > limit) {
		discard;
	}
	// A textura do chão da floresta é marrom: puxa o verde dela para virar musgo.
	vec3 ground = texture(moss_texture, UV).rgb;
	float light = dot(ground, vec3(0.333));
	vec3 moss = mix(ground, vec3(light * 0.75, light * 1.05, light * 0.45), 0.7) * moss_tint * 1.25;
	// Mais ralo e escuro perto da borda, onde aparece a rocha por baixo.
	float thick = smoothstep(0.0, 0.18, limit - d);
	ALBEDO = moss * mix(0.55, 1.0, thick);
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
