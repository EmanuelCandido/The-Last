shader_type canvas_item;
// Brilho das Configurações: uma curva de gama sobre a imagem 3D (fica abaixo de toda a interface).
// Mais de 1 clareia as sombras sem estourar o céu; menos de 1 escurece.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float gamma = 1.0;

void fragment() {
	vec3 color = max(texture(screen_texture, SCREEN_UV).rgb, vec3(0.0));
	COLOR = vec4(pow(color, vec3(1.0 / gamma)), 1.0);
}
