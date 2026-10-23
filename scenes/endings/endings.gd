class_name Endings
extends Node
## Os três finais (§8), pedidos pela ação de beat "ending" (Events.ending_requested), que os
## comandos do terminal disparam pelo gatilho "choice":
## - "stay" (ficar): "Obrigado." Ari volta para a floresta por escolha própria. Acabam a
##   Vigilância e a Reciclagem (o flag "ending_stay"), a parede ganha a contagem para a frente
##   (Story.forward_marks), os créditos passam sobre a floresta e o jogo segue. O título vira
##   "A Toca — Ninho";
## - "wake" (acordar): a saída blindada sobe, o Zelador segue Ari pelo corredor sem tocar nele e
##   fica na soleira. Lá fora, a escada e a cidade na neblina (Outside); no vidro da ótica, o rosto
##   de Ari. Créditos e o menu principal;
## - "swap" (trocar, o secreto): Ari passa o Zelador para a interface da cápsula. Ele se apaga
##   ("Ah. Ah. Está quente."), o jogo fecha sozinho e abre da próxima vez como "Bem-vindo de volta".
## Filho do Game.

func _ready() -> void:
	Events.ending_requested.connect(play)


func play(ending: StringName) -> void:
	var shelter := Game.shelter
	if shelter == null or shelter.ari == null:
		return
	Game.ending = ending
	print("[Endings] Final: %s." % ending)
	match ending:
		&"stay":
			await _stay(shelter)
		&"wake":
			await _wake(shelter)
		&"swap":
			await _swap(shelter)


func _stay(shelter: Shelter) -> void:
	var ari := shelter.ari
	ari.controls = false
	ari.turn_to(shelter.caretaker.head.global_position, 1.2)
	await _wait(1.4)
	await _wait(shelter.keeper.say(&"thanks") + 0.4)
	await Game.leave_shelter_by_choice()
	MetaFiles.set_title_mode(&"ninho")
	SaveSystem.save_game()
	var credits := Credits.new()
	credits.name = "Credits"
	credits.over_world = true
	Game.add_child(credits)
	await credits.play()
	Game.ending = &""


func _wake(shelter: Shelter) -> void:
	var ari := shelter.ari
	ari.controls = false
	var door := shelter.to_global(Vector3(0.0, 1.6, -3.4))
	ari.turn_to(door, 1.6)
	shelter.open_exit()
	await _wait(1.6)
	await _wait(shelter.keeper.say(&"cold"))
	shelter.keeper.escort()
	await _wait(maxf(Tuning.EXIT_DOOR_SECONDS - 2.0, 0.5))
	if shelter.ari == null:
		return
	ari.controls = true
	var outside := shelter.outside
	outside.start(ari)
	var outside_for := 0.0
	while not outside.reflection_seen and outside_for < Tuning.OUTSIDE_TIMEOUT:
		await get_tree().process_frame
		outside_for += get_process_delta_time()
	ari.controls = false
	Game.close_ears(4.0, -30.0, 2000.0)
	Events.screen_fade_requested.emit(1.0, 3.5)
	await _wait(4.5)
	var credits := Credits.new()
	credits.name = "Credits"
	Game.add_child(credits)
	await credits.play()
	Game.back_to_menu()


func _swap(shelter: Shelter) -> void:
	var ari := shelter.ari
	var keeper := shelter.keeper
	var body := shelter.caretaker
	ari.controls = false
	ari.turn_to(body.head.global_position, 1.0)
	await _wait(1.2)
	await _wait(keeper.say(&"swap_1"))
	# A transferência: o terminal conta, a lente falha e vai se apagando.
	var elapsed := 0.0
	var spoke := false
	while elapsed < Tuning.SWAP_SECONDS:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var done := elapsed / Tuning.SWAP_SECONDS
		shelter.control.show_transfer(done)
		body.set_glow(lerpf(1.0, 0.05, done) * (0.4 if randf() < 0.15 * done else 1.0))
		body.head.rotation.x = lerpf(0.0, 0.55, smoothstep(0.6, 1.0, done))
		if done > 0.55 and not spoke:
			spoke = true
			keeper.say(&"swap_2")
	body.set_glow(0.0)
	body.pose_arm(0, -0.1, 0.1)
	body.pose_arm(1, -0.1, 0.1)
	await _wait(2.5)
	MetaFiles.set_title_mode(&"welcome")
	Game.close_ears(0.4)
	Events.screen_fade_requested.emit(1.0, 0.2)
	await _wait(Tuning.SWAP_BLACK_SECONDS)
	# O jogo fecha sozinho. Da próxima vez, abre como "Bem-vindo de volta".
	Game.quit_after_swap()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
