class_name WhiteDeer
extends Deer
## O cervo branco (§5, Vigilância ≥ 60): o sedativo do Zelador vestido de caça. Anda sozinho,
## vê, ouve e fareja mal e corre devagar: é fácil demais de caçar. A carne branca enche a
## barriga, mas comer reinicia o ciclo (beat white_meat_recycle).


func _init() -> void:
	super()
	fur_color = Color(0.9, 0.9, 0.86)
	kind = &"white_deer"
	herd = ""
	meat = 2
	meat_item = &"white_meat"
	sight_range = 12.0
	hearing_range = 8.0
	smell_range = 10.0
	run_speed = 3.7
	calm_distance = 30.0


## Pelo pálido por inteiro (sem as manchas do cervo), com um brilho fraco: na neblina ele
## aparece antes dos outros, e parece errado. Olhos claros demais.
func _palette() -> Dictionary:
	var pale := [AnimalLook.PELT, Color(1.08, 1.1, 1.1), 0.18]
	var palette := super()
	for region in ["pelo", "pelo_escuro", "claro"]:
		palette[region] = pale
	palette["interno"] = [AnimalLook.PELT, Color(0.95, 0.85, 0.85), 0.12]
	palette["olho"] = Color(0.55, 0.6, 0.62)
	palette["casco"] = Color(0.5, 0.48, 0.45)
	return palette


func _look_key() -> String:
	return "white_deer"
