class_name MudCamouflage
extends Node
## Lama na pele (Vitals.mud, 0..1), §4.11: esconde o goblin (Tuning.MUD_VISIBILITY) e o
## cheiro dele (Tuning.MUD_SCENT). Sai sozinha em Tuning.MUD_SECONDS (um dia), mais rápido
## correndo. A pele escurece pela global de shader `goblin_mud` (goblin_skin.gdshader).
##
## Parte do goblin: um nó filho do Player. Tirar o nó tira a mecânica.

@onready var _player: Player = get_parent()


func _ready() -> void:
	Clock.skipped.connect(func(hours: float) -> void: _wear(hours * Tuning.SECONDS_PER_HOUR))


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(&"goblin_mud", 0.0)


func _process(delta: float) -> void:
	if Game.resting:
		_apply()
		return
	var running := Vector2(_player.velocity.x, _player.velocity.z).length() > _player.walk_speed + 0.5
	_wear(delta * (Tuning.MUD_RUN_FACTOR if running else 1.0))
	_apply()


func _wear(seconds: float) -> void:
	Vitals.mud = maxf(Vitals.mud - seconds / Tuning.MUD_SECONDS, 0.0)


func _apply() -> void:
	var mud := Vitals.mud
	if mud > 0.0:
		_player.visibility_factors[&"mud"] = lerpf(1.0, Tuning.MUD_VISIBILITY, mud)
		_player.scent_factors[&"mud"] = lerpf(1.0, Tuning.MUD_SCENT, mud)
	else:
		_player.visibility_factors.erase(&"mud")
		_player.scent_factors.erase(&"mud")
	RenderingServer.global_shader_parameter_set(&"goblin_mud", mud)
