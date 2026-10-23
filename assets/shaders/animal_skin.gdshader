shader_type spatial;
// Pelo, cerda e pena dos bichos, sem emendas: a textura é projetada dos três lados e misturada
// pela normal, tudo na pose de repouso (posição em UV/UV2, normal em COLOR, gravadas pelo
// AnimalLook), como na pele do goblin. Assim ela não escorrega quando os ossos mexem.
// A textura é quase neutra; `tint` dá a cor da região (pelo, barriga clara, focinho...).

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness = 0.95;
// Metros cobertos por uma repetição da textura.
uniform float texel_span = 0.4;
// Brilho fraco (o cervo branco na neblina).
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

varying vec3 rest_position;
varying vec3 rest_normal;

void vertex() {
	rest_position = vec3(UV.x, UV.y, UV2.x);
	rest_normal = COLOR.rgb * 2.0 - 1.0;
}

void fragment() {
	vec3 weights = pow(abs(normalize(rest_normal)), vec3(4.0));
	weights /= weights.x + weights.y + weights.z;
	vec3 p = rest_position / texel_span;
	vec3 color = texture(albedo_texture, vec2(p.z, -p.y)).rgb * weights.x
		+ texture(albedo_texture, vec2(p.x, p.z)).rgb * weights.y
		+ texture(albedo_texture, vec2(p.x, -p.y)).rgb * weights.z;
	ALBEDO = color * tint.rgb;
	ROUGHNESS = roughness;
	EMISSION = emission_color * emission_energy;
}
