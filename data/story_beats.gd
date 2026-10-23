class_name StoryBeats
extends RefCounted
## Acontecimentos da história, como dados (ver docs/plano.md, §3 e §9).
##
## Cada beat é avaliado quando o gatilho `on` acontece e dispara uma vez só, se as
## condições de `when` valerem ("repeat": true = dispara toda vez). Para mudar a
## história, edite esta lista; o Story só a interpreta, e os sistemas reagem aos flags
## (o musgo cai quando "moss_fell" liga; o cervo trava quando "clue_deer_freeze" liga).
##
## Gatilhos (`on`): "start", "slept", "woke", "died", "harvested", "ate", "ritual".
## Condições (`when`, todas precisam valer):
##   "act": n, "act_at_least": n, "marks_at_least": n, "flag": nome, "not_flag": nome,
##   "counter_at_least": {nome: n}, "reason": motivo do gatilho (ex.: "sleep"),
##   "any": [condições, ...] (basta uma valer).
##   Contadores automáticos: "<bicho>_harvested", "<receita>_crafted", "sleeps_act_<n>".
## Ações (`do`, em ordem):
##   {"set_flag": nome}, {"clear_flag": nome}, {"set_act": n}, {"add_note": texto},
##   {"notify": texto}, {"flash": n} (F5 mostra), {"recycle": motivo}, {"vigilance": n}.

## Código da porta da ruína: a pintura do teto (2 cervos, 7 corvos, 1 lobo, 4 coelhos).
const DOOR_CODE := "2714"
## A porta só aceita o código com este flag (Ari viu a ruína pela janela, no flash 3).
const DOOR_FLAG := &"saw_ruin_window"

const BEATS: Array[Dictionary] = [
	# --- Ato I: pistas que parecem bug ou estilo (o sistema é o Clues, na floresta) ----
	{
		# O primeiro cervo visível perto trava 0,4 s no meio do passo, e o som some junto.
		"id": "clue_deer_freeze",
		"on": "woke",
		"when": {"act": 1, "marks_at_least": 2},
		"do": [{"set_flag": "clue_deer_freeze"}],
	},
	{
		# Um corvo pousa perto e segue o goblin com a cabeça, sem crocitar.
		"id": "clue_crow_stare",
		"on": "woke",
		"when": {"act": 1, "marks_at_least": 3},
		"do": [{"set_flag": "clue_crow_stare"}],
	},
	{
		# Na primeira noite na caverna, três bipes no ritmo do coração.
		"id": "clue_beep",
		"on": "woke",
		"when": {"act": 1, "marks_at_least": 4},
		"do": [{"set_flag": "clue_beep"}],
	},
	{
		# Na próxima rajada forte, o zumbido de um ventilador.
		"id": "clue_fan",
		"on": "woke",
		"when": {"act": 1, "marks_at_least": 5},
		"do": [{"set_flag": "clue_fan"}],
	},
	{
		# O musgo ao lado da pele cai e mostra centenas de riscos antigos (fim do Ato I).
		"id": "moss_falls",
		"on": "woke",
		"when": {
			"act": 1,
			"reason": "sleep",
			"any": [
				{"marks_at_least": 7, "counter_at_least": {"deer_harvested": 1}},
				{"marks_at_least": 10},
			],
		},
		"do": [{"set_flag": "moss_fell"}, {"set_act": 2}],
	},
	# --- Ato II: os flashes (a cena é da F5; as anotações já entram) --------------------
	{
		"id": "flash_1",
		"on": "woke",
		"when": {"act": 2, "reason": "sleep", "counter_at_least": {"sleeps_act_2": 1}},
		"do": [{"flash": 1}, {"add_note": "Se o braço direito doer, é normal."}],
	},
	{
		"id": "flash_2",
		"on": "woke",
		"when": {"act": 2, "reason": "sleep", "counter_at_least": {"sleeps_act_2": 2}},
		"do": [{"flash": 2}, {"add_note": "NÃO COMA A CARNE DO CERVO BRANCO."}],
	},
	{
		"id": "flash_3",
		"on": "woke",
		"when": {"act": 2, "reason": "sleep", "counter_at_least": {"sleeps_act_2": 3}},
		"do": [{"flash": 3}, {"set_flag": "saw_ruin_window"}, {"add_note": "A ruína. Eu vi a ruína pela janela."}],
	},
	# --- Reciclagem ----------------------------------------------------------------------
	{
		# A carne do cervo branco é o sedativo: comer reinicia o ciclo. Toda vez.
		"id": "white_meat_recycle",
		"on": "ate",
		"when": {"reason": "white_meat"},
		"repeat": true,
		"do": [{"recycle": "white_meat"}],
	},
]
