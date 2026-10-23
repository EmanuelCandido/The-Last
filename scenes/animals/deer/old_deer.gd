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
	fur_color = Color(0.36, 0.26, 0.18)
	kind = &"old_deer"
	herd = ""
	max_health = 4.0
	meat = 6
	hide = 2
	bones = 3
	sight_range = 55.0
	hearing_range = 42.0
	smell_range = 45.0
	run_speed = 11.0
	calm_distance = 60.0
	home_radius = 30.0
	track_size = Vector2(0.27, 0.33)
	step_volume_db = -9.0
	step_pitch = 0.8


func _ready() -> void:
	super()
	scale = Vector3.ONE * 1.3


func _build_body() -> void:
	super()
	# A galhada: duas hastes grossas abertas, com cinco pontas cada.
	var bone := flat_material(Color(0.7, 0.64, 0.52))
	for side: float in [-1.0, 1.0]:
		var beam := _joint(_head, Vector3(0.07 * side, 0.12, -0.02))
		beam.rotation = Vector3(-0.35, 0.0, -0.6 * side)
		_box(beam, Vector3(0.04, 0.5, 0.04), Vector3(0.0, 0.25, 0.0), bone)
		for t in 5:
			var tine := _box(beam, Vector3(0.025, 0.16, 0.025), Vector3(0.0, 0.1 + t * 0.09, 0.05), bone)
			tine.rotation = Vector3(0.7 + t * 0.08, 0.0, 0.3 * side * (1.0 if t % 2 else -0.5))


func _physics_process(delta: float) -> void:
	super(delta)
	# No fim da tarde ele vai embora, se o goblin não está perto para ver.
	if Clock.hour >= LEAVE_HOUR and state != State.DEAD:
		var player := Game.player
		if player == null or player.global_position.distance_to(global_position) > 60.0:
			queue_free()
