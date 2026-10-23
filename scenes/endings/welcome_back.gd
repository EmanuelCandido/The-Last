class_name WelcomeBack
extends Node
## Bem-vindo de volta (§8, depois do Final 3). O Zelador está na cápsula, quente, e um goblin acorda
## na caverna: quem joga é a IA (GoblinAutopilot). Quem abriu o jogo só assiste.
## Depois de um dia de jogo (o goblin dorme e acorda, ou Tuning.WELCOME_MAX_HOURS sem dormir), o
## goblin vai até a parede, os riscos formam OBRIGADO (WallMarks.carve) e ele olha para a câmera.
## No fim o menu volta, agora com "Novo ciclo".
## Filho da fase (Game.start_welcome põe).

const SCRATCH := [preload("res://assets/audio/sfx/wall_scratch_1.wav"), preload("res://assets/audio/sfx/wall_scratch_2.wav")]
const WORD := "OBRIGADO"
const CARVE_SECONDS := 6.0

var _autopilot: GoblinAutopilot
var _hours := 0.0
var _finale := false


func _ready() -> void:
	Clock.skipped.connect(func(hours: float) -> void: _hours += hours)
	Events.woke_up.connect(_on_woke)
	await get_tree().process_frame
	if Game.player == null:
		return
	_autopilot = GoblinAutopilot.new()
	_autopilot.name = "Autopilot"
	Game.player.add_child(_autopilot)


func _process(delta: float) -> void:
	if not Game.resting:
		_hours += delta / 60.0
	if not _finale and _hours >= Tuning.WELCOME_MAX_HOURS:
		_play_finale(0.0)


func _on_woke(reason: StringName) -> void:
	if reason == &"sleep" and not _finale:
		# Espera ele sentar e levantar da pele.
		_play_finale(6.5)


func _play_finale(delay: float) -> void:
	_finale = true
	await _wait(delay)
	var player := Game.player
	var level := Game.current_level
	var marks := level.get_node_or_null(^"Cave/WallMarks") as WallMarks
	if player == null or marks == null:
		return
	if is_instance_valid(_autopilot):
		_autopilot.queue_free()
	player.set_controls_enabled(false)
	Events.screen_fade_requested.emit(1.0, 1.5)
	await _wait(1.8)
	var spot := marks.word_spot(WORD)
	if spot.is_empty():
		Game.back_to_menu()
		return
	var point: Vector3 = spot[0]
	var normal: Vector3 = spot[1]
	normal = Vector3(normal.x, 0.0, normal.z).normalized()
	# O goblin em pé ao lado da palavra, olhando para ela; a câmera de lado, pegando os dois.
	var side := normal.cross(Vector3.UP).normalized()
	var stand := point + normal * 0.7 - side * 1.0
	stand.y = level.ground_height(stand.x, stand.z) + 0.05 if level.has_method("ground_height") else stand.y
	player.global_position = stand
	player.velocity = Vector3.ZERO
	player.face(-normal)
	var camera := Camera3D.new()
	camera.fov = 55.0
	level.add_child(camera)
	camera.look_at_from_position(point + normal * 2.9 + side * 0.6 + Vector3.UP * 0.5, point + normal * 0.35 - side * 0.45 + Vector3.UP * 0.15)
	camera.make_current()
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.72, 0.45)
	fill.light_energy = 0.9
	fill.omni_range = 4.5
	level.add_child(fill)
	fill.global_position = point + normal * 1.6 + Vector3.UP * 1.0
	marks.hide_marks(true)
	marks.carve(WORD, 0.0)
	Events.screen_fade_requested.emit(0.0, 2.0)
	await _wait(1.5)
	# Os riscos viram a palavra, traço a traço, com o som da pedra na rocha.
	var tween := create_tween()
	tween.tween_method(func(amount: float) -> void: marks.carve(WORD, amount), 0.0, 1.0, CARVE_SECONDS)
	for i in 6:
		OccludedAudio.play_at(level, SCRATCH[i % 2], point, &"World", -10.0, 2.0, randf_range(0.9, 1.1))
		await _wait(CARVE_SECONDS / 6.0)
	await _wait(1.5)
	# O goblin vira e olha para a câmera.
	var from := -normal
	var to_camera := camera.global_position - player.global_position
	var turn := create_tween()
	turn.tween_method(func(weight: float) -> void: player.face(from.slerp(Vector3(to_camera.x, 0.0, to_camera.z).normalized(), weight)), 0.0, 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	await _wait(6.0)
	Events.screen_fade_requested.emit(1.0, 3.0)
	Game.close_ears(3.0)
	await _wait(3.5)
	MetaFiles.set_welcome_done()
	Game.back_to_menu()


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, false).timeout
