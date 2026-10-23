extends Control
## Menu de pausa: continuar, salvar, carregar, dicas e sair. Só aparece com o jogo pausado.

## Mini tutorial mostrado em "Dicas" (BBCode). As anotações da história (Story.notes)
## entram embaixo, em outra cor.
const TIPS := """[b]CONTROLES[/b]
WASD — andar  ·  Shift — correr  ·  Ctrl — agachar  ·  Espaço — pular
E — pegar, coletar, usar a fogueira, dormir  ·  F — comer  ·  R — fazer flechas (1 madeira = 3 flechas)
Botão direito — mirar com o arco
Botão esquerdo, mirando — segure para puxar a corda, solte para atirar
Botão esquerdo sem mirar — golpear (quebra árvores secas)
Esc — pausar  ·  F3 — desempenho

[b]PRIMEIROS PASSOS[/b]
• O arco e a aljava estão no chão da caverna, ao lado da pele onde você dormiu. Chegue perto e aperte E.
• Começa com 6 flechas. Flechas que erram ficam fincadas: dá para pegar de volta com E.

[b]CAÇADA[/b]
• Os bichos [i]enxergam[/i], [i]ouvem[/i] e [i]farejam[/i]. Correndo, você é ouvido de longe; agachado (Ctrl), quase não faz barulho.
• Eles percebem movimento muito mais que forma parada. Quando um cervo levantar a cabeça e encarar, fique parado até ele voltar a pastar.
• Pastando, de cabeça baixa, o cervo enxerga mal: é a hora de chegar mais perto.
• Fique contra o vento! Se o vento sopra de você para o bicho, ele sente seu cheiro de longe. Veja para onde a grama e as folhas se curvam.
• Capim alto e mata fechada escondem você, ainda mais agachado.
• Segure o clique para puxar a corda toda: a flecha vai mais longe e machuca mais. De longe, mire um pouco acima: a flecha cai.
• Acerte o peito ou o pescoço do cervo. Ferido, ele foge sangrando e mais devagar; siga o rastro de sangue. Coelhos caem com uma flecha.
• Se um cervo da manada foge, os outros fogem junto.
• Chegue perto do bicho abatido e aperte E para coletar carne e couro (e as flechas presas nele).

[b]MADEIRA E FLECHAS[/b]
• Árvores secas, sem folhas, quebram com alguns golpes (botão esquerdo bem perto do tronco). Pinheiros vivos são duros demais.
• Cada árvore seca dá madeira. Aperte R para fazer 3 flechas com 1 madeira.
• Árvore caindo faz muito barulho: os bichos por perto fogem.

[b]FOME, FOGO E SONO[/b]
• O goblin sente fome com o tempo. A barriga ronca quando é hora de comer; se a fome apertar demais, ela começa a machucar.
• Aperte F para comer. Carne crua mata pouco a fome e às vezes faz mal; assada, enche a barriga.
• Na fogueira da caverna (E): ponha madeira para a chama crescer e asse a carne crua. A lenha queima com o tempo, até de noite; sem lenha ficam só as brasas, e brasa não assa nada.
• À noite (ou cansado depois de muito tempo acordado), deite na pele da caverna (E) para dormir até amanhecer. Dormir cura, se a barriga não estiver vazia, e salva o jogo.
• Cair de muito alto machuca. Com a vida baixa, a borda da tela escurece.
• Se o goblin morrer, ele acorda na toca na manhã seguinte, mas perde a carne que levava.

[b]NOITE, FRIO E LOBOS[/b]
• A noite é escura e fria. Fora da toca o goblin esfria, mais ainda no vento; dentro da caverna esfria devagar, e perto do fogo aceso esquenta. Com muito frio ele treme, e no fim o frio machuca.
• De noite os bichos enxergam pior: é mais fácil chegar perto, e mais difícil achar o caminho.
• Depois de alguns dias, os lobos caçam à noite. Um uivo avisa que estão chegando. Eles ouvem, veem e farejam como os cervos, mas vêm atrás de você.
• Lobos têm medo de fogo: perto da fogueira acesa eles não chegam. Com a fogueira apagada, entram na caverna.
• Uma flechada faz o lobo fugir; duas matam, e ele dá couro e carne. Ao amanhecer, a matilha vai embora."""
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


func _on_game_paused(paused: bool) -> void:
	visible = paused
	if paused:
		_status_label.text = ""
		_load_button.disabled = not SaveSystem.has_save()
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
	_panel.visible = not tips_visible
	if tips_visible:
		_back_button.grab_focus()
	else:
		_resume_button.grab_focus()


func _on_save_pressed() -> void:
	if SaveSystem.save_game():
		_status_label.text = "Jogo salvo."
		_load_button.disabled = false
	else:
		_status_label.text = "Falha ao salvar."


func _on_load_pressed() -> void:
	if SaveSystem.load_game():
		Game.set_paused(false)
	else:
		_status_label.text = "Falha ao carregar."
