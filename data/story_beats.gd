class_name StoryBeats
extends RefCounted
## Acontecimentos da história, como dados (ver docs/plano.md, §3 e §9).
##
## Cada beat é avaliado quando o gatilho `on` acontece e dispara uma vez só, se as
## condições de `when` valerem. Para mudar a história, edite esta lista; o Story só a
## interpreta, e os sistemas reagem aos flags (o musgo cai quando "moss_fell" liga).
##
## Gatilhos (`on`): "start", "slept", "woke", "died", "harvested", "ate".
## Condições (`when`, todas precisam valer):
##   "act": n, "act_at_least": n, "marks_at_least": n, "flag": nome, "not_flag": nome,
##   "counter_at_least": {nome: n}, "reason": motivo do gatilho (ex.: "sleep"),
##   "any": [condições, ...] (basta uma valer).
## Ações (`do`, em ordem):
##   {"set_flag": nome}, {"clear_flag": nome}, {"set_act": n}, {"add_note": texto},
##   {"notify": texto}.

const BEATS: Array[Dictionary] = [
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
]
