shader_type spatial;
// Pele, trapo e couro do goblin sem emendas: a textura é projetada dos três lados e
// misturada pela normal, tudo na pose de repouso (posição em UV/UV2, normal em COLOR,
// gravadas pelo GoblinLook). Assim ela não escorrega quando os ossos mexem.

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness = 0.9;
// Metros cobertos por uma repetição da textura.
uniform float texel_span = 0.32;

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
}
