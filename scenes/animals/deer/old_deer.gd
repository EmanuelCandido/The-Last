class_name OldDeer
extends Deer
## O Velho (§8b-G): um cervo enorme, de pelo escuro e galhada de muitas pontas, que anda sozinho.
## Enxerga, ouve e fareja melhor que os outros, corre mais e aguenta duas flechadas a mais. Do dia
## Tuning.OLD_DEER_FROM_DAY em diante aparece em alguns amanheceres (a floresta sorteia) e vai
## embora no fim da tarde, quando ninguém está olhando. Coletado, dá muita carne e o troféu
## grande da caverna (contador "old_deer_harvested").

const LEAVE_HOUR := 19.0


func _init() -> void:
	super()
	fur_color = Color(0.5, 0.37, 0.26)
	kind = &"old_deer"
	herd = ""
	max_health = 4.0
	meat = 6
	hide = 2
	bones = 3
	sight_range = 30.0
	hearing_range = 23.0
	smell_range = 25.0
	run_speed = 7.3
	calm_distance = 60.0
	home_radius = 30.0
	track_size = Vector2(0.27, 0.33)
	step_volume_db = -9.0
	step_pitch = 0.8


func _ready() -> void:
	super()
	scale = Vector3.ONE * 1.3


## O modelo dele tem a galhada (duas hastes de cinco pontas) e a juba no pescoço.
func _model_scene() -> PackedScene:
	return preload("res://assets/models/animals/old_deer.glb")


func _look_key() -> String:
	return "old_deer"


func _physics_process(delta: float) -> void:
	super(delta)
	# No fim da tarde ele vai embora, se o goblin não está perto para ver.
	if Clock.hour >= LEAVE_HOUR and state != State.DEAD:
		var player := Game.player
		if player == null or player.global_position.distance_to(global_position) > 60.0:
			queue_free()
