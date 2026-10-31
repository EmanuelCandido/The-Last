shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;
// Pegada no chão (Tracks): o quad cobre a pegada e o desenho sai daqui, pixelado como as
// texturas do jogo. INSTANCE_CUSTOM: r = espécie (0 cervo, 1 coelho, 2 lobo, 3 bota de orc), g = instante
// em que foi deixada, b = sorteio (cada pegada um pouco diferente).
// A marca é escura (terra úmida amassada) com uma borda clara (terra empurrada para fora),
// para se ler tanto na terra da trilha quanto no capim.

uniform float now = 0.0;
uniform float lifetime = 120.0;
uniform vec3 mud_color : source_color = vec3(0.07, 0.055, 0.04);
uniform vec3 rim_color : source_color = vec3(0.46, 0.39, 0.3);

varying vec3 custom;

void vertex() {
	custom = INSTANCE_CUSTOM.rgb;
	// A malha do terreno e a altura lida pelo código não batem ao centímetro nas encostas:
	// a pegada vem um pouco na direção da câmera para não ficar enterrada.
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz += normalize(-view.xyz) * 0.07;
	POSITION = PROJECTION_MATRIX * view;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Elipse cheia: 1 dentro, 0 fora.
float blob(vec2 p, vec2 center, vec2 radius) {
	vec2 d = (p - center) / radius;
	return step(dot(d, d), 1.0);
}

// Desenho de cada espécie em p (-1..1 no quad; +y é a frente).
float print_shape(vec2 p, float kind) {
	if (kind < 0.5) {
		// Casco fendido: duas metades em gota, pontudas na frente.
		float taper = 1.0 - 0.4 * clamp(p.y, 0.0, 1.0);
		return max(blob(p, vec2(-0.37, -0.05), vec2(0.36 * taper, 0.76)), blob(p, vec2(0.37, -0.05), vec2(0.36 * taper, 0.76)));
	} else if (kind < 1.5) {
		// Coelho: as duas patas de trás compridas na frente, as da frente pequenas atrás, em fila.
		float shape = max(blob(p, vec2(-0.4, 0.32), vec2(0.25, 0.48)), blob(p, vec2(0.4, 0.32), vec2(0.25, 0.48)));
		return max(shape, max(blob(p, vec2(0.0, -0.42), vec2(0.19, 0.17)), blob(p, vec2(0.05, -0.76), vec2(0.19, 0.15))));
	}
	if (kind > 2.5) {
		// Bota de orc: sola comprida e larga na frente, o salto separado atrás e as travas
		// atravessadas (faixas sem marca).
		float sole = blob(p, vec2(0.0, 0.25), vec2(0.62, 0.62));
		float heel = blob(p, vec2(0.0, -0.66), vec2(0.5, 0.3));
		float tread = step(0.5, fract(p.y * 3.5));
		return max(sole * max(tread, step(0.85, abs(p.x) / 0.62)), heel);
	}
	// Lobo: almofada e quatro dedos.
	float shape = blob(p, vec2(0.0, -0.35), vec2(0.42, 0.36));
	shape = max(shape, max(blob(p, vec2(-0.52, 0.15), vec2(0.17, 0.21)), blob(p, vec2(0.52, 0.15), vec2(0.17, 0.21))));
	return max(shape, max(blob(p, vec2(-0.19, 0.55), vec2(0.17, 0.22)), blob(p, vec2(0.19, 0.55), vec2(0.17, 0.22))));
}

void fragment() {
	// 14 "texels" por pegada, como o resto das texturas pixeladas.
	vec2 cell = floor(UV * 14.0);
	vec2 p = (cell + 0.5) / 14.0 * 2.0 - 1.0;
	float mark = print_shape(p, custom.r);
	// A borda: o mesmo desenho um pouco maior, sem o miolo.
	float rim = print_shape(p * 0.8, custom.r) * (1.0 - mark);
	// Bordas esfareladas: alguns texels caem.
	float crumb = hash(cell + custom.b * 37.0);
	mark *= step(0.06, crumb);
	rim *= step(0.45, crumb);
	if (mark + rim < 0.5) {
		discard;
	}
	float age = clamp((now - custom.g) / lifetime, 0.0, 1.0);
	ALBEDO = mark > 0.5 ? mud_color * (0.85 + 0.3 * crumb) : rim_color * (0.9 + 0.2 * crumb);
	ROUGHNESS = 0.95;
	// Fresca, bem marcada; some devagar (o fim é o mais lento: a pegada velha ainda se nota).
	ALPHA = (mark > 0.5 ? 0.85 : 0.45) * (1.0 - age * age);
}
