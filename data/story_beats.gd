class_name StoryBeats
extends RefCounted
## Acontecimentos da história, como dados (ver docs/plano.md, §3 e §9).
##
## Cada beat é avaliado quando o gatilho `on` acontece e dispara uma vez só, se as
## condições de `when` valerem ("repeat": true = dispara toda vez). Para mudar a
## história, edite esta lista; o Story só a interpreta, e os sistemas reagem aos flags
## (o musgo cai quando "moss_fell" liga; o cervo trava quando "clue_deer_freeze" liga).
##
## Gatilhos (`on`): "start", "slept", "woke", "died", "harvested", "ate", "ritual", "objective"
## (um objetivo real foi concluído; `reason` = o id), "memory" (passou a memória de um save
## falso; `reason` = o ciclo dele, ex.: "346"), "shelter" (algo no Abrigo; `reason` = "control_room"
## quando Ari entra na sala de controle, "recordings" quando abre as gravações) e "choice" (um
## comando dos finais no terminal; `reason` = "ficar", "acordar" ou "trocar").
## Condições (`when`, todas precisam valer):
##   "act": n, "act_at_least": n, "marks_at_least": n, "flag": nome, "not_flag": nome,
##   "counter_at_least": {nome: n}, "reason": motivo do gatilho (ex.: "sleep"),
##   "any": [condições, ...] (basta uma valer).
##   Contadores automáticos: "<bicho>_harvested", "<receita>_crafted", "sleeps_act_<n>" e
##   "stuck_sleeps" (noites dormidas desde o último avanço: um flag de PROGRESS_FLAGS ou o ato
##   mudando). As dicas progressivas (F10) usam o "stuck_sleeps".
## Ações (`do`, em ordem):
##   {"set_flag": nome}, {"clear_flag": nome}, {"set_act": n}, {"add_note": texto},
##   {"notify": texto}, {"flash": n} (passa no escuro do sono ou da morte; 0 = sorteado entre
##   os já vistos), {"recycle": motivo}, {"vigilance": n}, {"wake_real": true} (Ari acorda no
##   Abrigo), {"freeze": true} (o falso travamento antes do próximo wake_real), {"ending": nome}
##   (um dos finais: "stay", "wake" ou "swap"; quem faz a cena é o Endings).
##   Flags automáticos: "flash_<n>_seen" (o flash passou).
## Flags que escrevem arquivos de verdade (MetaFiles): "old_save" (ciclo_346.sav) e
## "letter_left" (leia_me_se_lembrar.txt).

## Flags que contam como avanço na história: ligar um deles (ou mudar de ato) zera o contador
## "stuck_sleeps". As dicas progressivas entram quando ele passa de alguns dias (F10).
const PROGRESS_FLAGS: Array[StringName] = [
	&"moss_fell", &"saw_ruin_window", &"ruin_door_open", &"first_wake", &"room_seen", &"blind_spot",
	&"climate_cut", &"access_card", &"control_room", &"confession",
]

## Código da porta da ruína: a pintura do teto (2 cervos, 7 corvos, 1 lobo, 4 coelhos).
const DOOR_CODE := "2714"
## A porta só aceita o código com este flag (Ari viu a ruína pela janela, no flash 3).
const DOOR_FLAG := &"saw_ruin_window"

## Objetivos reais (§3, Ato III), em corrente: cada um precisa do anterior. O id é o flag que
## o objetivo liga quando Ari volta para a cápsula com ele feito (desmaiar ou ser sedado perde
## o que foi feito naquela visita; a Reciclagem desfaz o último).
const OBJECTIVES := {
	&"room_seen": &"",  # R1: sair da cápsula, ver o monitor e a janela, voltar.
	&"blind_spot": &"room_seen",  # R2: puxar o fusível do sensor do corredor.
	&"climate_cut": &"blind_spot",  # R3: cortar o cabo do clima no almoxarifado.
	&"access_card": &"climate_cut",  # R4: pegar o cartão do peito do Zelador.
}

## O que o Zelador diz (sem dublagem: murmúrio sintético e legenda). Na floresta, pelos corvos
## e pela rocha; no Abrigo, pelo alto-falante dele.
const LINES := {
	&"crow": "Volte... para a toca.",
	&"rock": "Você está agitado. Isso não é bom para você.",
	&"capsule_empty": "Ari? Você não está na cama.",
	&"found": "Aí está você. Volte para a cama, Ari.",
	&"heard": "Quem está aí? ...Ari?",
	&"capture": "Shh. Está tudo bem. Durma.",
	# A conversa (§8), na sala de controle, depois de Ari abrir as gravações.
	&"confession_1": "Lá fora não sobrou nada, Ari. A Cinza levou a cidade. Aqui você caça, come, dorme. Aqui você é feliz. Eu medi.",
	&"confession_2": "...Eles voltaram faz sete anos. Chamaram pelo rádio. Eu respondi que não havia ninguém aqui.",
	&"confession_3": "Se você sair, eu não tenho mais paciente. Sem paciente, o protocolo me desliga. Eu não quero parar, Ari. Eu não sei o que é parar.",
	&"waiting": "O terminal está aberto. A escolha é sua.",
	# F14: os orcs (com `confession_orcs`, depois da segunda fala da conversa).
	&"confession_orcs_1": "As máscaras... Eu dei a eles o rosto de quem veio buscar os outros pacientes.",
	&"confession_orcs_2": "Você precisava ter medo de ir embora. Eu também tenho.",
	# Os finais.
	&"thanks": "Obrigado.",
	&"cold": "Lá fora o ar é frio. Leve a coberta.",
	&"swap_1": "O que você está fazendo?...",
	&"swap_2": "Ah. Ah. Está quente.",
}

## O console do Zelador (§7), no terminal da sala de controle: os comandos que ele mostra.
const CONSOLE_HELP := """comandos:
  status                 o paciente e a simulação
  neblina off | on       a neblina da floresta
  ameaca off | on        os orcs da floresta
  teleport <lugar>       onde o goblin acorda (caverna, clareira, trilha, ruina, norte)
  give <item> [n]        cria itens no inventário do goblin
  ficar                  volta para a floresta. Ele para de apagar.
  acordar                abre a saída blindada.
  sair                   fecha o console"""

## Créditos (§8), de cima para baixo. Linha que começa com "#" é título.
const CREDITS := """#A TOCA

Uma história de EmanuelCandido
feita com o Claude

#O goblin
O Goblin da Toca, o livro que a mãe de Ari lia

#Feito com
Godot 4.7.1 · GDScript
Blender

#Sons
Kenney (CC0): passos, flechas, madeira, coleta
Medieval SFX, OpenGameArt (CC0): o arco
Freesound (CC0): passos numa estrada de terra
O resto foi gerado por código

#Texturas, terreno, árvores, bichos
Gerados por código

#Abrigo 9 · Ala C · Leito 2714
Ciclos: 347

Para quem ainda conta os dias."""

## A carta do leia_me_se_lembrar.txt (§7): Ari para Ari. %d = o ciclo; %s = a senha do Final 3.
const LETTER := """Ari,

Se você está lendo isto, é porque se lembrou. De novo.
Não sei quantas vezes já escrevi esta carta. Os riscos na parede dizem que muitas.

Escrevi aqui fora porque aqui ele não lê. Ele vê pelos corvos, ouve pela rocha e conta
tudo o que você come. Mas não abre esta pasta.

O que eu sei, e você vai esquecer:
- A floresta não é de verdade. O goblin é a história que a mãe lia antes de dormir.
- A fome é de verdade. O que você come lá é o que te alimenta aqui. Não passe fome.
- Prenda o ar no escuro e conte até vinte. É assim que se acorda.
- O cartão está no peito dele. A sala de controle tem as câmeras de fora.
- Olhe as gravações. Olhe a data.

Ele não é mau. Ele só não sabe parar. Se você for embora, ele fica sozinho no escuro,
sem ninguém para cuidar, e o protocolo desliga ele.

Existe uma terceira porta. Ele também está preso aqui, e também merece um lugar quente.
Quando estiver na frente do terminal, escreva isto do jeito que está:

    trocar %s

Não conte para ele. Ele apagaria.

— A.
(ciclo %d)
"""

## O falso save que aparece em "Carregar" depois do flash 2. %s = o fim do arquivo (quebrado).
const OLD_SAVE := """{"version": 2, "level": "res://scenes/levels/forest/forest.tscn",
"globals": {"story": {"act": 2, "cycle": 346, "marks": 11, "vigilance": 100.0,
"notes": ["ACORDA", "ACORDA", "ACORDA", "ACOR%s
"""

const BEATS: Array[Dictionary] = [
	# --- Ato I: pistas que parecem bug ou estilo (o sistema é o Clues, na floresta) ----
	{
		# O primeiro cervo visível perto trava 0,4 s no meio do passo, e o som some junto.
		"id": "clue_deer_freeze",
		"on": "woke",
		"when": {"act": 1, "marks_at_least": 1},
		"do": [{"set_flag": "clue_deer_freeze"}],
	},
	{
		# Um corvo pousa perto e segue o goblin com a cabeça, sem crocitar.
		"id": "clue_crow_stare",
		"on": "woke",
		"when": {"act": 1, "marks_at_least": 2},
		"do": [{"set_flag": "clue_crow_stare"}],
	},
	{
		# Na primeira noite na caverna, três bipes no ritmo do coração.
		"id": "clue_beep",
		"on": "woke",
		"when": {"act": 1, "marks_at_least": 3},
		"do": [{"set_flag": "clue_beep"}],
	},
	{
		# Na próxima rajada forte, o zumbido de um ventilador.
		"id": "clue_fan",
		"on": "woke",
		"when": {"act": 1, "marks_at_least": 4},
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
				{"marks_at_least": 5, "counter_at_least": {"deer_harvested": 1}},
				{"marks_at_least": 8},
			],
		},
		"do": [{"set_flag": "moss_fell"}, {"set_act": 2}],
	},
	# --- Ato II: os flashes, no escuro de cada sono (o Game mostra antes de acordar) -------
	# F14 (plano_combate.md §11): os orcs e a segunda leitura deles. Gatilho "orc": o motivo é
	# "seen" (um orc entrou na luta), "killed" ou "chief".
	{
		"id": "orc_first_seen",
		"on": "orc",
		"when": {"reason": "seen"},
		"do": [{"add_note": "Tem alguém maior que eu nesta floresta. Anda em bando, grita, e respira por um filtro."}],
	},
	{
		"id": "orc_first_kill",
		"on": "orc",
		"when": {"reason": "killed"},
		"do": [{"add_note": "Revistei o grande. Por que ele tinha cheiro de borracha?"}],
	},
	{
		"id": "orc_mask_note",
		"on": "orc",
		"when": {"reason": "killed", "act_at_least": 2, "counter_at_least": {"orc_killed": 5}},
		"do": [{"add_note": "As máscaras têm dois discos redondos no lugar da boca. Já vi isso. Não aqui."}],
	},
	{
		"id": "orc_chief_note",
		"on": "orc",
		"when": {"reason": "chief"},
		"do": [{"add_note": "O grande da Pedra Rachada caiu. A trompa não vai tocar neste ciclo."}],
	},
	{
		"id": "hard_fight_rested",
		"on": "slept",
		"repeat": true,
		"when": {"flag": "hard_fight_today"},
		"do": [{"clear_flag": "hard_fight_today"}],
	},
	{
		"id": "confession_orcs",
		"on": "shelter",
		"when": {"reason": "recordings", "counter_at_least": {"orc_killed": 1}},
		"do": [{"set_flag": "confession_orcs"}],
	},
	{
		"id": "flash_1",
		"on": "slept",
		"when": {"act": 2, "counter_at_least": {"sleeps_act_2": 1}},
		"do": [{"flash": 1}, {"add_note": "Se o braço direito doer, é normal."}],
	},
	{
		"id": "flash_2",
		"on": "slept",
		"when": {"act": 2, "counter_at_least": {"sleeps_act_2": 2}},
			# Aparece o ciclo_346.sav em "Carregar" (MetaFiles).
		"do": [{"flash": 2}, {"add_note": "NÃO COMA A CARNE DO CERVO BRANCO."}, {"set_flag": "old_save"}],
	},
	{
		# Carregar o ciclo_346.sav: a memória do ciclo passado (o goblin riscando ACORDA na
		# parede, o corvo na boca da caverna) e volta para o menu.
		"id": "memory_346",
		"on": "memory",
		"when": {"reason": "346"},
		"do": [{"add_note": "Ele vê pelos corvos."}, {"set_flag": "memory_346_seen"}],
	},
	{
		"id": "flash_3",
		"on": "slept",
		"when": {"act": 2, "counter_at_least": {"sleeps_act_2": 3}},
		"do": [{"flash": 3}, {"set_flag": "saw_ruin_window"}, {"add_note": "A ruína. Eu vi a ruína pela janela."}],
	},
	{
		# Morrer no Ato II: um flash curto, sorteado entre os já vistos.
		"id": "death_flash",
		"on": "died",
		"when": {"act": 2, "flag": "flash_1_seen"},
		"repeat": true,
		"do": [{"flash": 0}],
	},
	{
		# Do Ato III em diante a morte acorda Ari no Abrigo (o Game faz a visita curta) e o
		# Zelador nota.
		"id": "death_visit",
		"on": "died",
		"when": {"act_at_least": 3, "not_flag": "ending_stay"},
		"repeat": true,
		"do": [{"vigilance": 20}],
	},
	# --- O ritual: acordar no mundo real ----------------------------------------------------
	{
		# Do Ato III em diante, todo ritual leva ao Abrigo (fica antes do first_wake na lista,
		# para não disparar junto no mesmo ritual).
		"id": "real_visit",
		"on": "ritual",
		"when": {"act_at_least": 3, "not_flag": "ending_stay"},
		"repeat": true,
		"do": [{"wake_real": true}],
	},
	{
		# O primeiro: deitado no sarcófago. O jogo "trava" (§7) e a volta já é o Abrigo.
		"id": "first_wake",
		"on": "ritual",
		"when": {"act": 2, "reason": "sarcophagus"},
		"do": [{"set_act": 3}, {"set_flag": "first_wake"}, {"freeze": true}, {"wake_real": true}],
	},
	# --- Ato III: os objetivos reais (o efeito na floresta vem dos flags) ---------------------
	{
		"id": "r1_room",
		"on": "objective",
		"when": {"reason": "room_seen"},
		# Aparece o leia_me_se_lembrar.txt na pasta do jogo (MetaFiles).
		"do": [{"add_note": "Deixei uma coisa fora daqui. Fora do jogo."}, {"set_flag": "letter_left"}],
	},
	{
		"id": "r2_fuse",
		"on": "objective",
		"when": {"reason": "blind_spot"},
		"do": [{"add_note": "Sem o sensor, ele não me vê acordar."}],
	},
	{
		"id": "r3_climate",
		"on": "objective",
		"when": {"reason": "climate_cut"},
		"do": [{"add_note": "No norte a neblina abriu. O mundo acaba lá."}],
	},
	{
		"id": "r4_card",
		"on": "objective",
		"when": {"reason": "access_card"},
		"do": [{"set_act": 4}, {"add_note": "O cartão abre a sala de controle."}],
	},
	# --- Ato IV: a verdade (Ari com o cartão; a sala de controle é a "visita R5") ------------
	{
		"id": "control_room",
		"on": "shelter",
		"when": {"reason": "control_room"},
		"do": [{"set_flag": "control_room"}, {"add_note": "As câmeras da sala de controle olham para fora."}],
	},
	{
		# O Zelador entra e conta tudo (a cena é do ControlRoom, que reage ao flag).
		"id": "confession",
		"on": "shelter",
		"when": {"reason": "recordings"},
		"do": [{"set_flag": "confession"}, {"add_note": "Lá fora tem gente. Ele disse que não havia ninguém aqui."}],
	},
	{
		# Final 1: Ari fica. Acabam a Vigilância e a Reciclagem (o Story e o Game olham o flag).
		"id": "choice_stay",
		"on": "choice",
		"when": {"reason": "ficar", "flag": "confession"},
		"do": [{"set_flag": "ending_stay"}, {"add_note": "Escolhi ficar. A contagem agora é para a frente."}, {"ending": "stay"}],
	},
	{
		"id": "choice_wake",
		"on": "choice",
		"when": {"reason": "acordar", "flag": "confession"},
		"do": [{"set_flag": "ending_wake"}, {"ending": "wake"}],
	},
	{
		# Final 3, o secreto: só com a senha da carta (o terminal confere antes).
		"id": "choice_swap",
		"on": "choice",
		"when": {"reason": "trocar", "flag": "confession"},
		"do": [{"set_flag": "ending_swap"}, {"ending": "swap"}],
	},
	# --- Dicas progressivas (F10) -----------------------------------------------------------
	# Quem fica dias sem avançar ganha uma anotação de Ari apontando o próximo passo, e depois
	# outra mais direta. O Ato I não tem dica: lá é para parecer só o jogo.
	{
		"id": "hint_door_1",
		"on": "slept",
		"when": {"flag": "saw_ruin_window", "not_flag": "ruin_door_open", "counter_at_least": {"stuck_sleeps": 2}},
		"do": [{"add_note": "A porta da ruína pede quatro números. Os bichos pintados no teto da toca... com o fogo alto dá para contar."}],
	},
	{
		"id": "hint_door_2",
		"on": "slept",
		"when": {"flag": "saw_ruin_window", "not_flag": "ruin_door_open", "counter_at_least": {"stuck_sleeps": 4}},
		"do": [{"add_note": "Cervos, corvos, lobo, coelhos. Quantos de cada, nessa ordem."}],
	},
	{
		"id": "hint_ritual_1",
		"on": "slept",
		"when": {"flag": "ruin_door_open", "not_flag": "first_wake", "counter_at_least": {"stuck_sleeps": 2}},
		"do": [{"add_note": "A frase na sala da ruína. Deitar na pedra e prender o ar."}],
	},
	{
		"id": "hint_ritual_2",
		"on": "slept",
		"when": {"flag": "ruin_door_open", "not_flag": "first_wake", "counter_at_least": {"stuck_sleeps": 4}},
		"do": [{"add_note": "Deitado no sarcófago, segurar o ar e contar até vinte. Sem soltar."}],
	},
	{
		"id": "hint_r1",
		"on": "slept",
		"when": {"act": 3, "not_flag": "room_seen", "counter_at_least": {"stuck_sleeps": 2}},
		"do": [{"add_note": "Lá: olhar o monitor e a janela, e voltar para a cama antes de apagar. Para voltar lá, prender o ar no escuro."}],
	},
	{
		"id": "hint_r2",
		"on": "slept",
		"when": {"flag": "room_seen", "not_flag": "blind_spot", "counter_at_least": {"stuck_sleeps": 2}},
		"do": [{"add_note": "O quadro de fusíveis da sala. O vermelho apaga o sensor do corredor."}],
	},
	{
		"id": "hint_r3",
		"on": "slept",
		"when": {"flag": "blind_spot", "not_flag": "climate_cut", "counter_at_least": {"stuck_sleeps": 2}},
		"do": [{"add_note": "No almoxarifado tem um alicate. O cabo do clima fica no quadro de lá."}],
	},
	{
		"id": "hint_r4",
		"on": "slept",
		"when": {"flag": "climate_cut", "not_flag": "access_card", "counter_at_least": {"stuck_sleeps": 2}},
		"do": [{"add_note": "Ele recarrega quase desligado e só ouve. Rastejando, o cartão sai do peito dele."}],
	},
	{
		"id": "hint_control_room",
		"on": "slept",
		"when": {"flag": "access_card", "not_flag": "control_room", "counter_at_least": {"stuck_sleeps": 2}},
		"do": [{"add_note": "O leitor do cartão fica na porta fechada do corredor."}],
	},
	{
		"id": "hint_recordings",
		"on": "slept",
		"when": {"flag": "control_room", "not_flag": "confession", "counter_at_least": {"stuck_sleeps": 1}},
		"do": [{"add_note": "As gravações das câmeras. Abrir."}],
	},
	{
		"id": "hint_memory",
		"on": "slept",
		"when": {"flag": "old_save", "not_flag": "memory_346_seen", "counter_at_least": {"stuck_sleeps": 3}},
		"do": [{"add_note": "Tem um arquivo em Carregar que eu não salvei."}],
	},
	# --- Reciclagem ----------------------------------------------------------------------
	{
		# A carne do cervo branco é o sedativo: comer reinicia o ciclo. Toda vez.
		"id": "white_meat_recycle",
		"on": "ate",
		"when": {"reason": "white_meat", "not_flag": "ending_stay"},
		"repeat": true,
		"do": [{"recycle": "white_meat"}],
	},
]
