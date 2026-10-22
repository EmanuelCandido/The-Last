class_name Footsteps
extends AudioStreamPlayer3D
## Toca passos conforme o corpo (pai, CharacterBody3D) anda, com o som do chão
## embaixo dele. A fase informa o chão por `surface_at(posição) -> StringName`.

## Gravações reais (Kenney, CC0): grama, terra batida e pedra.
const SOUNDS := {
	&"grass": [
		preload("res://assets/audio/real/step_grass_1.ogg"), preload("res://assets/audio/real/step_grass_2.ogg"),
		preload("res://assets/audio/real/step_grass_3.ogg"), preload("res://assets/audio/real/step_grass_4.ogg"),
		preload("res://assets/audio/real/step_grass_5.ogg"),
	],
	&"dirt": [
		preload("res://assets/audio/real/step_dirt_1.ogg"), preload("res://assets/audio/real/step_dirt_2.ogg"),
		preload("res://assets/audio/real/step_dirt_3.ogg"), preload("res://assets/audio/real/step_dirt_4.ogg"),
		preload("res://assets/audio/real/step_dirt_5.ogg"),
	],
	&"stone": [
		preload("res://assets/audio/real/step_stone_1.ogg"), preload("res://assets/audio/real/step_stone_2.ogg"),
		preload("res://assets/audio/real/step_stone_3.ogg"), preload("res://assets/audio/real/step_stone_4.ogg"),
		preload("res://assets/audio/real/step_stone_5.ogg"),
	],
}

## Distância andada entre um passo e outro (metros).
@export var stride := 0.65
@export var base_volume_db := -8.0
## true quando quem anima o corpo chama play_step() no instante em que o pé toca o chão;
## aí a contagem por distância fica desligada (só a aterrissagem continua aqui).
@export var driven_by_animation := false

var _distance := 0.0
var _was_on_floor := true

@onready var _body := get_parent() as CharacterBody3D


func _physics_process(delta: float) -> void:
	var on_floor := _body.is_on_floor()
	var horizontal := Vector2(_body.velocity.x, _body.velocity.z).length()
	if on_floor and horizontal > 0.3 and not driven_by_animation:
		_distance += horizontal * delta
		# Correndo, a passada fica mais longa.
		if _distance >= stride * (1.0 + 0.4 * clampf((horizontal - 3.5) / 3.0, 0.0, 1.0)):
			_distance = 0.0
			play_step()
	if on_floor and not _was_on_floor:
		play_step(5.0)
	_was_on_floor = on_floor


func play_step(extra_db := 0.0) -> void:
	var surface := &"grass"
	var level := Game.current_level
	if level != null and level.has_method("surface_at"):
		surface = level.surface_at(_body.global_position)
	var options: Array = SOUNDS.get(surface, SOUNDS[&"grass"])
	stream = options.pick_random()
	pitch_scale = randf_range(0.9, 1.1)
	# Agachado, o goblin pisa devagar e quase não faz barulho.
	var sneaking: bool = _body.has_method("is_crouching") and _body.is_crouching()
	volume_db = base_volume_db + extra_db + randf_range(-2.0, 0.0) - (10.0 if sneaking else 0.0)
	play()
