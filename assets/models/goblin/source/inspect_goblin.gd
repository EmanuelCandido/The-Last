extends Node
## Inspeção isolada do asset com o Player e os materiais reais do jogo.
## Godot --path . assets/models/goblin/source/inspect_goblin.tscn

const OUT := "res://assets/models/goblin/source/"
var players: Array[Player] = []
var viewports: Array[SubViewport] = []
var cameras: Array[Camera3D] = []
@onready var root: Window = get_tree().root

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1500, 850)
	root.content_scale_size = Vector2i(1500, 850)
	var stage := Control.new()
	root.add_child(stage)
	var headings := ["FRENTE", "VISTA EM 3/4", "COSTAS"]
	for index in 3:
		var container := SubViewportContainer.new()
		container.position = Vector2(index * 500, 0)
		container.size = Vector2(500, 850)
		stage.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(500, 850)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_4X
		container.add_child(viewport)
		viewports.append(viewport)
		var env_node := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.105, 0.125, 0.14)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.77, 0.83, 0.89)
		env.ambient_light_energy = 0.65
		env_node.environment = env
		viewport.add_child(env_node)
		var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
		viewport.add_child(player)
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.get_node("Visual").rotation.y = [0.0, -0.65, PI][index]
		player._camera.current = false
		players.append(player)
		assert(player._skeleton != null)
		assert(player._animator != null, "Rig sem joelhos/cotovelos: o GoblinAnimator não ligou.")
		assert(player._model.find_child("braco_E*mao", true, false) != null)
		for light_spec in [[Vector3(-1.5, 2.4, 2.5), 1.3, Color(1.0, 0.91, 0.78)], [Vector3(1.7, 1.5, -1.8), 1.0, Color(0.68, 0.82, 1.0)]]:
			var light := DirectionalLight3D.new()
			viewport.add_child(light)
			light.position = light_spec[0]
			light.look_at(Vector3(0, 0.5, 0))
			light.light_energy = light_spec[1]
			light.light_color = light_spec[2]
		var camera := Camera3D.new()
		viewport.add_child(camera)
		camera.position = Vector3(0, 0.70, 2.4)
		camera.look_at(Vector3(0, 0.49, 0))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.size = 0.90
		camera.current = true
		cameras.append(camera)
		var label := Label.new()
		label.text = headings[index]
		label.position = Vector2(index * 500 + 25, 22)
		label.add_theme_font_size_override("font_size", 18)
		label.modulate = Color(0.7, 0.77, 0.78)
		stage.add_child(label)
	print("[Goblin QA] Rig, materiais, sockets e animacoes carregados pelo Player.")
	for pose in ["rest", "walk", "aim", "punch"]:
		for camera in cameras:
			camera.size = 0.82 if pose == "rest" else 1.05
		# O Player está desligado: o GoblinAnimator é alimentado e avançado à mão.
		for player in players:
			var animator: GoblinAnimator = player._animator
			animator.velocity_local = Vector3(0.0, 0.0, 2.6) if pose == "walk" else Vector3.ZERO
			animator.aiming = pose == "aim"
			animator.draw = 0.7 if pose == "aim" else 0.0
			if player._bow != null:
				player._bow.visible = false
			if pose == "aim":
				if player._bow == null:
					player._bow = player._attach(BowMesh.build_bow(), "braco_E*mao")
				player._bow.visible = true
			if pose == "punch":
				animator.play_action(&"punch", 0.5)
			for step in (14 if pose == "punch" else 40):
				animator.update(1.0 / 60.0)
		for frame in 4:
			await get_tree().process_frame
		if pose == "aim":
			# Bone attachments have now received the new pose, as in the live controller.
			for player in players:
				player._bow.global_basis = player._visual.global_basis
			await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var path: String = OUT + "godot_" + pose + ".png"
			assert(root.get_texture().get_image().save_png(path) == OK)
			print("[Goblin QA] " + path)
	print("[Goblin QA] PASS: repouso, caminhada, mira com arco e soco.")
	stage.queue_free()
	await get_tree().process_frame
	get_tree().quit()
