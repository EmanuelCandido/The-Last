extends Control
## Menu de pausa: continuar, salvar, carregar, dicas, configurações, menu principal e sair. Só
## aparece com o jogo pausado: o painel de rocha à esquerda (UiStyle.rock_panel) com a boca da
## caverna, "PAUSADO", os riscos e o dia, e o jogo parado à direita, sem escurecer.
## Do mistério meta (§7): com o ciclo_346.sav no disco, "Carregar" abre a lista de saves; com a
## carta no disco, aparece "Abrir pasta do jogo". As Dicas abrem no painel largo.

## Mini tutorial mostrado em "Dicas" (BBCode). As teclas são marcadores ({interact}, {eat}...) que
## viram as teclas de agora (Settings.key_labels). As anotações da história (Story.notes) entram
## embaixo, em outra cor.
const TIPS := """[b]CONTROLES[/b]
{move} — andar  ·  {sprint} — correr  ·  {crouch} — agachar  ·  {jump} — pular
{interact} — pegar, coletar, usar a fogueira, dormir  ·  {eat} — comer  ·  {craft} — lista de fabricar
{sniff} (segurar) — farejar  ·  {hold_breath} (segurar) — prender o ar  ·  {throw} — jogar pedra
{aim} — mirar com o arco
{attack}, mirando — segure para puxar a corda, solte para atirar
{attack} sem mirar — golpear (quebra árvores secas)
{pause} — pausar  ·  F3 — desempenho  ·  as teclas mudam em Configurações

[b]PRIMEIROS PASSOS[/b]
• O arco e a aljava estão no chão da caverna, ao lado da pele onde você dormiu. Chegue perto e aperte {interact}.
• Começa com 6 flechas. Flechas que erram ficam fincadas: dá para pegar de volta com {interact}.

[b]CAÇADA[/b]
• Os bichos [i]enxergam[/i], [i]ouvem[/i] e [i]farejam[/i]. Correndo, você é ouvido de longe; agachado ({crouch}), quase não faz barulho.
• Eles percebem movimento muito mais que forma parada. Leia o corpo do cervo: [i]ergue a cabeça e as orelhas[/i] (algo chamou a atenção), [i]encara[/i] (desconfiado), [i]bate a pata e bufa[/i] (vai fugir). Ao primeiro sinal, pare ou agache.
• Pastando, de cabeça baixa, o cervo enxerga mal: é a hora de chegar mais perto.
• Fique contra o vento! Se o vento sopra de você para o bicho, ele sente seu cheiro de longe. Veja para onde a grama e as folhas se curvam.
• Capim alto e mata fechada escondem você, ainda mais agachado.
• Segure o clique para puxar a corda toda: a flecha vai mais longe e machuca mais. De longe, mire um pouco acima: a flecha cai.
• Acerte o peito ou o pescoço do cervo. Ferido, ele foge sangrando e mais devagar, e a ferida o derruba em menos de um minuto: siga o sangue e as pegadas. Coelhos caem com uma flecha.
• Se um cervo da manada foge, os outros fogem junto.
• Cada manada tem a sua casa. De dia ela anda pelo vale todo, pastando; no fim da tarde volta para casa e dorme lá. Dormindo, os cervos quase não enxergam.
• Prendendo o ar ({hold_breath}) com a corda puxada, aparece o caminho da flecha.
• Tocaia de galhos (3 madeiras, {craft}): monta aos seus pés. Agachado dentro dela, você quase some.
• Javalis fuçam na mata fechada. De longe, fogem; de perto ou feridos, [i]investem[/i]: saia da frente no último instante.
• Às vezes, depois de alguns dias, um cervo enorme e esperto anda sozinho pelo vale.
• Com a prática o goblin melhora: andar agachado ensina a pisar leve, e acertar flechas firma o braço.
• Chegue perto do bicho abatido e aperte {interact} para coletar carne e couro (e as flechas presas nele).

[b]RASTROS, CHEIRO E SILÊNCIO[/b]
• Cervos, coelhos e lobos deixam pegadas no chão. Elas somem em uns dois minutos: as mais escuras são as mais frescas.
• Segure {sniff} para farejar: o goblin agacha, o mundo abafa e o vento aparece. Bicho de onde o vento vem solta uma trilha de cheiro até você. Dura poucos segundos.
• Segure {hold_breath} para prender o ar: parado, você não faz barulho nenhum e o arco puxado não treme. Não aguenta muito: se passar do limite, solta o ar alto e fica ofegante.
• Depois de correr, o goblin ofega parado, e isso se ouve.
• Esfregue lama numa poça da trilha ({interact}): fica mais difícil de ver e de farejar. A lama sai com o tempo, mais rápido correndo.
• Pegue pedras num monte de pedras soltas ({interact}) e jogue com {throw} para onde a câmera olha. Os bichos fogem do lugar onde a pedra cai, não de você: jogue do outro lado da manada para tocá-la na sua direção.

[b]MADEIRA, PENAS E FABRICAR[/b]
• Árvores secas, sem folhas, quebram com alguns golpes (botão esquerdo bem perto do tronco). Pinheiros vivos são duros demais.
• Cada árvore seca dá madeira. Árvore caindo faz muito barulho: os bichos por perto fogem.
• {craft} abre a lista de fabricar (o tempo não para): escolha com a roda ou as setas e aperte {interact}, ou o número da receita.
• Flechas: 1 madeira. Flechas emplumadas: 1 madeira e 2 penas; caem menos e ferem mais (vão primeiro na corda).
• Corvos abatidos com flecha dão penas.
• Laço (1 couro e 1 madeira): arme sobre pegadas de coelho ({interact}) e volte mais tarde. Às vezes pega um.
• Roupa de couro (3 couros): o frio pega pela metade.
• Tocha (1 madeira): luz e calor por uns minutos, e lobo não chega perto. Mas os bichos veem você de longe. Ao mirar o arco, o goblin finca a tocha no chão.
• A caça dá ossos: flechas de osso (ferem mais), arco de teixo (flecha mais rápida, braço firme) e, com couro, a cama de peles (o sono cura mais e dá menos fome).
• Cada caça coletada deixa um troféu na parede da caverna.

[b]NA NEBLINA[/b]
• Com a fogueira da toca acesa, a fumaça sai pela boca da caverna e sobe acima das árvores: de longe, ela mostra onde fica a toca.
• Marco de pedras (3 pedras, {craft}): uma torre de pedras na sua frente, que aparece de longe na neblina.
• Perto de um pinheiro vivo, {interact} risca o tronco com as garras: a casca raspada fica clara dos dois lados. Riscando árvores pelo caminho, dá para voltar pela mesma trilha.
• Na ruína, um sino velho bate quando o vento é forte. Dá para se guiar pelo som.

[b]FOME, FOGO E SONO[/b]
• O goblin sente fome com o tempo. A barriga ronca quando é hora de comer; se a fome apertar demais, ela começa a machucar.
• Aperte {eat} para comer. Carne crua mata pouco a fome e às vezes faz mal; assada, enche a barriga.
• Cogumelos ao pé das árvores e frutinhas nos arbustos da borda da mata ({interact}) enganam a fome. Voltam a dar em uns dias.
• A carne estraga: crua em um dia e meio, assada em três. Estragada, quase sempre faz mal.
• Defumador (ao lado da fogueira): pendure a carne crua e mantenha o fogo aceso. Em algumas horas vira carne defumada, que não estraga.
• Na fogueira da caverna ({interact}): ponha madeira para a chama crescer e asse a carne crua. A lenha queima com o tempo, até de noite; sem lenha ficam só as brasas, e brasa não assa nada.
• À noite (ou cansado depois de muito tempo acordado), deite na pele da caverna ({interact}) para dormir até amanhecer. Dormir cura, se a barriga não estiver vazia, e salva o jogo.
• Cair de muito alto machuca. Com a vida baixa, a borda da tela escurece.
• Se o goblin morrer, ele acorda na toca na manhã seguinte, mas perde a carne que levava.

[b]NOITE, FRIO E LOBOS[/b]
• A noite é escura e fria. Fora da toca o goblin esfria, mais ainda no vento; dentro da caverna esfria devagar, e perto do fogo aceso esquenta. Com muito frio ele treme, e no fim o frio machuca.
• De noite os bichos enxergam pior: é mais fácil chegar perto, e mais difícil achar o caminho.
• Depois de alguns dias, os lobos caçam à noite. Um uivo avisa que estão chegando. Eles ouvem, veem e farejam como os cervos, mas vêm atrás de você.
• Lobos têm medo de fogo: perto da fogueira acesa eles não chegam. Com a fogueira apagada, entram na caverna.
• Uma flechada faz o lobo fugir; duas matam, e ele dá couro e carne. Ao amanhecer, a matilha vai embora.

[b]CHUVA[/b]
• Às vezes chove. A chuva abafa seus passos e lava o seu cheiro: é um bom tempo para caçar. Mas molha, e molhado o goblin esfria, até de dia. Debaixo das árvores e na toca ela não pega.
• Na chuva as manadas se abrigam debaixo das árvores mais fechadas e ficam paradas."""

## Segundos que um aviso ("Jogo salvo.") fica no lugar do dia.
const STATUS_SECONDS := 3.0

var _rock: Control
var _panel: Control
var _state_label: Label
var _items: VBoxContainer
var _resume_button: Button
var _save_button: Button
var _load_button: Button
var _folder_button: Button
var _settings_button: Button
var _settings: SettingsMenu
var _tips: Control
var _tips_text: RichTextLabel
var _back_button: Button
var _slots: VBoxContainer
var _slot_real: Button
var _slot_old: Button
var _slots_back: Button
## A pergunta antes de sair sem salvar (F10), no lugar dos itens, e o que fazer se confirmar.
var _leave: VBoxContainer
var _leave_text: Label
var _leave_save: Button
var _leave_back: Button
var _leave_action := Callable()
## Aviso que está no lugar do dia, e até quando (Time.get_ticks_msec; 0 = enquanto pausado).
var _status := ""
var _status_until := 0


func _ready() -> void:
	hide()
	_build()
	Events.game_paused.connect(_on_game_paused)


func _process(_delta: float) -> void:
	if _status_until > 0 and Time.get_ticks_msec() >= _status_until:
		_status = ""
		_status_until = 0
		_state_label.text = _state_text()


func _on_game_paused(paused: bool) -> void:
	visible = paused
	if not paused and _settings != null:
		_settings.queue_free()
		_settings = null
	if paused:
		_status = "Acordado, não dá para salvar." if Game.awake else ("Bem-vindo de volta." if Game.welcome else "")
		_status_until = 0
		_save_button.disabled = Game.awake or Game.welcome
		_load_button.disabled = Game.welcome or (not SaveSystem.has_save() and not MetaFiles.has_old_save())
		_folder_button.visible = MetaFiles.has_letter()
		_state_label.text = _state_text()
		_tips_text.text = _tips_with_notes()
		# A tecla do rodapé segue o aparelho em uso (Esc no teclado, Menu no controle).
		for footer: Node in [_panel.get_node_or_null(^"Footer/Text"), _tips.get_node_or_null(^"Footer/Text")]:
			if footer is Label:
				(footer as Label).text = "[%s] Voltar ao jogo" % Settings.key_label(&"pause", true)
		show_tips(false)


## "Dia 4 · tarde · Com fome", ou o aviso da hora ("Jogo salvo.").
func _state_text() -> String:
	if _status != "":
		return _status
	var parts := PackedStringArray(["Dia %d" % Clock.day, Clock.period_name()])
	parts.append_array(Vitals.status_words())
	return " · ".join(parts)


func _show_status(text: String) -> void:
	_status = text
	_status_until = Time.get_ticks_msec() + int(STATUS_SECONDS * 1000.0)
	_state_label.text = text


## As Dicas com as teclas de agora (Settings), os títulos em ocre e as anotações de Ari no fim.
func _tips_with_notes() -> String:
	var text := TIPS.format(Settings.key_labels())
	text = text.replace("[b]", "[color=%s][b]" % UiStyle.hex(UiStyle.ACCENT)).replace("[/b]", "[/b][/color]")
	if Story.notes.is_empty():
		return text
	var lines := PackedStringArray()
	for note in Story.notes:
		lines.append("[i]%s[/i]" % note)
	return text + "\n\n[color=%s][b]ANOTAÇÕES[/b]\n%s[/color]" % [UiStyle.hex(UiStyle.MOSS), "\n".join(lines)]


## Mostra a tela de Dicas (true) ou volta ao menu (false).
func show_tips(tips_visible: bool) -> void:
	_tips.visible = tips_visible
	_rock.visible = not tips_visible
	_panel.visible = not tips_visible
	_show_items(true)
	if tips_visible:
		_back_button.grab_focus()
	else:
		_resume_button.grab_focus()


## Abre as Configurações por cima (o painel some até elas fecharem).
func open_settings() -> void:
	if _settings != null:
		return
	_settings = SettingsMenu.new()
	_settings.name = "Settings"
	_panel.visible = false
	_settings.closed.connect(func() -> void:
		_settings = null
		_panel.visible = true
		_settings_button.grab_focus())
	add_child(_settings)


## Mostra a lista de saves (true) ou volta ao menu (false), no lugar dos itens.
func show_slots(slots_visible: bool) -> void:
	_show_items(not slots_visible)
	if slots_visible:
		var real := SaveSystem.describe_save()
		_slot_real.text = real if real != "" else "Nenhum jogo salvo"
		_slot_real.disabled = real == ""
		_slot_old.visible = MetaFiles.has_old_save()
		_slots_back.grab_focus()
	else:
		_load_button.grab_focus()


func _show_items(items_visible: bool) -> void:
	_items.visible = items_visible
	_slots.visible = not items_visible
	if _leave != null:
		_leave.visible = false


## Sair (para o menu ou do jogo): se o que foi feito desde o último salvar se perderia, pergunta
## antes, no lugar dos itens; senão sai direto. O X da janela também passa por aqui (Game).
func ask_leave(action: Callable) -> void:
	if not SaveSystem.can_lose_progress():
		action.call()
		return
	_leave_action = action
	var minutes := maxi(1, roundi(SaveSystem.unsaved_seconds() / 60.0))
	if Game.awake:
		_leave_text.text = "Acordado não dá para salvar.\nO que você fez desde que salvou\n(há %d min) se perde." % minutes
	else:
		_leave_text.text = "O que você fez desde que salvou\n(há %d min) se perde." % minutes
	_leave_save.visible = not Game.awake
	show_tips(false)
	_items.visible = false
	_slots.visible = false
	_leave.visible = true
	(_leave_save if _leave_save.visible else _leave_back).grab_focus()


func _build_leave() -> void:
	_leave = _column()
	_leave.visible = false
	_leave.add_theme_constant_override(&"separation", 0)
	_leave_text = UiStyle.label("")
	_leave_text.add_theme_color_override(&"font_color", UiStyle.BLOOD.lightened(0.25))
	_leave.add_child(_leave_text)
	_leave_save = _menu_item(_leave, "Salvar e sair", func() -> void:
		if SaveSystem.save_game():
			_leave_now())
	_menu_item(_leave, "Sair sem salvar", _leave_now)
	_leave_back = _menu_item(_leave, "Voltar", func() -> void:
		_show_items(true)
		_resume_button.grab_focus())


func _leave_now() -> void:
	var action := _leave_action
	_leave_action = Callable()
	_show_items(true)
	if action.is_valid():
		action.call()


func _build() -> void:
	_rock = UiStyle.rock_panel(&"pause")
	add_child(_rock)
	_panel = _layer("Panel")
	var header := VBoxContainer.new()
	header.add_theme_constant_override(&"separation", -6)
	header.position = Vector2(79.0, 132.0)
	_panel.add_child(header)
	header.add_child(UiStyle.sprite(UiStyle.CAVE_ICON, 3))
	header.add_child(UiStyle.menu_title("Pausado"))
	var tally := UiStyle.tally_line(" ")
	_state_label = tally.get_node("Text")
	header.add_child(tally)
	_items = _column()
	_resume_button = _menu_item(_items, "Continuar", Game.set_paused.bind(false))
	_save_button = _menu_item(_items, "Salvar", _on_save_pressed)
	_load_button = _menu_item(_items, "Carregar", _on_load_pressed)
	_menu_item(_items, "Dicas", show_tips.bind(true))
	_folder_button = _menu_item(_items, "Abrir pasta do jogo", MetaFiles.open_game_folder)
	_settings_button = _menu_item(_items, "Configurações", open_settings)
	_menu_item(_items, "Menu principal", ask_leave.bind(Game.back_to_menu))
	_menu_item(_items, "Sair do jogo", ask_leave.bind(Game.quit))
	_build_slots()
	_build_leave()
	UiStyle.footer(_panel, "[%s] Voltar ao jogo" % Settings.key_label(&"pause", true))
	_build_tips()


## A lista de "Carregar": o save de verdade ("Dia 4 · Ciclo 347") e, depois do flash 2, o
## ciclo_346.sav.
func _build_slots() -> void:
	_slots = _column()
	_slots.visible = false
	_slot_real = _menu_item(_slots, "", _on_load_real)
	_slot_old = _menu_item(_slots, "ciclo_346.sav", _on_load_old)
	_slots_back = _menu_item(_slots, "Voltar", show_slots.bind(false))


## As Dicas: o painel largo de rocha, o título, o texto rolando e o "Voltar".
func _build_tips() -> void:
	_tips = _layer("Tips")
	_tips.visible = false
	_tips.add_child(UiStyle.rock_panel(&"wide"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	box.position = Vector2(79.0, 52.0)
	_tips.add_child(box)
	box.add_child(UiStyle.menu_title("Dicas"))
	box.add_child(UiStyle.tally_line())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(800.0, 380.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_tips_text = RichTextLabel.new()
	_tips_text.bbcode_enabled = true
	_tips_text.fit_content = true
	_tips_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tips_text)
	# O "Voltar" alinhado com os itens dos menus (o marcador cabe à esquerda dele).
	var back_row := MarginContainer.new()
	back_row.add_theme_constant_override(&"margin_left", int(UiStyle.MENU_LEFT - box.position.x))
	box.add_child(back_row)
	_back_button = UiStyle.menu_button("Voltar", show_tips.bind(false))
	_back_button.custom_minimum_size.x = 300.0
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_row.add_child(_back_button)
	UiStyle.footer(_tips, "[%s] Voltar ao jogo" % Settings.key_label(&"pause", true))


## Uma camada da tela inteira que não pega o mouse.
func _layer(node_name: String) -> Control:
	var layer := Control.new()
	layer.name = node_name
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer


## A coluna dos itens. A linha da fonte é alta (a fonte de reserva do sistema entra na conta):
## a separação negativa deixa um item de 32 a cada 41 px.
func _column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", -12)
	column.position = Vector2(UiStyle.MENU_LEFT, 318.0)
	_panel.add_child(column)
	return column


func _menu_item(parent: Container, text: String, action: Callable, font_size := 32) -> Button:
	var button := UiStyle.menu_button(text, action, font_size)
	button.custom_minimum_size.x = 300.0
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(button)
	return button


func _on_save_pressed() -> void:
	if SaveSystem.save_game():
		_show_status("Jogo salvo.")
		_load_button.disabled = false
	else:
		_show_status("Falha ao salvar.")


func _on_load_pressed() -> void:
	if MetaFiles.has_old_save():
		show_slots(true)
	else:
		_on_load_real()


func _on_load_real() -> void:
	if SaveSystem.load_game():
		Game.set_paused(false)
	else:
		show_slots(false)
		_show_status("Falha ao carregar.")


## O save do ciclo passado não carrega nada: passa a memória dele e volta para cá.
func _on_load_old() -> void:
	Game.set_paused(false)
	Game.play_memory()
