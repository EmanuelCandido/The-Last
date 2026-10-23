class_name Tuning
extends RefCounted
## Números de ajuste do jogo, num lugar só (ver docs/plano.md, §9).
##
## Os sistemas leem daqui em vez de ter números soltos no código: para mudar o ritmo
## do jogo, mexa só neste arquivo. Tempos em segundos reais, salvo quando indicado.

# --- Relógio (§4.1) ----------------------------------------------------------------

## Segundos reais por hora de jogo (24 h = 24 min).
const SECONDS_PER_HOUR := 60.0
## Hora em que o jogo começa e em que se acorda depois de dormir ou morrer.
const START_HOUR := 7.0
const WAKE_HOUR := 6.5
## Pode dormir a partir desta hora, antes da madrugada acabar ou depois de tantas horas acordado.
const SLEEP_FROM_HOUR := 18.0
const SLEEP_UNTIL_HOUR := 5.0
const SLEEPY_AFTER_HOURS := 10.0
## Anoitecer e amanhecer (hora em que começa e em que termina a passagem). Entre o fim
## do anoitecer e o começo do amanhecer é noite fechada.
const DUSK := Vector2(18.5, 20.5)
const DAWN := Vector2(5.0, 7.0)

# --- Luz do dia e da noite (§4.1) ------------------------------------------------------

## Céu nublado de dia e de noite; a passagem mistura os dois pela Clock.night(). Na meia
## passagem (lusco-fusco) a neblina puxa para TWILIGHT_FOG.
const DAY_LIGHT := {
	"sun_energy": 0.65, "sun_color": Color(0.86, 0.88, 0.92),
	"sky_energy": 1.0, "fog_color": Color(0.56, 0.58, 0.6),
}
const NIGHT_LIGHT := {
	"sun_energy": 0.12, "sun_color": Color(0.5, 0.58, 0.85),
	"sky_energy": 0.13, "fog_color": Color(0.07, 0.085, 0.11),
}
const TWILIGHT_FOG := Color(0.48, 0.4, 0.36)
const TWILIGHT_WEIGHT := 0.45

# --- Corpo (§4.2, §4.3) ------------------------------------------------------------

const START_SATIETY := 70.0
## Saciedade perdida por segundo (100 em 2 dias de jogo).
const SATIETY_DECAY := 100.0 / (48.0 * SECONDS_PER_HOUR)
## Saciedade gasta numa noite de sono.
const SLEEP_SATIETY_COST := 15.0
## Vida recuperada dormindo, se a saciedade estiver acima de SLEEP_HEAL_MIN_SATIETY.
const SLEEP_HEAL := 25.0
const SLEEP_HEAL_MIN_SATIETY := 20.0
## Vida perdida por segundo com a saciedade zerada.
const STARVE_DAMAGE := 0.5
## Regeneração por segundo, só com a saciedade acima de REGEN_MIN_SATIETY e sem enjoo.
const REGEN := 0.1
const REGEN_MIN_SATIETY := 50.0
## Abaixo disto a barriga ronca (e o aviso "Com fome" aparece uma vez).
const HUNGRY_BELOW := 30.0
## Abaixo disto o goblin põe a mão na barriga quando fica parado.
const STARVING_BELOW := 15.0
## Segundos entre roncos da barriga (sorteado entre os dois).
const GROWL_INTERVAL := Vector2(40.0, 70.0)
## Vida baixa: a borda da tela escurece e pulsa.
const LOW_HEALTH := 40.0
## Como se volta depois de morrer.
const DEATH_HEALTH := 60.0
const DEATH_SATIETY := 40.0

## Comida: saciedade ganha, chance de enjoo (0..1) e a ação que o goblin faz.
const FOODS := {
	&"cooked_meat": {"satiety": 30.0, "nausea_chance": 0.0},
	&"meat": {"satiety": 12.0, "nausea_chance": 0.25},
	# O sedativo: enche muito a barriga e reinicia o ciclo (beat white_meat_recycle).
	&"white_meat": {"satiety": 60.0, "nausea_chance": 0.0},
	# F9: a coleta, a carne defumada (não estraga) e a estragada.
	&"smoked_meat": {"satiety": 26.0, "nausea_chance": 0.0},
	&"berries": {"satiety": 6.0, "nausea_chance": 0.0},
	&"mushroom": {"satiety": 8.0, "nausea_chance": 0.15},
	&"rotten_meat": {"satiety": 6.0, "nausea_chance": 0.9},
}
## Ordem em que o goblin escolhe o que comer.
const FOOD_PREFERENCE: Array[StringName] = [&"cooked_meat", &"smoked_meat", &"berries", &"mushroom", &"meat", &"rotten_meat", &"white_meat"]
## Enjoo de carne crua: dano na hora e segundos sem regenerar.
const NAUSEA_DAMAGE := 5.0
const NAUSEA_SECONDS := 60.0
## Duração da animação de comer e o instante em que a comida chega à boca.
const EAT_TIME := 1.6
const EAT_BITE_AT := 0.8

## Frio (0..100) ganho por segundo. Fora/dentro da caverna, de noite e de dia (a passagem
## mistura). O ganho (positivo) é multiplicado por 0,5 + força do vento no goblin.
const COLD_NIGHT_OUTSIDE := 0.6
const COLD_NIGHT_CAVE := 0.15
const COLD_DAY := -1.0
## Perto de fogo aceso (raio em m), o frio cai por segundo.
const FIRE_WARMTH := -3.0
const FIRE_WARM_RADIUS := 4.0
## Com a roupa de couro, o ganho de frio é multiplicado por isto.
const CLOTHES_COLD_FACTOR := 0.5
## A partir disto o goblin treme e o aviso aparece; no máximo, o frio machuca.
const COLD_SHIVER := 50.0
const COLD_DAMAGE := 0.6

## De noite os bichos enxergam o goblin com esta fração da visibilidade de dia.
const NIGHT_VISIBILITY := 0.55
## Os bichos: a atenção não passa de (estímulo por segundo) × isto. Fugir (0,8) pede um estímulo
## de 0,4/s, o que ver o goblin andando de pé dá a ~18 m de um cervo alerta; desconfiar (0,35), um
## de 0,18/s. Sinal mais fraco que isso, por mais que dure, não assusta.
const ANIMAL_AWARENESS_CEILING := 2.0
## Movimento que os bichos veem (0..1) é a velocidade do goblin ÷ isto; andando de pé nunca
## fica abaixo de UPRIGHT_MOTION (braços e pernas balançando chamam atenção mesmo devagar).
const SIGHT_MOTION_SPEED := 3.0
const UPRIGHT_MOTION := 0.85
## Barulho dos passos (0..1): andando de pé é isto, e sobe até 1 no disparo.
const WALK_NOISE := 0.45
## Quanto o passo de um bicho correndo sai mais alto que andando (dB).
const ANIMAL_RUN_STEP_DB := 5.0

## Pulo: segundos que o goblin agacha antes de sair do chão (o impulso vem no fim).
const JUMP_PREP := 0.1
## Queda: acima desta velocidade (m/s), dano = (v - FALL_DAMAGE_SPEED) * FALL_DAMAGE_PER_MS.
const FALL_DAMAGE_SPEED := 8.0
const FALL_DAMAGE_PER_MS := 12.0

# --- Fogueira (§4.4) ---------------------------------------------------------------

const FIRE_MAX_FUEL := 3.0
const FIRE_START_FUEL := 1.0
## Segundos que uma lenha dura queimando.
const FIRE_SECONDS_PER_FUEL := 360.0
## Assar uma carne: duração da ação e quando a carne fica pronta.
const COOK_TIME := 6.0
const COOK_DONE_AT := 5.6
## Pôr lenha: duração da ação e quando a lenha cai no fogo.
const FEED_TIME := 1.1
const FEED_AT := 0.5

# --- Sono e acordar (§4.5) ---------------------------------------------------------

## Segundos para a tela escurecer ao dormir e ao morrer.
const SLEEP_FADE := 1.6
const DEATH_FADE := 2.2
## Segundos no escuro antes de acordar.
const DARK_HOLD := 1.2

# --- Riscos na parede (§4.5) -------------------------------------------------------

## Riscos antigos debaixo do musgo, de ciclos passados (o bastante para cobrir a mancha).
const OLD_MARKS := 640

# --- Lobos (§4.7) --------------------------------------------------------------------

## A partir de que dia, a que hora chegam e a que hora vão embora.
const WOLVES_FROM_DAY := 3
const WOLF_ARRIVE_HOUR := 21.0
const WOLF_LEAVE_HOUR := 5.5
const WOLF_COUNT := 2
## O uivo de aviso vem este tanto de horas antes (0,5 h = 30 s).
const WOLF_WARNING_HOURS := 0.5
## Nascem na borda do vale, pelo menos a esta distância do goblin.
const WOLF_SPAWN_MIN_DISTANCE := 60.0
## Mordida: dano, intervalo e alcance (m).
const WOLF_BITE := 15.0
const WOLF_BITE_INTERVAL := 1.6
const WOLF_BITE_RANGE := 1.3
## Não chegam a menos disto de um fogo aceso (m).
const WOLF_FIRE_FEAR := 6.0
## De quanto em quanto tempo a matilha arrasta a área de caça para onde sentiu o goblin.
const WOLF_HOME_DRIFT_SECONDS := 25.0

# --- Rastros (§4.8) --------------------------------------------------------------------

## Distância (m) entre duas pegadas, quanto tempo ficam no chão e quantas existem ao mesmo tempo.
const TRACK_SPACING := 0.9
const TRACK_SECONDS := 120.0
const TRACK_POOL := 200

# --- Farejar (§4.8) ---------------------------------------------------------------------

## Segurando X: no máximo isto de segundos por vez, e só depois de soltar fareja de novo.
const SNIFF_MAX_SECONDS := 6.0
## Bichos até esta distância soltam trilha de cheiro, se o vento traz o cheiro deles.
const SNIFF_RANGE := 45.0
## O vento precisa vir do bicho para o goblin: cosseno mínimo entre o vento e bicho→goblin.
const SNIFF_DOWNWIND := 0.35
## O som abafa enquanto fareja (dB e corte do passa-baixa, Hz).
const SNIFF_MUFFLE_DB := -12.0
const SNIFF_MUFFLE_HZ := 1400.0

# --- Fôlego (§4.9) ---------------------------------------------------------------------

## Prender o ar (Q): segundos até não aguentar mais e soltar alto.
const BREATH_MAX_SECONDS := 12.0
## Ao soltar sem aguentar: alcance do barulho (m) e segundos ofegando com a mira tremendo.
const BREATH_GASP_NOISE := 6.0
const BREATH_GASP_SECONDS := 3.0
## Parado e ofegante (depois de correr), o goblin respira alto: barulho máximo da respiração (0..1).
const PANTING_NOISE := 0.25
## No ritual (Ato III) o ar não acaba: segundos agachado e parado para acordar no Abrigo (F6).
const RITUAL_BREATH_SECONDS := 20.0

# --- Pedras (§4.11) ---------------------------------------------------------------------

const STONE_MAX := 5
## Velocidade do arremesso (m/s), quanto sobe acima da mira e o alcance do barulho onde cai (m).
const STONE_SPEED := 14.0
const STONE_LOFT := 0.12
const STONE_NOISE := 12.0
## Ação de arremessar: duração e o instante em que a pedra sai da mão.
const THROW_TIME := 0.7
const THROW_RELEASE_AT := 0.32

# --- Lama (§4.11) -----------------------------------------------------------------------

## Esfregar lama: duração da ação. A camuflagem vai de 1 a 0 em MUD_SECONDS (1 dia de jogo),
## MUD_RUN_FACTOR vezes mais rápido correndo.
const MUD_RUB_TIME := 3.0
const MUD_SECONDS := 24.0 * SECONDS_PER_HOUR
const MUD_RUN_FACTOR := 4.0
## Com lama cheia, a visibilidade e o alcance do cheiro são multiplicados por isto.
const MUD_VISIBILITY := 0.65
const MUD_SCENT := 0.5

# --- Fabricar (§4.10) -------------------------------------------------------------------

## Ação de fabricar (animação craft) e o instante em que a coisa fica pronta.
const CRAFT_TIME := 2.0
const CRAFT_DONE_AT := 1.7
## A lista some sozinha depois disto sem mexer nela (s).
const CRAFT_LIST_SECONDS := 8.0
## Flecha emplumada: fração da gravidade e multiplicador de dano.
const FEATHERED_GRAVITY := 0.6
const FEATHERED_DAMAGE := 1.15
## Corvo abatido: penas que rende.
const CROW_FEATHERS := 2
## Um corvo novo volta ao bando depois disto (s).
const CROW_RESPAWN_SECONDS := 300.0
## Laço: chance de pegar um coelho em SNARE_HOURS horas de jogo armado, e a que distância de
## uma pegada de coelho dá para armar (m). Só pega com o goblin longe (m), para não ver surgir.
const SNARE_CHANCE := 0.6
const SNARE_HOURS := 24.0
const SNARE_TRACK_DISTANCE := 1.6
const SNARE_UNSEEN_DISTANCE := 25.0
## Tocha: segundos acesa e quanto mais fácil os bichos veem o goblin com ela (de noite não
## vale o desconto do escuro).
const TORCH_SECONDS := 240.0
const TORCH_VISIBILITY := 1.8

# --- Vigilância (§5) ---------------------------------------------------------------------

## A partir de que ato a Vigilância (0..100) conta.
const VIGILANCE_FROM_ACT := 2
## O que sobe e o que desce.
const VIGILANCE_CROW_SHOT := 5.0
const VIGILANCE_KEYPAD_SEEN := 10.0
const VIGILANCE_RITUAL := 10.0
const VIGILANCE_RITUAL_SEEN := 25.0
const VIGILANCE_CALM_SLEEP := -15.0
const VIGILANCE_COOKED_MEAT := -2.0
## Depois da Reciclagem, a Vigilância volta para isto.
const VIGILANCE_AFTER_RECYCLE := 30.0
## Limiares dos efeitos: corvos em dobro e mais perto; cervo branco; Reciclagem em 100.
const VIGILANCE_MORE_CROWS := 40.0
const VIGILANCE_WHITE_DEER := 60.0

# --- Corvos espiões (§5) -----------------------------------------------------------------

## De quanto em quanto tempo um corvo pousa perto do goblin (s), a que distância (m), e quanto
## fica olhando (s). Com Vigilância alta: metade do intervalo e mais perto.
const SPY_INTERVAL := 120.0
const SPY_LAND_DISTANCE := 14.0
const SPY_LAND_DISTANCE_CLOSE := 7.0
const SPY_WATCH_SECONDS := 12.0
## Um corvo pousado vê o goblin até esta distância (m), com linha de visada.
const SPY_SIGHT := 28.0

# --- Pistas do Ato I (§3) ------------------------------------------------------------------

## Cervo que trava: distância máxima (m) e quanto tempo fica parado (s).
const CLUE_DEER_DISTANCE := 30.0
const CLUE_DEER_FREEZE := 0.4
## Corvo que encara: distância do pouso (m) e quanto tempo olha (s).
const CLUE_CROW_DISTANCE := 6.0
const CLUE_CROW_SECONDS := 8.0
## Bipes: quantos e em que ritmo (batidas por minuto).
const CLUE_BEEPS := 3
const CLUE_BEEP_BPM := 72.0
## Rajada forte o bastante para o ventilador vazar (força do vento no goblin; ~5% das rajadas
## passam disto — com 0,75 era 1% e a pista quase nunca acontecia).
const CLUE_FAN_GUST := 0.5
## Sons vazando no Ato II em diante: intervalo mínimo entre dois (s) e chance por noite do bipe.
const LEAK_FAN_COOLDOWN := 240.0
const LEAK_BEEP_CHANCE := 0.5

# --- Cervo branco e Reciclagem (§3) --------------------------------------------------------

## A Reciclagem: segundos da floresta se desmanchando antes de acordar no dia 1.
const RECYCLE_SECONDS := 5.0

# --- Ruína e ritual (§3, §4.9) ----------------------------------------------------------------

## Segundos da laje descendo no chão.
const RUIN_DOOR_OPEN_TIME := 3.0

# --- O Abrigo (§6) ----------------------------------------------------------------------------

## Onde fica o Abrigo: no mesmo mundo da floresta, 2 km abaixo (sem trocar de fase).
const SHELTER_ORIGIN := Vector3(0.0, -2000.0, 0.0)
## Ari andando e rastejando (m/s). Sem pulo e sem corrida. Andando, é a velocidade no passo
## bom: mancando, a média fica em ~0,9 m/s (§6.2).
const ARI_WALK_SPEED := 1.1
const ARI_CRAWL_SPEED := 0.4
## Uma passada inteira (passo bom + passo manco) em metros, e quanto a perna direita segura o
## corpo para trás (0 = anda reto; 1 = quase para no passo manco).
const ARI_STRIDE := 1.1
const ARI_LIMP := 0.55
## Altura dos olhos de pé e rastejando (m).
const ARI_EYE_HEIGHT := 1.62
const ARI_CRAWL_EYE := 0.5
## Prender o ar acordado (s) e quanto tempo fica arfando depois de não aguentar.
const ARI_BREATH_SECONDS := 15.0
const ARI_GASP_SECONDS := 4.0
## Barulho de Ari (raio em m, para o Zelador da F6): andando, rastejando, arfando.
const ARI_NOISE_WALK := 4.0
const ARI_NOISE_CRAWL := 1.5
const ARI_NOISE_PANT := 6.0
## Distância e ângulo (graus a partir do centro da tela) para interagir com algo.
const ARI_INTERACT_DISTANCE := 2.0
const ARI_INTERACT_ANGLE := 30.0
## Segundos para a visão clarear depois de acordar na cápsula.
const ARI_WAKE_BLUR_SECONDS := 6.0

# --- Flashes (§7) -----------------------------------------------------------------------------

## Duração de cada flash (s), pelo número; o flash de morte é mais curto.
const FLASH_SECONDS := {1: 8.0, 2: 7.0, 3: 8.0}
const DEATH_FLASH_SECONDS := 5.0
## Quanto a cabeça mexe com o mouse durante um flash (graus para cada lado).
const FLASH_LOOK_DEGREES := 10.0
## Batimento mostrado no monitor: normal e durante o flash 1 ("Leve agitação").
const SHELTER_BPM := 72.0
const FLASH_BPM := 112.0

# --- O Zelador (§6.3) -------------------------------------------------------------------------

## Velocidade (m/s): na ronda, atrás de Ari e com a bateria baixa (depois do R3).
const KEEPER_SPEED := 1.2
const KEEPER_CHASE_SPEED := 1.6
const KEEPER_LOW_BATTERY_SPEED := 0.8
## Visão: cone (graus) e alcance (m) com luz e no escuro (almoxarifado). Rastejando, Ari é
## visto a uma fração disso.
const KEEPER_FOV := 60.0
const KEEPER_SIGHT := 10.0
const KEEPER_SIGHT_DARK := 4.0
const KEEPER_SIGHT_CRAWLING := 0.6
## Segundos vendo Ari de perto até ter certeza (de longe demora mais).
const KEEPER_SIGHT_TIME := 1.0
## O térmico (o "faro" dele): alcance em m, atravessa paredes.
const KEEPER_THERMAL := 3.0
## A esta distância (m) ele seda.
const KEEPER_CAPTURE_DISTANCE := 1.2
## Sem ver Ari por tanto tempo (s), vai olhar onde o viu por último; e olha em volta por tanto.
const KEEPER_LOSE_SECONDS := 4.0
const KEEPER_LOOK_AROUND := 3.5
## A ronda: começa a cada tanto (s), mais vezes com Vigilância alta; a primeira, depois de Ari
## acordar. Paradas: cápsula, sala de controle, recarga.
const KEEPER_ROUND_INTERVAL := 90.0
const KEEPER_ROUND_INTERVAL_ALERT := 45.0
const KEEPER_ROUND_ALERT_VIGILANCE := 80.0
const KEEPER_FIRST_ROUND := 25.0
const KEEPER_CAPSULE_CHECK := 8.0
const KEEPER_CONTROL_STAY := 20.0
const KEEPER_DOCK_STAY := 30.0
## O sensor térmico do corredor: raio do cone no chão (m), antes do R2.
const SENSOR_RADIUS := 1.4

# --- Lucidez (§6.2) ---------------------------------------------------------------------------

## Deste ato em diante, morrer na floresta acorda Ari no Abrigo (uma visita curta).
const DEATH_VISIT_ACT := 3
## Quanto dura uma visita acordado (s); com fome, uma fração disso; depois de morrer, menos.
const LUCIDITY_SECONDS := 180.0
const LUCIDITY_HUNGRY_BELOW := 30.0
const LUCIDITY_HUNGRY_FACTOR := 0.6
const LUCIDITY_AFTER_DEATH := 90.0
## Nos últimos segundos o coração dispara e a visão fecha pelas bordas.
const LUCIDITY_WARNING := 30.0

# --- Vigilância no Abrigo (§5, §6) ------------------------------------------------------------

## Desmaiar (a lucidez acabou), ser sedado, o Zelador achar a cápsula vazia, passar no sensor.
const VIGILANCE_FAINT := 10.0
const VIGILANCE_CAPTURED := 30.0
const VIGILANCE_CAPSULE_EMPTY := 5.0
const VIGILANCE_SENSOR := 5.0

# --- O Zelador na floresta (Ato III) ----------------------------------------------------------

## Chance de um corvo espião falar com a voz dele; quanto a Vigilância precisa subir de uma vez
## para a voz sair da rocha (e o intervalo mínimo entre duas, s); chance de um chamado de bicho
## sair com a voz dele (depois do R4).
const KEEPER_CROW_VOICE_CHANCE := 0.5
const KEEPER_ROCK_VOICE_RISE := 8.0
const KEEPER_ROCK_VOICE_COOLDOWN := 120.0
const KEEPER_CALL_VOICE_CHANCE := 0.3
## Clima cortado (R3): a neblina abre no setor norte entre estes z (começa, aberta) e fica nesta
## densidade; o chão do céu fica preto (o vazio).
const NORTH_SECTOR_Z := Vector2(-15.0, -60.0)
const NORTH_FOG_DENSITY := 0.0015
## Onde o mundo acaba ao norte (z, m): o terreno e a vegetação somem depois daqui. Tem de cair
## numa divisa de bloco (múltiplo de 48 m a partir de -192 no terreno e de 0 na vegetação).
const VOID_EDGE_Z := -96.0
## Quanto o céu embaixo do horizonte escurece no setor norte (o vazio).
const VOID_SKY_DARKNESS := 0.92

# --- O mistério meta (§7) ---------------------------------------------------------------------

## Falso travamento (fim do Ato II): a imagem fica congelada com o áudio preso (s), depois vem a
## janela de "não está respondendo" (s) e a tela preta antes do Abrigo (s).
const FREEZE_SECONDS := 4.0
const FREEZE_DIALOG_SECONDS := 4.5
const FREEZE_BLACK_SECONDS := 1.5
## A memória do ciclo 346: o goblin riscando a parede, o corvo na boca da caverna e o glitch do
## fim (s); a hora (noite fechada) e a lenha da fogueira, para a parede pegar luz.
const MEMORY_CARVE_SECONDS := 9.0
const MEMORY_CROW_SECONDS := 4.5
const MEMORY_GLITCH_SECONDS := 1.6
const MEMORY_HOUR := 23.5
const MEMORY_FUEL := 3.0
## HUD vital: o oxigênio normal (%), quanto cai por segundo com o ar preso e quanto volta; a
## opacidade no Abrigo e na floresta (depois do R3, com a vida baixa).
const SPO2_NORMAL := 97.0
const SPO2_HOLD_DROP := 0.6
const SPO2_RECOVER := 2.0
const VITALS_HUD_ALPHA := 0.85
const VITALS_HUD_FOREST_ALPHA := 0.4
## Do Ato III em diante, o bipe do monitor fica sempre no fundo da caverna, baixinho (dB).
const LEAK_BEEP_STEADY_DB := -30.0
## Intervalo mínimo (s) entre duas falas do Zelador no Abrigo (o alto-falante dele).
const KEEPER_SPEECH_COOLDOWN := 8.0

# --- A verdade e os finais (§8) -----------------------------------------------------------------

## Na conversa, o Zelador para a esta distância de Ari (m) e espera ele chegar até este tempo (s)
## antes de falar de onde estiver; cada fala dura uma base mais um tanto por letra (s).
const KEEPER_TALK_DISTANCE := 1.8
const KEEPER_TALK_WAIT := 12.0
const KEEPER_LINE_SECONDS := 2.2
const KEEPER_LINE_PER_CHAR := 0.055
## Final 2: o Zelador segue Ari a esta distância (m), sem tocar nele, até a porta da saída. A porta
## blindada leva este tempo para subir (s).
const KEEPER_ESCORT_DISTANCE := 2.2
const EXIT_DOOR_SECONDS := 4.5
## Lá fora: a neblina da cidade (a mesma da floresta, um pouco mais densa), quando o sino começa
## (m andados desde a porta), e o reflexo no vidro (aparece a esta distância, m; fica na tela s).
const OUTSIDE_FOG_DENSITY := 0.03
const OUTSIDE_BELL_AFTER := 14.0
const REFLECTION_DISTANCE := 3.2
const REFLECTION_HOLD := 6.0
## Se Ari não chegar ao vidro, a cena acaba sozinha depois disto (s lá fora).
const OUTSIDE_TIMEOUT := 150.0
## Final 3: quanto dura a transferência do Zelador para a cápsula (s) e o preto antes de o jogo
## fechar sozinho (s).
const SWAP_SECONDS := 9.0
const SWAP_BLACK_SECONDS := 3.0
## Créditos: velocidade da rolagem (px/s) e quanto esperam antes de deixar pular (s).
const CREDITS_SPEED := 38.0
const CREDITS_SKIP_AFTER := 3.0
## Bem-vindo de volta (depois do Final 3): o goblin da IA. Atira de até esta distância (m), começa
## a chegar agachado nesta (m), segura a corda este tempo (s), come abaixo desta fome e volta para
## a pele nesta hora. Sem dormir, o fim vem depois destas horas de jogo.
const AUTOPILOT_SHOOT_RANGE := 14.0
const AUTOPILOT_STALK_RANGE := 32.0
const AUTOPILOT_DRAW_SECONDS := 1.1
const AUTOPILOT_EAT_BELOW := 40.0
const AUTOPILOT_SLEEP_HOUR := 19.5
## Esperando um bicho desconfiado se acalmar, depois disto (s) volta a se aproximar agachado.
const AUTOPILOT_WAIT_SECONDS := 6.0
const WELCOME_MAX_HOURS := 26.0

# --- Caça e vida na toca (F9, §8b) ---------------------------------------------------------------

## Chuva: chance de começar por hora de jogo, duração (h) e quanto tempo leva para entrar e sair (s).
const RAIN_CHANCE_PER_HOUR := 0.05
const RAIN_HOURS_MIN := 1.0
const RAIN_HOURS_MAX := 4.0
const RAIN_FADE_SECONDS := 25.0
## Na chuva cheia: o que os bichos ouvem e cheiram do goblin (fração do normal), o frio a mais por
## segundo fora do abrigo, quanto a neblina adensa e quanto a luz do céu cai.
const RAIN_HEARING := 0.5
const RAIN_SCENT := 0.5
const RAIN_COLD := 0.45
const RAIN_FOG := 0.6
const RAIN_DARK := 0.4
## Debaixo de árvore (copa de 0..1, Vegetation.canopy_at) a chuva quase não molha acima disto.
const CANOPY_SHELTER := 0.5

## Manadas (§8b-B): tamanho, quão espalhados pastam em volta do centro (m), a velocidade do centro
## andando pelo vale (m/s) e de quantas em quantas horas ele escolhe outro ponto de pasto.
const HERD_SIZE_MIN := 3
const HERD_SIZE_MAX := 4
const HERD_SPREAD := 9.0
const HERD_ROAM_SPEED := 0.23
const HERD_WAYPOINT_HOURS := Vector2(1.0, 2.5)
## A agenda da manada: sai de casa, volta para casa e deita para dormir (horas do dia).
const HERD_DAY_START := 6.0
const HERD_HOME_HOUR := 18.0
const HERD_SLEEP_HOUR := 20.0
## Longe assim do centro da manada (m), o cervo volta a andar até ela.
const HERD_REJOIN_DISTANCE := 25.0
## Dormindo, o bicho enxerga e ouve esta fração do normal.
const SLEEP_SIGHT := 0.1
const SLEEP_HEARING := 0.6
## Coelhos no vale e quão longe do goblin um bicho reposto pode nascer (m).
const RABBIT_COUNT := 10
const RESTOCK_MIN_DISTANCE := 60.0

## Caça (§8b-C): vida perdida por segundo para cada ponto de dano da ferida (correndo, vezes o fator).
const BLEED_PER_DAMAGE := 0.009
const BLEED_RUN_FACTOR := 1.6
## O corpo do cervo avisando: ergue a cabeça e as orelhas, e bate a pata e bufa (atenção 0..1).
const DEER_ALERT_AT := 0.12
const DEER_STOMP_AT := 0.6
## A mira com fôlego: até onde o arco da flecha é desenhado (m).
const AIM_GUIDE_MAX := 70.0
## Tocaia: quantas no mapa, o raio de dentro (m) e quanto se vê do goblin agachado nela.
const BLIND_MAX := 2
const BLIND_RADIUS := 1.3
const BLIND_VISIBILITY := 0.2

## Comida (§8b-D): quantos lugares de coleta e em quantos dias voltam a dar.
const FORAGE_MUSHROOMS := 28
const FORAGE_BERRIES := 14
const FORAGE_REGROW_DAYS := 2
## Horas até a carne estragar (crua e assada). A defumada não estraga.
const MEAT_SPOIL_HOURS := 36.0
const COOKED_SPOIL_HOURS := 72.0
## Defumador: horas de fogo aceso para defumar e quantos pedaços cabem.
const SMOKE_HOURS := 5.0
const SMOKE_RACK_SLOTS := 4

## Equipamento (§8b-E): dano da flecha de osso; o arco de teixo (velocidade da flecha e tremor).
const BONE_ARROW_DAMAGE := 1.5
const YEW_BOW_SPEED := 1.18
const YEW_BOW_TREMOR := 0.5
## Cama de peles: cura do sono vezes isto, e a fome do sono vezes aquilo.
const FUR_BED_HEAL := 1.6
const FUR_BED_SATIETY := 0.7
## Prática: segundos andando agachado e flechas acertadas para chegar a ~63% do ganho, e o ganho
## máximo (barulho a menos e tremor a menos).
const PRACTICE_STEALTH_SECONDS := 900.0
const PRACTICE_STEALTH_MAX := 0.3
const PRACTICE_HITS := 25.0
const PRACTICE_STEADY_MAX := 0.6
## Troféus na parede da caverna.
const TROPHY_MAX := 8

## O Velho: a partir de que dia e a chance de aparecer em cada amanhecer.
const OLD_DEER_FROM_DAY := 4
const OLD_DEER_CHANCE := 0.3
## Javali: quantos, a distância em que investe em vez de fugir (m), a velocidade da investida (m/s),
## o dano e quantas investidas antes de fugir.
const BOAR_COUNT := 3
const BOAR_CHARGE_RANGE := 7.0
const BOAR_CHARGE_SPEED := 5.7
const BOAR_DAMAGE := 22.0
const BOAR_CHARGES := 2

# --- Configurações (Settings) -------------------------------------------------------------------

## Padrões da tela de Configurações (o que "Restaurar padrão" devolve). Volumes de 0 a 1.
const SETTINGS_FULLSCREEN := false
const SETTINGS_VSYNC := true
## Escala da resolução 3D (1 = nativa; menos fica mais leve e mais pixelado) e os limites.
const SETTINGS_RENDER_SCALE := 1.0
const SETTINGS_RENDER_SCALE_RANGE := Vector2(0.5, 1.0)
## Limite de FPS (0 = sem limite) e as opções da lista.
const SETTINGS_MAX_FPS := 0
const SETTINGS_FPS_OPTIONS: Array[int] = [0, 30, 60, 90, 120, 144, 165, 240]
## Campo de visão da câmera do goblin em repouso (graus); mirando, fecha SETTINGS_AIM_FOV_DROP.
const SETTINGS_FOV := 65.0
const SETTINGS_FOV_RANGE := Vector2(55.0, 90.0)
const SETTINGS_AIM_FOV_DROP := 15.0
## Câmera espremida contra a parede: o goblin some em dither, pixel a pixel, do que está a
## CAMERA_FADE_FAR m da lente (inteiro) até CAMERA_FADE_NEAR (sumido). Com a lente a menos de
## CAMERA_HIDE_DISTANCE do meio do corpo, some de vez.
const CAMERA_FADE_NEAR := 0.3
const CAMERA_FADE_FAR := 0.85
const CAMERA_HIDE_DISTANCE := 0.4
## Brilho (gama sobre a imagem 3D: mais de 1 clareia as sombras).
const SETTINGS_BRIGHTNESS := 1.0
const SETTINGS_BRIGHTNESS_RANGE := Vector2(0.6, 1.6)
const SETTINGS_VOLUME := 1.0
## Sensibilidade do mouse (multiplica a do Player e a de Ari) e os limites.
const SETTINGS_MOUSE_SENSITIVITY := 1.0
const SETTINGS_MOUSE_SENSITIVITY_RANGE := Vector2(0.25, 3.0)
## Tamanho de avisos, prompt e legendas: as opções (escala da fonte) e o padrão (índice).
const SETTINGS_TEXT_SCALES: Array[float] = [1.0, 1.5, 2.0]
const SETTINGS_TEXT_SCALE := 0

# --- Bichos do ambiente (grilos, gafanhotos, pássaros, uivos) ---------------------------------------

## Insetos espalhados pelo capim (InsectField), sempre nos mesmos lugares. Grilos cantam de noite
## (cada um começa num ponto do anoitecer), gafanhotos de dia, em campo aberto.
const CRICKET_COUNT := 320
const GRASSHOPPER_COUNT := 220
## Até onde cada um se ouve sozinho (m) e quantos tocam de perto ao mesmo tempo; os de além disso
## viram o coro distante (o loop), no volume de quantos estão cantando de verdade lá.
const CRICKET_HEAR_RANGE := 28.0
const GRASSHOPPER_HEAR_RANGE := 20.0
const INSECT_VOICES := 14
const INSECT_CHORUS_RANGE := 90.0
## Com o goblin andando a menos disto (m), o inseto se cala; volta depois de INSECT_QUIET_SECONDS
## com ele longe. Um barulho (Events.noise_made) cala os que estão dentro do raio dele.
const CRICKET_QUIET_RADIUS := 4.5
const GRASSHOPPER_QUIET_RADIUS := 3.0
const INSECT_QUIET_SECONDS := Vector2(6.0, 16.0)
## O gafanhoto de perto do pé pula para longe (m).
const GRASSHOPPER_FLUSH_RADIUS := 1.6
const GRASSHOPPER_JUMP := Vector2(1.2, 2.6)

## Pássaros pousados nas árvores (BirdLife): canoros na copa das vivas, pica-paus no tronco das
## secas, corujas na mata fechada. Cada um canta do seu galho.
const SONGBIRD_COUNT := 40
const WOODPECKER_COUNT := 4
const OWL_COUNT := 4
## Segundos entre um canto e outro (sorteado na faixa); de madrugada o coro do amanhecer canta
## SONGBIRD_DAWN_BOOST vezes mais.
const SONGBIRD_SONG_GAP := Vector2(5.0, 16.0)
const SONGBIRD_DAWN_BOOST := 2.5
const WOODPECKER_DRUM_GAP := Vector2(14.0, 40.0)
const OWL_HOOT_GAP := Vector2(14.0, 45.0)
## O goblin a menos disto (m, no plano) espanta o pássaro, que voa para outra árvore e fica
## calado BIRD_SHY_SECONDS. Agachado e devagar, chega BIRD_CROUCH_FACTOR mais perto.
const BIRD_FLUSH_RADIUS := 4.0
const BIRD_CROUCH_FACTOR := 0.5
const BIRD_SHY_SECONDS := Vector2(12.0, 35.0)
## De tempos em tempos o pássaro troca de árvore sozinho (s).
const BIRD_WANDER_SECONDS := Vector2(40.0, 140.0)
## Só canta e se mexe perto do ouvido (m): longe disso não se ouviria mesmo.
const BIRD_ACTIVE_RANGE := 80.0

## Matilhas distantes (WolfPack): algumas noites ficam caladas. Peso de 0, 1, 2 e 3 rodadas por
## noite; cada rodada é um lobo de verdade (às vezes outros respondem) de um lado só, entre 21h e 4h.
const DISTANT_HOWL_WEIGHTS: Array[float] = [0.4, 0.35, 0.2, 0.05]
const DISTANT_HOWL_HOURS := Vector2(21.0, 28.0)
## Os lobos distantes ficam além da borda do vale, entre estes raios do centro do mapa (m), e a
## pelo menos DISTANT_HOWL_MIN_DISTANCE do goblin. Somem DISTANT_WOLF_SECONDS depois do uivo.
const DISTANT_HOWL_RING := Vector2(135.0, 180.0)
const DISTANT_HOWL_MIN_DISTANCE := 120.0
const DISTANT_WOLF_SECONDS := 60.0
## Chance de outro lobo responder a um uivo (no aviso da matilha e nas rodadas distantes; cada
## resposta distante pode puxar outra).
const HOWL_ANSWER := 0.45
## Chance de uma matilha distante responder ao uivo de aviso da matilha do vale.
const DISTANT_HOWL_REPLY := 0.35
