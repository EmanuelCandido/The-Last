extends Control
## Menu de pausa: continuar, salvar, carregar, dicas, menu principal e sair. Só aparece com o jogo
## pausado.
## Do mistério meta (§7): com o ciclo_346.sav no disco, "Carregar" abre a lista de saves; com a
## carta no disco, aparece "Abrir pasta do jogo".

## Mini tutorial mostrado em "Dicas" (BBCode). As anotações da história (Story.notes)
## entram embaixo, em outra cor.
const TIPS := """[b]CONTROLES[/b]
WASD — andar  ·  Shift — correr  ·  Ctrl — agachar  ·  Espaço — pular
E — pegar, coletar, usar a fogueira, dormir  ·  F — comer  ·  R — lista de fabricar
X (segurar) — farejar  ·  Q (segurar) — prender o ar  ·  G — jogar pedra
Botão direito — mirar com o arco
Botão esquerdo, mirando — segure para puxar a corda, solte para atirar
Botão esquerdo sem mirar — golpear (quebra árvores secas)
Esc — pausar  ·  F3 — desempenho

[b]PRIMEIROS PASSOS[/b]
• O arco e a aljava estão no chão da caverna, ao lado da pele onde você dormiu. Chegue perto e aperte E.
• Começa com 6 flechas. Flechas que erram ficam fincadas: dá para pegar de volta com E.

[b]CAÇADA[/b]
• Os bichos [i]enxergam[/i], [i]ouvem[/i] e [i]farejam[/i]. Correndo, você é ouvido de longe; agachado (Ctrl), quase não faz barulho.
• Eles percebem movimento muito mais que forma parada. Leia o corpo do cervo: [i]ergue a cabeça e as orelhas[/i] (algo chamou a atenção), [i]encara[/i] (desconfiado), [i]bate a pata e bufa[/i] (vai fugir). Ao primeiro sinal, pare ou agache.
• Pastando, de cabeça baixa, o cervo enxerga mal: é a hora de chegar mais perto.
• Fique contra o vento! Se o vento sopra de você para o bicho, ele sente seu cheiro de longe. Veja para onde a grama e as folhas se curvam.
• Capim alto e mata fechada escondem você, ainda mais agachado.
• Segure o clique para puxar a corda toda: a flecha vai mais longe e machuca mais. De longe, mire um pouco acima: a flecha cai.
• Acerte o peito ou o pescoço do cervo. Ferido, ele foge sangrando e mais devagar, e a ferida o derruba em menos de um minuto: siga o sangue e as pegadas. Coelhos caem com uma flecha.
• Se um cervo da manada foge, os outros fogem junto.
• Cada manada tem a sua casa. De dia ela anda pelo vale todo, pastando; no fim da tarde volta para casa e dorme lá. Dormindo, os cervos quase não enxergam.
• Prendendo o ar (Q) com a corda puxada, aparece o caminho da flecha.
• Tocaia de galhos (3 madeiras, R): monta aos seus pés. Agachado dentro dela, você quase some.
• Javalis fuçam na mata fechada. De longe, fogem; de perto ou feridos, [i]investem[/i]: saia da frente no último instante.
• Às vezes, depois de alguns dias, um cervo enorme e esperto anda sozinho pelo vale.
• Com a prática o goblin melhora: andar agachado ensina a pisar leve, e acertar flechas firma o braço.
• Chegue perto do bicho abatido e aperte E para coletar carne e couro (e as flechas presas nele).

[b]RASTROS, CHEIRO E SILÊNCIO[/b]
• Cervos, coelhos e lobos deixam pegadas no chão. Elas somem em uns dois minutos: as mais escuras são as mais frescas.
• Segure X para farejar: o goblin agacha, o mundo abafa e o vento aparece. Bicho de onde o vento vem solta uma trilha de cheiro até você. Dura poucos segundos.
• Segure Q para prender o ar: parado, você não faz barulho nenhum e o arco puxado não treme. Não aguenta muito: se passar do limite, solta o ar alto e fica ofegante.
• Depois de correr, o goblin ofega parado, e isso se ouve.
• Esfregue lama numa poça da trilha (E): fica mais difícil de ver e de farejar. A lama sai com o tempo, mais rápido correndo.
• Pegue pedras num monte de pedras soltas (E) e jogue com G para onde a câmera olha. Os bichos fogem do lugar onde a pedra cai, não de você: jogue do outro lado da manada para tocá-la na sua direção.

[b]MADEIRA, PENAS E FABRICAR[/b]
• Árvores secas, sem folhas, quebram com alguns golpes (botão esquerdo bem perto do tronco). Pinheiros vivos são duros demais.
• Cada árvore seca dá madeira. Árvore caindo faz muito barulho: os bichos por perto fogem.
• R abre a lista de fabricar (o tempo não para): escolha com a roda ou as setas e aperte E, ou o número da receita.
• Flechas: 1 madeira. Flechas emplumadas: 1 madeira e 2 penas; caem menos e ferem mais (vão primeiro na corda).
• Corvos abatidos com flecha dão penas.
• Laço (1 couro e 1 madeira): arme sobre pegadas de coelho (E) e volte mais tarde. Às vezes pega um.
• Roupa de couro (3 couros): o frio pega pela metade.
• Tocha (1 madeira): luz e calor por uns minutos, e lobo não chega perto. Mas os bichos veem você de longe. Ao mirar o arco, o goblin finca a tocha no chão.
• A caça dá ossos: flechas de osso (ferem mais), arco de teixo (flecha mais rápida, braço firme) e, com couro, a cama de peles (o sono cura mais e dá menos fome).
• Cada caça coletada deixa um troféu na parede da caverna.

[b]FOME, FOGO E SONO[/b]
• O goblin sente fome com o tempo. A barriga ronca quando é hora de comer; se a fome apertar demais, ela começa a machucar.
• Aperte F para comer. Carne crua mata pouco a fome e às vezes faz mal; assada, enche a barriga.
• Cogumelos ao pé das árvores e frutinhas nos arbustos da borda da mata (E) enganam a fome. Voltam a dar em uns dias.
• A carne estraga: crua em um dia e meio, assada em três. Estragada, quase sempre faz mal.
• Defumador (ao lado da fogueira): pendure a carne crua e mantenha o fogo aceso. Em algumas horas vira carne defumada, que não estraga.
• Na fogueira da caverna (E): ponha madeira para a chama crescer e asse a carne crua. A lenha queima com o tempo, até de noite; sem lenha ficam só as brasas, e brasa não assa nada.
• À noite (ou cansado depois de muito tempo acordado), deite na pele da caverna (E) para dormir até amanhecer. Dormir cura, se a barriga não estiver vazia, e salva o jogo.
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
## Cor das anotações que o próprio Ari deixou.
const NOTES_COLOR := "#d9c27a"

@onready var _panel: Control = %Panel
@onready var _tips: Control = %Tips
@onready var _resume_button: Button = %ResumeButton
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _tips_button: Button = %TipsButton
@onready var _quit_button: Button = %QuitButton
@onready var _back_button: Button = %BackButton
@onready var _status_label: Label = %StatusLabel
@onready var _state_label: Label = %StateLabel
@onready var _tips_text: RichTextLabel = %TipsText

var _folder_button: Button
var _menu_button: Button
var _slots: PanelContainer
var _slot_real: Button
var _slot_old: Button
var _slots_back: Button


func _ready() -> void:
	hide()
	_tips_text.text = TIPS
	Events.game_paused.connect(_on_game_paused)
	_resume_button.pressed.connect(Game.set_paused.bind(false))
	_save_button.pressed.connect(_on_save_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_tips_button.pressed.connect(show_tips.bind(true))
	_back_button.pressed.connect(show_tips.bind(false))
	_quit_button.pressed.connect(Game.quit)
	_folder_button = Button.new()
	_folder_button.name = "FolderButton"
	_folder_button.text = "Abrir pasta do jogo"
	_folder_button.pressed.connect(MetaFiles.open_game_folder)
	_tips_button.add_sibling(_folder_button)
	_menu_button = Button.new()
	_menu_button.name = "MenuButton"
	_menu_button.text = "Menu principal"
	_menu_button.pressed.connect(Game.back_to_menu)
	_quit_button.add_sibling(_menu_button)
	_quit_button.get_parent().move_child(_menu_button, _quit_button.get_index())
	_build_slots()


func _on_game_paused(paused: bool) -> void:
	visible = paused
	if paused:
		_status_label.text = "Acordado, não dá para salvar." if Game.awake else ("Bem-vindo de volta." if Game.welcome else "")
		_save_button.disabled = Game.awake or Game.welcome
		_load_button.disabled = Game.welcome or (not SaveSystem.has_save() and not MetaFiles.has_old_save())
		_folder_button.visible = MetaFiles.has_letter()
		_state_label.text = _state_text()
		_tips_text.text = _tips_with_notes()
		show_tips(false)


## "Dia 4 · fim da tarde · Com fome".
func _state_text() -> String:
	var parts := PackedStringArray(["Dia %d" % Clock.day, Clock.period_name()])
	parts.append_array(Vitals.status_words())
	return " · ".join(parts)


func _tips_with_notes() -> String:
	if Story.notes.is_empty():
		return TIPS
	var lines := PackedStringArray()
	for note in Story.notes:
		lines.append("[i]%s[/i]" % note)
	return TIPS + "\n\n[color=%s][b]ANOTAÇÕES[/b]\n%s[/color]" % [NOTES_COLOR, "\n".join(lines)]


## Mostra a tela de Dicas (true) ou volta ao menu (false).
func show_tips(tips_visible: bool) -> void:
	_tips.visible = tips_visible
	_slots.visible = false
	_panel.visible = not tips_visible
	if tips_visible:
		_back_button.grab_focus()
	else:
		_resume_button.grab_focus()


## Mostra a lista de saves (true) ou volta ao menu (false).
func show_slots(slots_visible: bool) -> void:
	_slots.visible = slots_visible
	_tips.visible = false
	_panel.visible = not slots_visible
	if slots_visible:
		var real := SaveSystem.describe_save()
		_slot_real.text = "save.json  ·  %s" % real if real != "" else "save.json  ·  vazio"
		_slot_real.disabled = real == ""
		_slot_old.visible = MetaFiles.has_old_save()
		_slots_back.grab_focus()
	else:
		_resume_button.grab_focus()


## A lista de "Carregar": o save de verdade e, depois do flash 2, o ciclo_346.sav.
func _build_slots() -> void:
	_slots = PanelContainer.new()
	_slots.name = "Slots"
	_slots.visible = false
	_slots.custom_minimum_size = Vector2(380, 0)
	_panel.add_sibling(_slots)
	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_slots.add_child(margin)
	var items := VBoxContainer.new()
	items.add_theme_constant_override(&"separation", 10)
	margin.add_child(items)
	var title := Label.new()
	title.text = "Carregar"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 28)
	items.add_child(title)
	_slot_real = Button.new()
	_slot_real.pressed.connect(_on_load_real)
	items.add_child(_slot_real)
	_slot_old = Button.new()
	_slot_old.text = "ciclo_346.sav  ·  Dia 12 · Ciclo 346"
	_slot_old.pressed.connect(_on_load_old)
	items.add_child(_slot_old)
	_slots_back = Button.new()
	_slots_back.text = "Voltar"
	_slots_back.pressed.connect(show_slots.bind(false))
	items.add_child(_slots_back)


func _on_save_pressed() -> void:
	if SaveSystem.save_game():
		_status_label.text = "Jogo salvo."
		_load_button.disabled = false
	else:
		_status_label.text = "Falha ao salvar."


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
		_status_label.text = "Falha ao carregar."


## O save do ciclo passado não carrega nada: passa a memória dele e volta para cá.
func _on_load_old() -> void:
	Game.set_paused(false)
	Game.play_memory()
