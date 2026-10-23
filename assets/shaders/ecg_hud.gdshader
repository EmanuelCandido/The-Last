shader_type canvas_item;
// O traçado do coração no canto da tela (HUD vital, §7): o mesmo desenho do monitor do Abrigo
// (ecg.gdshader), escrito da esquerda para a direita no ritmo de `bpm`, apagando atrás do
// cursor. Fundo transparente; `flicker` (0..1) faz a linha falhar, como sinal que vaza.

uniform float bpm = 72.0;
uniform vec4 trace_color : source_color = vec4(0.4, 1.0, 0.6, 1.0);
uniform float window_seconds = 3.0;
uniform vec2 pixels = vec2(120.0, 30.0);
uniform float flicker : hint_range(0.0, 1.0) = 0.0;

float beat(float phase) {
	float p = 0.12 * exp(-pow((phase - 0.12) / 0.03, 2.0));
	float q = -0.12 * exp(-pow((phase - 0.27) / 0.008, 2.0));
	float r = 1.0 * exp(-pow((phase - 0.3) / 0.012, 2.0));
	float s = -0.25 * exp(-pow((phase - 0.33) / 0.01, 2.0));
	float t = 0.25 * exp(-pow((phase - 0.55) / 0.06, 2.0));
	return p + q + r + s + t;
}

float hash(float x) {
	return fract(sin(x * 91.7) * 43758.5453);
}

void fragment() {
	vec2 uv = floor(UV * pixels) / pixels;
	float sweep = fract(TIME / window_seconds);
	float age = fract(sweep - uv.x);
	float when = TIME - age * window_seconds;
	float value = beat(fract(when * bpm / 60.0));
	float next_value = beat(fract((when - window_seconds / pixels.x) * bpm / 60.0));
	float line_y = 0.7 - value * 0.55;
	float on_line = step(abs(uv.y - line_y), 1.5 / pixels.y);
	float uv_value = (0.7 - uv.y) / 0.55;
	on_line = max(on_line, step(min(value, next_value), uv_value) * step(uv_value, max(value, next_value)));
	float fade = 1.0 - smoothstep(0.0, 0.9, age);
	float cursor = step(age, 1.5 / pixels.x);
	// Falhando: pedaços da linha somem por instantes.
	float drop = step(hash(floor(when * 6.0)), flicker * 0.6);
	float alpha = (on_line * (0.2 + 0.8 * fade) + cursor * 0.5) * (1.0 - drop);
	COLOR = vec4(trace_color.rgb, trace_color.a * alpha);
}
