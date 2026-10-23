shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
// Traçado do monitor cardíaco (§6.1): a linha é escrita da esquerda para a direita no ritmo
// de `bpm`, e o que foi escrito há mais tempo apaga. Pixelado como uma tela velha.

uniform float bpm = 72.0;
uniform vec3 trace_color : source_color = vec3(0.35, 1.0, 0.55);
uniform float energy = 2.2;
uniform float window_seconds = 3.0;
uniform vec2 pixels = vec2(96.0, 28.0);

// Um batimento (P, QRS, T) na fase 0..1.
float beat(float phase) {
	float p = 0.12 * exp(-pow((phase - 0.12) / 0.03, 2.0));
	float q = -0.12 * exp(-pow((phase - 0.27) / 0.008, 2.0));
	float r = 1.0 * exp(-pow((phase - 0.3) / 0.012, 2.0));
	float s = -0.25 * exp(-pow((phase - 0.33) / 0.01, 2.0));
	float t = 0.25 * exp(-pow((phase - 0.55) / 0.06, 2.0));
	return p + q + r + s + t;
}

void fragment() {
	vec2 uv = floor(UV * pixels) / pixels;
	float sweep = fract(TIME / window_seconds);
	// O instante que este x mostra: o cursor está em `sweep`; à esquerda dele, a volta atual.
	float age = fract(sweep - uv.x);
	float when = TIME - age * window_seconds;
	float value = beat(fract(when * bpm / 60.0));
	float line_y = 0.62 - value * 0.45;
	float thickness = 1.5 / pixels.y;
	float on_line = step(abs(uv.y - line_y), thickness);
	// Os picos ligam os pontos na vertical (sem isto o QRS vira pontos soltos).
	float next_value = beat(fract((when - window_seconds / pixels.x) * bpm / 60.0));
	float lo = min(value, next_value);
	float hi = max(value, next_value);
	float uv_value = (0.62 - uv.y) / 0.45;
	on_line = max(on_line, step(lo, uv_value) * step(uv_value, hi));
	float fade = 1.0 - smoothstep(0.0, 0.9, age);
	float cursor = step(age, 1.5 / pixels.x);
	vec3 color = trace_color * on_line * (0.25 + 0.75 * fade) + trace_color * cursor * 0.4;
	// Sem luz (unshaded): passar de 1 é o que faz o brilho (glow) pegar na linha.
	ALBEDO = vec3(0.01, 0.025, 0.015) + color * energy;
}
