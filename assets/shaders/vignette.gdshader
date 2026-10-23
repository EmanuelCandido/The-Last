shader_type canvas_item;
// Borda escura da tela (vida baixa, fome): fecha dos cantos para o centro com `amount`.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.07, 0.0, 0.0, 1.0);
// Largura / altura da tela, para a borda ser redonda e não oval.
uniform float aspect = 1.7778;

void fragment() {
	// 0 no centro, 1 nos cantos.
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float d = length(p) / length(vec2(aspect, 1.0) * 0.5);
	float edge = smoothstep(0.7 - amount * 0.5, 1.0, d);
	COLOR = vec4(tint.rgb, clamp(edge * (0.55 + 0.45 * amount), 0.0, 0.95));
}
