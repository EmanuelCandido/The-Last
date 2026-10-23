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
}
## Ordem em que o goblin escolhe o que comer.
const FOOD_PREFERENCE: Array[StringName] = [&"cooked_meat", &"meat"]
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
