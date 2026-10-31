class_name ForestLayout
extends RefCounted
## Pontos-chave do mapa da floresta. Tudo em metros; Vector2 é (x, z) no chão.
##
## Terreno, caverna, vegetação, bichos e som leem daqui, então mover um ponto
## aqui reorganiza o mapa inteiro de forma consistente.

## O terreno: um retângulo de TERRAIN_MIN a TERRAIN_MAX no chão. O vale da toca fica no meio da
## metade oeste; a leste, depois das montanhas e do desfiladeiro, o vale da Pedra Rachada (F14).
## As divisas dos blocos de 48 m caem em z = 0, -48, -96... (o vazio do norte corta numa delas).
const TERRAIN_MIN := Vector2(-192.0, -192.0)
const TERRAIN_MAX := Vector2(384.0, 192.0)
## Raio do vale jogável; depois disso o terreno sobe em montanhas.
const VALLEY_RADIUS := 110.0

## O vale da Pedra Rachada (F14): o dos orcs, sem bicho nenhum. Centro e raio do chão aberto.
const SECOND_VALLEY := Vector2(252.0, -18.0)
const SECOND_VALLEY_RADIUS := 50.0
## O desfiladeiro, o único caminho entre os dois vales: o eixo começa dentro da borda leste do vale
## da toca e termina dentro da borda oeste do outro; o chão tem 2 × GORGE_HALF_WIDTH de largura.
const GORGE_FROM := Vector2(96.0, -12.0)
const GORGE_TO := Vector2(208.0, -18.0)
const GORGE_HALF_WIDTH := 9.0
## A ravina que corta o desfiladeiro, a casa do troll: onde fica no eixo (0 = GORGE_FROM,
## 1 = GORGE_TO), a profundidade e a meia largura da boca. É funda do paredão sul até
## RAVINE_DEEP_TO de lado; dali o fundo sobe em rampa até RAVINE_RAMP_TO, e junto do paredão
## norte fica a passagem plana (lado positivo = norte, -Z).
const RAVINE_AT := 0.65
const RAVINE_DEPTH := 5.0
const RAVINE_HALF := 2.6
const RAVINE_DEEP_TO := -2.0
const RAVINE_RAMP_TO := 5.0
## Onde a passagem plana corre (de lado, no eixo do desfiladeiro).
const GORGE_LEDGE := 7.0

## Caverna: centro do salão. A boca fica virada para -Z (para o vale).
const CAVE_CENTER := Vector2(0.0, 72.0)
const CAVE_HALF_WIDTH := 3.6
const CAVE_HEIGHT := 4.2
const CAVE_DEPTH := 13.0
## Espessura da rocha da caverna.
const CAVE_WALL := 2.6

## Onde o goblin acorda: dentro da caverna, a poucos metros da saída.
const SPAWN := Vector2(1.0, 69.8)

## Onde a sentinela do Zelador fica pousada, ao lado da boca da caverna.
const CAVE_CROW := Vector2(2.8, 63.0)

## Árvore velha que solta folhas com o vento.
const OLD_TREE := Vector2(-9.0, 44.0)
## Clareira onde os cervos pastam.
const MEADOW := Vector2(30.0, 8.0)
const MEADOW_RADIUS := 18.0
## Ruína de pedra no fim da trilha.
const RUINS := Vector2(-18.0, -46.0)
## O acampamento dos orcs (F13; F14: no vale da Pedra Rachada): o lugar preferido; o OrcCamp
## procura o chão livre mais perto.
const ORC_CAMP := Vector2(262.0, -14.0)
## A casa de cada manada de cervos (§8b-B): onde ela volta no fim da tarde e dorme. De dia anda
## pelo vale todo.
const DEER_HOMES := [Vector2(42.0, -12.0), Vector2(-42.0, -22.0), Vector2(-52.0, 30.0), Vector2(50.0, 42.0), Vector2(14.0, -62.0)]
## Onde os javalis fuçam: mata fechada, longe da caverna.
const BOAR_HOMES := [Vector2(-66.0, -8.0), Vector2(64.0, 4.0), Vector2(30.0, -75.0)]
## Tocas dos coelhos: cada coelho vive em volta de uma.
const RABBIT_HOMES := [
	Vector2(4.0, 54.0), Vector2(-8.0, 30.0), Vector2(6.0, 18.0), Vector2(12.0, 40.0), Vector2(-6.0, -8.0),
	Vector2(30.0, -30.0), Vector2(-30.0, 8.0), Vector2(38.0, 20.0), Vector2(-24.0, -40.0), Vector2(20.0, 60.0),
	Vector2(-40.0, 50.0), Vector2(55.0, -30.0),
]

## Poças de lama ao lado da trilha (camuflagem, §4.11).
const MUD_SPOTS := [Vector2(-4.8, 51.0), Vector2(3.6, 21.0), Vector2(1.6, -5.0), Vector2(-13.5, -31.0)]
## Montes de pedras soltas (pedras para jogar, §4.11).
const STONE_PILES := [Vector2(3.4, 61.5), Vector2(-7.5, 40.0), Vector2(17.0, 13.0), Vector2(-6.0, -16.0)]

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


## `p` está perto do desfiladeiro (até `margin` m em volta da caixa dele): um teste barato antes
## das contas do eixo, que a geração do terreno faz em cada ponto.
static func near_gorge(p: Vector2, margin: float) -> bool:
	return p.x > minf(GORGE_FROM.x, GORGE_TO.x) - margin and p.x < maxf(GORGE_FROM.x, GORGE_TO.x) + margin \
		and p.y > minf(GORGE_FROM.y, GORGE_TO.y) - margin and p.y < maxf(GORGE_FROM.y, GORGE_TO.y) + margin


## O desfiladeiro em volta de `p`: x = quanto do eixo já andou (0 em GORGE_FROM, 1 em GORGE_TO,
## fora disso além das pontas), y = distância de lado (positiva ao norte, -Z).
static func gorge_frame(p: Vector2) -> Vector2:
	var axis := GORGE_TO - GORGE_FROM
	var side := Vector2(axis.y, -axis.x).normalized()
	return Vector2((p - GORGE_FROM).dot(axis) / axis.length_squared(), (p - GORGE_FROM).dot(side))


## O ponto do desfiladeiro em `t` do eixo e `side` metros de lado (positivo ao norte).
static func gorge_point(t: float, side: float) -> Vector2:
	var axis := GORGE_TO - GORGE_FROM
	return GORGE_FROM + axis * t + Vector2(axis.y, -axis.x).normalized() * side


## Distância de `p` até o eixo do desfiladeiro.
static func distance_to_gorge(p: Vector2) -> float:
	var axis := GORGE_TO - GORGE_FROM
	var t := clampf((p - GORGE_FROM).dot(axis) / axis.length_squared(), 0.0, 1.0)
	return p.distance_to(GORGE_FROM + axis * t)


## `p` está no chão do vale da Pedra Rachada, a pelo menos `margin` m da borda.
static func in_second_valley(p: Vector2, margin := 0.0) -> bool:
	return p.distance_to(SECOND_VALLEY) < SECOND_VALLEY_RADIUS - margin


## `p` está no desfiladeiro (entre as bocas, no chão).
static func in_gorge(p: Vector2) -> bool:
	var frame := gorge_frame(p)
	return frame.x > 0.0 and frame.x < 1.0 and absf(frame.y) < GORGE_HALF_WIDTH + 2.0


## O caminho pelo desfiladeiro que um orc anda (pela passagem plana, sem descer na ravina):
## `inward` = do vale da Pedra Rachada para o da toca.
static func gorge_path(inward: bool) -> Array[Vector2]:
	var around := (RAVINE_HALF + 6.0) / (GORGE_TO - GORGE_FROM).length()
	var path: Array[Vector2] = [
		GORGE_TO, gorge_point(RAVINE_AT + around, GORGE_LEDGE), gorge_point(RAVINE_AT - around, GORGE_LEDGE), GORGE_FROM,
	]
	if not inward:
		path.reverse()
	return path


## Onde fica a ravina no meio do eixo (a ponte passa por cima).
static func ravine_center() -> Vector2:
	return gorge_point(RAVINE_AT, 0.0)


## Quanto a ravina afunda o chão em `p` (m; 0 fora dela). A boca tem paredes a pique; no sentido
## do paredão norte o fundo sobe em rampa até o chão do desfiladeiro.
static func ravine_depth(p: Vector2) -> float:
	var frame := gorge_frame(p)
	if absf(frame.y) > GORGE_HALF_WIDTH + 12.0:
		return 0.0
	var along := (frame.x - RAVINE_AT) * (GORGE_TO - GORGE_FROM).length()
	var mouth := 1.0 - smoothstep(RAVINE_HALF - 0.7, RAVINE_HALF + 0.7, absf(along))
	var across := clampf((RAVINE_RAMP_TO - frame.y) / (RAVINE_RAMP_TO - RAVINE_DEEP_TO), 0.0, 1.0)
	# Ao sul, entra no paredão como uma fenda que some aos poucos.
	across *= 1.0 - smoothstep(GORGE_HALF_WIDTH + 3.0, GORGE_HALF_WIDTH + 12.0, -frame.y)
	return RAVINE_DEPTH * mouth * across


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
