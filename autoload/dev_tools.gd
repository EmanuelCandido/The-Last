extends Node
## Ferramentas de desenvolvimento ativadas por argumentos de linha de comando.
##
## Argumentos (depois de "--"):
##   --frames=<n>         roda n frames (após o aquecimento), imprime um relatório e fecha o jogo
##   --hold=<ações>       mantém ações pressionadas durante os n frames, separadas por vírgula
##                        (ex.: move_forward,sprint)
##   --load               carrega o save antes de apertar as ações
##   --save               salva a partida no fim
##   --pause              pausa o jogo antes do fim
##   --screenshot=<png>   salva um print da tela no fim (precisa de janela, não funciona com --headless)
##   --skip-intro         pula a cena de despertar (o jogador começa de pé e controlável)
##   --teleport=<x>,<z>   coloca o jogador nesse ponto do chão antes de apertar as ações
##   --camera=<yaw>,<pitch>  ângulos da câmera em graus (yaw 0 = olhando para -Z)
##   --give=<item>:<n>,...  põe itens no inventário (ex.: bow:1,arrow:6,wood:2)
##   --press=<ações>      aperta e solta ações uma vez depois das --hold (ex.: interact)
##   --tips               com --pause, abre a tela de Dicas
##   --set=<a.b:v>,...    muda o estado global (ex.: story.act:2,story.flag:moss_fell,
##                        vitals.satiety:10,clock.hour:19); autoloads em SET_TARGETS
##   --run=<script.gd>    roda um roteiro de teste: um RefCounted com `func run() -> void`
##                        (pode usar await); roda depois do aquecimento e antes das --hold
##   --shelter            acorda Ari no Abrigo, já de pé (antes do --run e das --hold)
##   --flash=<n>          começa o flash n (1 a 3) e segue sem esperar ele acabar (para prints)
##   --menu               abre o menu principal (sem argumentos de teste ele já abre sozinho)
##   --welcome            começa o Bem-vindo de volta (o goblin da IA, depois do Final 3)
##
## Exemplo: godot --path . --fixed-fps 60 -- --frames=120 --hold=move_forward --screenshot=C:/temp/print.png
## (--fixed-fps deixa o teste determinístico: 120 frames = 2 segundos de jogo.)

const DEFAULT_FRAMES := 90
## Frames de espera antes de apertar as ações, para a fase carregar e o jogador assentar no chão.
const WARMUP_FRAMES := 10

## Lido pelas fases antes de rodar a introdução.
var skip_intro := false
## Rodando um roteiro de teste (--run): o Final 3 não fecha o jogo.
var scripted := false
## O jogo começa pelo menu principal (sempre, menos nos testes; --menu força).
var show_menu := true


func _ready() -> void:
	var args := _parse_user_args()
	skip_intro = args.has("skip-intro")
	scripted = args.has("run")
	show_menu = args.has("menu") or not (args.has("frames") or args.has("screenshot"))
	if args.has("frames") or args.has("screenshot"):
		_run(args)


func _run(args: Dictionary) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var held: PackedStringArray = []
	if args.has("hold"):
		held = String(args["hold"]).split(",", false)

	for i in WARMUP_FRAMES:
		await get_tree().physics_frame
	if args.has("load"):
		print("[DevTools] Carregar save: %s" % ("ok" if SaveSystem.load_game() else "falhou"))
	if args.has("teleport"):
		_teleport(String(args["teleport"]).split_floats(","))
	if args.has("camera") and Game.player != null:
		var angles := String(args["camera"]).split_floats(",")
		Game.player.set_camera_angles(angles[0], angles[1] if angles.size() > 1 else -15.0)
	if args.has("give"):
		for entry in String(args["give"]).split(",", false):
			var parts := entry.split(":")
			Inventory.add(StringName(parts[0]), int(parts[1]) if parts.size() > 1 else 1)
	if args.has("set"):
		for entry in String(args["set"]).split(",", false):
			_set_value(entry)
	if args.has("welcome"):
		Game.start_welcome()
		await get_tree().physics_frame
	if args.has("shelter"):
		await Game.wake_in_shelter(true)
	if args.has("flash"):
		Events.screen_fade_requested.emit(1.0, 0.0)
		Game.play_flash(int(args["flash"]))
	if args.has("run"):
		var script := load(String(args["run"])) as GDScript
		if script == null:
			push_error("[DevTools] Roteiro não encontrado: %s" % args["run"])
		else:
			await script.new().run()
	for action in held:
		Input.action_press(action)
	if args.has("press"):
		await get_tree().physics_frame
		for action in String(args["press"]).split(",", false):
			_press(action)

	for i in int(args.get("frames", DEFAULT_FRAMES)):
		await get_tree().process_frame

	for action in held:
		Input.action_release(action)
	if args.has("save"):
		print("[DevTools] Salvar: %s" % ("ok" if SaveSystem.save_game() else "falhou"))
	if args.has("pause"):
		Game.set_paused(true)
		if args.has("tips"):
			get_tree().root.find_child("PauseMenu", true, false).show_tips(true)
		# Dá tempo da interface montar o layout antes do print.
		await get_tree().process_frame
		await get_tree().process_frame

	_print_report()
	if args.has("screenshot"):
		await RenderingServer.frame_post_draw
		_save_screenshot(args["screenshot"])
	# Descarrega a cena antes de sair, para os sons pararem e não sobrar nada vivo.
	get_tree().current_scene.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _print_report() -> void:
	print("[DevTools] FPS: %d | draw calls: %d | triângulos: %d" % [
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
	])
	if Game.player != null:
		print("[DevTools] Jogador em %s, chão: %s" % [Game.player.global_position, Game.player.is_on_floor()])
	print("[DevTools] Inventário: %s" % Inventory.items())


## Gera um evento de ação de verdade (aperta e solta), como se fosse uma tecla.
func _press(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().physics_frame


## "story.act:2" -> Story.debug_set("act", "2").
func _set_value(entry: String) -> void:
	var targets := {"story": Story, "clock": Clock, "vitals": Vitals}
	var parts := entry.split(":", true, 1)
	var path := parts[0].split(".", true, 1)
	if parts.size() < 2 or path.size() < 2 or not targets.has(path[0]):
		push_error("[DevTools] --set inválido: %s (use alvo.chave:valor; alvos: %s)" % [entry, ", ".join(targets.keys())])
		return
	targets[path[0]].debug_set(path[1], parts[1])


func _teleport(xz: PackedFloat64Array) -> void:
	var level := Game.current_level
	if Game.player == null or xz.size() < 2:
		return
	var y := 0.0
	if level != null and level.has_method("ground_height"):
		y = level.ground_height(xz[0], xz[1])
	Game.player.global_position = Vector3(xz[0], y + 0.1, xz[1])
	Game.player.velocity = Vector3.ZERO


func _save_screenshot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		push_warning("[DevTools] --screenshot ignorado: sem janela no modo --headless.")
		return
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error == OK:
		print("[DevTools] Print salvo em %s" % ProjectSettings.globalize_path(path))
	else:
		push_error("[DevTools] Falha ao salvar print em %s: %s" % [path, error_string(error)])


func _parse_user_args() -> Dictionary:
	var args := {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	return args
