class_name ForestLayout
extends RefCounted
## Pontos-chave do mapa da floresta. Tudo em metros; Vector2 é (x, z) no chão.
##
## Terreno, caverna, vegetação, bichos e som leem daqui, então mover um ponto
## aqui reorganiza o mapa inteiro de forma consistente.

## Lado do terreno (quadrado centrado na origem).
const TERRAIN_SIZE := 384.0
## Raio do vale jogável; depois disso o terreno sobe em montanhas.
const VALLEY_RADIUS := 110.0

## Caverna: centro do salão. A boca fica virada para -Z (para o vale).
const CAVE_CENTER := Vector2(0.0, 72.0)
const CAVE_HALF_WIDTH := 3.6
const CAVE_HEIGHT := 4.2
const CAVE_DEPTH := 13.0
## Espessura da rocha da caverna.
const CAVE_WALL := 2.6

## Onde o goblin acorda: dentro da caverna, a poucos metros da saída.
const SPAWN := Vector2(1.0, 69.8)

## Árvore velha que solta folhas com o vento.
const OLD_TREE := Vector2(-9.0, 44.0)
## Clareira onde os cervos pastam.
const MEADOW := Vector2(30.0, 8.0)
const MEADOW_RADIUS := 18.0
## Ruína de pedra no fim da trilha.
const RUINS := Vector2(-18.0, -46.0)

## Trilha de terra que sai da caverna e desce o vale.
const TRAIL := [
	Vector2(0.0, 64.0), Vector2(-2.0, 56.0), Vector2(-5.0, 48.0), Vector2(-4.0, 36.0),
	Vector2(1.0, 26.0), Vector2(5.0, 14.0), Vector2(4.0, 2.0), Vector2(-3.0, -12.0),
	Vector2(-10.0, -26.0), Vector2(-15.0, -38.0), Vector2(-18.0, -44.0),
]
const TRAIL_HALF_WIDTH := 1.3


## Distância de p até a trilha.
static func distance_to_trail(p: Vector2) -> float:
	var best := INF
	for i in TRAIL.size() - 1:
		var a: Vector2 = TRAIL[i]
		var b: Vector2 = TRAIL[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## Distância elíptica normalizada até a caverna: 1.0 encosta na face externa da rocha.
static func cave_ellipse(p: Vector2) -> float:
	var local := p - CAVE_CENTER
	return Vector2(local.x / (CAVE_HALF_WIDTH + CAVE_WALL), local.y / (CAVE_DEPTH * 0.5 + CAVE_WALL)).length()


## Quanto p está "dentro" da caverna: 0 do lado de fora, 1 a partir de ~2,5 m depois da boca.
static func cave_interior(p: Vector2) -> float:
	var local := p - CAVE_CENTER
	var mouth := -CAVE_DEPTH * 0.5
	var depth := smoothstep(mouth - 1.0, mouth + 2.5, local.y) * (1.0 - smoothstep(CAVE_DEPTH * 0.5, CAVE_DEPTH * 0.5 + 1.0, local.y))
	var side := 1.0 - smoothstep(CAVE_HALF_WIDTH, CAVE_HALF_WIDTH + 1.0, absf(local.x))
	return depth * side
