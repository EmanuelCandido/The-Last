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
	sight_range = 22.0
	hearing_range = 14.0
	smell_range = 18.0
	run_speed = 5.5
	calm_distance = 30.0


func _build_body() -> void:
	super()
	# Pelo liso e pálido (a textura de pelo é marrom e escureceria o branco), com um brilho
	# fraco: na neblina ele aparece antes dos outros, e parece errado.
	for node in find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var material := part.material_override as StandardMaterial3D
		if material != null and material.albedo_color == fur_color:
			material.albedo_texture = null
			material.emission_enabled = true
			material.emission = Color(0.85, 0.88, 0.9)
			material.emission_energy_multiplier = 0.25
