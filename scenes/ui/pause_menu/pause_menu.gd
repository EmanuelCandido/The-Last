extends Control
## Menu de pausa: continuar, salvar, carregar, dicas e sair. Só aparece com o jogo pausado.

## Mini tutorial mostrado em "Dicas" (BBCode).
const TIPS := """[b]CONTROLES[/b]
WASD — andar  ·  Shift — correr  ·  Ctrl — agachar  ·  Espaço — pular
E — pegar e coletar  ·  R — fazer flechas (1 madeira = 3 flechas)
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
• Árvore caindo faz muito barulho: os bichos por perto fogem."""

@onready var _panel: Control = %Panel
@onready var _tips: Control = %Tips
@onready var _resume_button: Button = %ResumeButton
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _tips_button: Button = %TipsButton
@onready var _quit_button: Button = %QuitButton
@onready var _back_button: Button = %BackButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	hide()
	(%TipsText as RichTextLabel).text = TIPS
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
		show_tips(false)


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
