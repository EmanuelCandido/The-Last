shader_type canvas_item;
// Fundo dos menus: escurece a tela (vindo da esquerda ou por igual) e passa uma neblina devagar.
// Tudo em pontilhado de Bayer no tamanho de pixel da interface, nada de degradê liso.

uniform sampler2D noise : filter_linear, repeat_enable;
// Escuro no lado forte (0..1) e de onde ele vem: 1 = da esquerda, 0 = por igual.
uniform float darkness = 0.7;
uniform float side = 1.0;
// Quanto de neblina clara passa por cima.
uniform float fog = 0.2;
// Tamanho do pixel do pontilhado, em pixels da tela.
uniform float pixel = 2.0;
uniform vec3 shade_color : source_color = vec3(0.02, 0.025, 0.025);
uniform vec3 fog_color : source_color = vec3(0.6, 0.62, 0.6);

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int index = i.x + i.y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[index] + 0.5) / 16.0;
}

// Quantiza em 6 degraus, pontilhando entre eles.
float steps(float value, float threshold) {
	return clamp(floor(value * 6.0 + threshold) / 6.0, 0.0, 1.0);
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / pixel);
	float threshold = bayer4(cell);
	vec2 uv = cell * pixel * SCREEN_PIXEL_SIZE;
	float shade = darkness * mix(1.0, 1.0 - smoothstep(0.05, 0.7, uv.x), side);
	float n1 = texture(noise, uv * vec2(1.3, 0.8) + vec2(TIME * 0.005, TIME * 0.0015)).r;
	float n2 = texture(noise, uv * vec2(2.7, 1.5) - vec2(TIME * 0.009, 0.0)).r;
	float mist = smoothstep(0.42, 0.9, n1 * 0.6 + n2 * 0.4) * fog * (0.6 + 0.4 * uv.y);
	float a_shade = steps(shade, threshold);
	float a_mist = steps(mist, 1.0 - threshold);
	vec3 color = mix(shade_color, fog_color, a_mist / max(a_shade + a_mist, 0.001));
	COLOR = vec4(color, clamp(a_shade + a_mist * (1.0 - a_shade), 0.0, 1.0));
}
