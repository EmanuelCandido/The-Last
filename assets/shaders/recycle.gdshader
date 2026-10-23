shader_type canvas_item;
// A Reciclagem (§3): a imagem vira pixels cada vez maiores, perde a cor e some da borda
// para o centro, bloco por bloco.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float rows = mix(360.0, 18.0, progress * progress);
	vec2 cells = vec2(rows * aspect, rows);
	vec2 cell = floor(SCREEN_UV * cells);
	vec2 uv = (cell + 0.5) / cells;
	vec3 color = texture(screen_texture, uv).rgb;
	color = mix(color, vec3(dot(color, vec3(0.3, 0.59, 0.11))), progress);
	float edge = max(abs(uv.x - 0.5), abs(uv.y - 0.5)) * 2.0;
	float gone = step(1.05 - progress * 1.3 + hash(cell) * 0.3, edge);
	COLOR = vec4(mix(color, vec3(0.0), gone), 1.0);
}
