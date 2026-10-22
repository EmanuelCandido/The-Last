class_name Footsteps
extends AudioStreamPlayer3D
## Toca passos conforme o corpo (pai, CharacterBody3D) anda, com o som do chão
## embaixo dele. Se o pé está numa colisão marcada com o meta `surface` (pedra, tronco),
## vale ela; senão a fase informa o chão por `surface_at(posição) -> StringName`.

## Grama, pedra e madeira são gravações reais (Kenney, CC0); pedra e madeira passaram por um
## passa-baixa, sem clique de sola. Terra é gravação real numa estrada de terra (Freesound,
## CC0); o chão da caverna usa os mesmos passos, mais graves e abafados (terra batida).
const SOUNDS := {
	&"grass": [
		preload("res://assets/audio/real/step_grass_1.ogg"), preload("res://assets/audio/real/step_grass_2.ogg"),
		preload("res://assets/audio/real/step_grass_3.ogg"), preload("res://assets/audio/real/step_grass_4.ogg"),
		preload("res://assets/audio/real/step_grass_5.ogg"),
	],
	&"dirt": [
		preload("res://assets/audio/real/step_dirt_1.ogg"), preload("res://assets/audio/real/step_dirt_2.ogg"),
		preload("res://assets/audio/real/step_dirt_3.ogg"), preload("res://assets/audio/real/step_dirt_4.ogg"),
		preload("res://assets/audio/real/step_dirt_5.ogg"), preload("res://assets/audio/real/step_dirt_6.ogg"),
	],
	&"stone": [
		preload("res://assets/audio/real/step_stone_1.ogg"), preload("res://assets/audio/real/step_stone_2.ogg"),
		preload("res://assets/audio/real/step_stone_3.ogg"), preload("res://assets/audio/real/step_stone_4.ogg"),
		preload("res://assets/audio/real/step_stone_5.ogg"),
	],
	&"cave": [
		preload("res://assets/audio/real/step_cave_1.ogg"), preload("res://assets/audio/real/step_cave_2.ogg"),
		preload("res://assets/audio/real/step_cave_3.ogg"), preload("res://assets/audio/real/step_cave_4.ogg"),
		preload("res://assets/audio/real/step_cave_5.ogg"), preload("res://assets/audio/real/step_cave_6.ogg"),
	],
	&"wood": [
		preload("res://assets/audio/real/step_wood_1.ogg"), preload("res://assets/audio/real/step_wood_2.ogg"),
		preload("res://assets/audio/real/step_wood_3.ogg"), preload("res://assets/audio/real/step_wood_4.ogg"),
		preload("res://assets/audio/real/step_wood_5.ogg"),
	],
}
## Ajuste de volume por chão, para os passos soarem parecidos com os da grama: terra e
## caverna saem ~2,5 dB mais altas.
const SURFACE_DB := {&"dirt": -2.0, &"cave": -2.5, &"stone": -2.0, &"wood": -1.0}

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
	var surface := surface_under()
	var options: Array = SOUNDS.get(surface, SOUNDS[&"grass"])
	stream = options.pick_random()
	pitch_scale = randf_range(0.9, 1.1)
	# Agachado, o goblin pisa devagar e quase não faz barulho.
	var sneaking: bool = _body.has_method("is_crouching") and _body.is_crouching()
	volume_db = base_volume_db + extra_db + float(SURFACE_DB.get(surface, 0.0)) + randf_range(-2.0, 0.0) - (10.0 if sneaking else 0.0)
	play()


## Chão embaixo do corpo: primeiro a colisão em que ele pisa (pedra, tronco), depois o terreno.
func surface_under() -> StringName:
	var from := _body.global_position + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.5, 1, [_body.get_rid()])
	var hit := _body.get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as CollisionObject3D
	if collider != null:
		var shape := collider.shape_owner_get_owner(collider.shape_find_owner(hit.shape)) as Node
		if shape != null and shape.has_meta(&"surface"):
			return shape.get_meta(&"surface")
	var level := Game.current_level
	if level != null and level.has_method("surface_at"):
		return level.surface_at(_body.global_position)
	return &"grass"
