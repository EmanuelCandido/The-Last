class_name Memory346
extends Node3D
## A memória do ciclo 346 (§7), que passa ao "carregar" o ciclo_346.sav: a caverna à noite, o
## goblin riscando ACORDA na parede sozinho, o corvo na entrada da caverna virando a cabeça para
## quem olha, um glitch e o fim. Usa a floresta de verdade (a caverna, o goblin, a fogueira):
## o Game guarda o estado antes (SaveSystem.snapshot) e devolve depois, então nada daqui fica.
## A tela passa por memory_glitch.gdshader: desbotada, com grão, e quebrando no fim.

const GLITCH_SHADER := preload("res://assets/shaders/memory_glitch.gdshader")
const SCRATCH_SOUNDS := [preload("res://assets/audio/sfx/wall_scratch_1.wav"), preload("res://assets/audio/sfx/wall_scratch_2.wav")]
const GLITCH_SOUND := preload("res://assets/audio/sfx/glitch.wav")
const WORD := "ACORDA"
## Altura da palavra na parede (local da caverna) e de onde sai o raio que acha a rocha.
const WORD_HEIGHT := 0.58
const RAY_FROM_X := 1.4
## O goblin fica a esta distância da rocha e, de lado, um pouco antes da letra que risca (a mão
## direita fica à direita do corpo).
const STAND_OFF := 0.36
const HAND_SIDE := 0.13
## O corvo pousa na boca da caverna (local da caverna): visto de fora, fica preto contra o salão
## aceso. De perto ele é só caixas, então a câmera fica longe e fecha o zoom.
const CROW_SPOT := Vector3(0.3, 0.0, -5.6)
## A câmera fica nesta distância do corvo, do lado de fora, na linha do fogo para ele.
const CROW_CAMERA_DISTANCE := 5.0
## Intervalo entre dois traços (o mesmo ritmo da ação "scratch" do GoblinAnimator).
const STROKE_SECONDS := 0.6
## Luz de preenchimento quente (a memória é mais clara que a noite de verdade).
const FILL_COLOR := Color(1.0, 0.62, 0.38)
const FILL_ENERGY := 0.9

var _cave: Node3D
var _marks: WallMarks
var _player: Player
var _camera: Camera3D
var _fill: OmniLight3D
var _material: ShaderMaterial
var _layer: CanvasLayer
var _crow: Crow
var _fire := Vector3.ZERO
## A rocha na altura da palavra: o ponto no começo dela, a direção para dentro da parede e a
## direção em que a palavra é escrita.
var _wall := Vector3.ZERO
var _into_wall := Vector3.RIGHT
var _along := Vector3.BACK


## Passa a memória inteira (a tela começa e termina preta).
func play() -> void:
	var level := Game.current_level
	_player = Game.player
	_cave = level.find_child("Cave", true, false) as Node3D
	if _cave == null or _player == null:
		return
	_marks = _cave.find_child("WallMarks", true, false) as WallMarks
	var previous := get_viewport().get_camera_3d()
	_setup_screen()
	_setup_night()
	_find_wall()
	_player.face(_into_wall)
	_place_goblin(0.0)
	_camera = Camera3D.new()
	_camera.top_level = true
	_camera.fov = 55.0
	add_child(_camera)
	_camera.make_current()
	_land_crow()

	Events.screen_fade_requested.emit(0.0, 1.2)
	_player.perform(&"scratch", Tuning.MEMORY_CARVE_SECONDS + Tuning.MEMORY_CROW_SECONDS)
	await _carve_shot(Tuning.MEMORY_CARVE_SECONDS)
	await _crow_shot(Tuning.MEMORY_CROW_SECONDS)
	Events.screen_fade_requested.emit(1.0, 0.0)
	await get_tree().create_timer(0.4, false).timeout

	if _marks != null:
		_marks.carve("")
		_marks.hide_marks(false)
	if is_instance_valid(_crow):
		_crow.queue_free()
	_layer.queue_free()
	if is_instance_valid(previous):
		previous.make_current()


func _setup_screen() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 15
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = GLITCH_SHADER
	var size := get_viewport().get_visible_rect().size
	_material.set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))
	overlay.material = _material
	_layer.add_child(overlay)
	add_child(_layer)


## A noite do ciclo 346: noite fechada, o fogo alto e a parede como era (sem os riscos de agora).
func _setup_night() -> void:
	Clock.hour = Tuning.MEMORY_HOUR
	var campfire := _cave.find_child("Campfire", true, false) as Node3D
	_fire = _cave.global_position
	if campfire != null:
		campfire.load_data({"fuel": Tuning.MEMORY_FUEL})
		_fire = campfire.global_position
	if _marks != null:
		_marks.hide_marks(true)
		_marks.carve(WORD, 0.0)
	_fill = OmniLight3D.new()
	_fill.light_color = FILL_COLOR
	_fill.light_energy = FILL_ENERGY
	_fill.omni_range = 3.2
	add_child(_fill)


## A rocha onde a palavra começa (WallMarks.WORD_START) e para onde ela corre.
func _find_wall() -> void:
	_into_wall = _cave.global_basis.x.normalized()
	_along = _cave.global_basis.z.normalized()
	var from := _cave.to_global(Vector3(RAY_FROM_X, WORD_HEIGHT, WallMarks.WORD_START.x))
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + _into_wall * 4.0, 1))
	_wall = hit.position if not hit.is_empty() else from + _into_wall * 1.8


## Ponto da parede `u` metros depois do começo da palavra.
func _wall_at(u: float) -> Vector3:
	return _wall + _along * u


## O goblin de frente para a rocha, na letra que está riscando (`amount` = quanto da palavra).
func _place_goblin(amount: float) -> void:
	var width := (WORD.length() - 0.5) * WallMarks.LETTER_HEIGHT
	var stand := _wall_at(lerpf(0.1, width, amount) - HAND_SIDE) - _into_wall * STAND_OFF
	var level := Game.current_level
	if level.has_method("ground_height"):
		stand.y = float(level.ground_height(stand.x, stand.z))
	_player.global_position = stand
	_player.velocity = Vector3.ZERO


## O corvo pousa na entrada da caverna já no começo (fora de quadro), olhando o goblin.
func _land_crow() -> void:
	var watchers := Game.current_level.find_child("Watchers", true, false) as Watchers
	if watchers == null:
		return
	var spot := _cave.to_global(CROW_SPOT)
	if Game.current_level.has_method("ground_height"):
		spot.y = float(Game.current_level.ground_height(spot.x, spot.z))
	_crow = watchers.perch_crow(spot, _player, 60.0, true)


## Do lado de onde a palavra já está pronta, um pouco atrás do goblin: ele de costas na direita
## do quadro, as letras aparecendo à esquerda dele, e a câmera chegando perto devagar.
func _carve_shot(seconds: float) -> void:
	var middle := _wall_at(WORD.length() * WallMarks.LETTER_HEIGHT * 0.5) - _into_wall * 0.02
	_fill.global_position = middle - _into_wall * 1.0 + Vector3.UP * 0.5 - _along * 0.6
	var next_scratch := 0.55
	var t := 0.0
	while t < seconds:
		var k := smoothstep(0.0, seconds, t)
		var amount := clampf((t - 0.6) / (seconds - 1.6), 0.0, 1.0)
		_place_goblin(amount)
		var at := middle - _into_wall * lerpf(1.5, 1.15, k) - _along * lerpf(0.75, 0.55, k) + Vector3.UP * lerpf(0.4, 0.3, k)
		at += Vector3(sin(t * 0.7), sin(t * 1.1) * 0.5, cos(t * 0.5)) * 0.012
		_camera.global_position = at
		_camera.look_at(middle + _along * 0.1, Vector3.UP)
		if _marks != null:
			_marks.carve(WORD, amount)
		if t >= next_scratch and amount < 1.0:
			next_scratch += STROKE_SECONDS
			_scratch_sound(amount)
		_material.set_shader_parameter(&"glitch", 0.0)
		await get_tree().process_frame
		t += get_process_delta_time()
	if _marks != null:
		_marks.carve(WORD, 1.0)


## De fora da caverna, baixo: o corvo na boca, preto contra a fogueira e o salão aceso, olhando o
## goblin que risca lá dentro. Ele vira a cabeça para trás e encara a câmera; a tela quebra no fim.
func _crow_shot(seconds: float) -> void:
	var crow_at := _crow.global_position if is_instance_valid(_crow) else _cave.to_global(CROW_SPOT)
	var away := crow_at - _fire
	away.y = 0.0
	var at := crow_at + away.normalized() * CROW_CAMERA_DISTANCE
	var level := Game.current_level
	if level.has_method("ground_height"):
		at.y = maxf(at.y, float(level.ground_height(at.x, at.z)))
	# Na altura do corvo: ele fica na frente das chamas, só o recorte preto.
	at.y = maxf(at.y + 0.12, crow_at.y + 0.05)
	_fill.global_position = crow_at - away.normalized() * 0.8 + Vector3.UP * 0.6
	_fill.light_energy = FILL_ENERGY * 0.5
	var glitch_from := seconds - Tuning.MEMORY_GLITCH_SECONDS
	var glitched := false
	var turned := false
	var t := 0.0
	while t < seconds:
		var k := smoothstep(0.0, seconds, t)
		_camera.global_position = at.lerp(crow_at + Vector3.UP * 0.3, k * 0.2) + Vector3(sin(t * 0.8), 0.0, 0.0) * 0.01
		_camera.look_at(crow_at + Vector3.UP * 0.12, Vector3.UP)
		_camera.fov = lerpf(30.0, 16.0, k)
		if not turned and t > 1.2 and is_instance_valid(_crow):
			turned = true
			_crow.watch = _camera
		var glitch := clampf((t - glitch_from) / Tuning.MEMORY_GLITCH_SECONDS, 0.0, 1.0)
		_material.set_shader_parameter(&"glitch", glitch * glitch)
		if glitch > 0.0 and not glitched:
			glitched = true
			_play(GLITCH_SOUND, -4.0)
		await get_tree().process_frame
		t += get_process_delta_time()


func _scratch_sound(amount: float) -> void:
	var at := _wall_at(amount * WORD.length() * WallMarks.LETTER_HEIGHT) - _into_wall * 0.05
	OccludedAudio.play_at(self, SCRATCH_SOUNDS.pick_random(), at, &"World", -8.0, 2.0, randf_range(0.9, 1.1))


func _play(stream: AudioStream, volume_db: float) -> void:
	var sound := AudioStreamPlayer.new()
	sound.stream = stream
	sound.volume_db = volume_db
	add_child(sound)
	sound.play()
