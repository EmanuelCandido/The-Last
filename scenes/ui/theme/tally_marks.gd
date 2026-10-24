class_name TallyMarks
extends Control
## Os riscos da parede da caverna no cabeçalho dos menus: um por noite dormida neste ciclo
## (Story.marks; no menu principal, os do save), em grupos de quatro em pé com o quinto cortando
## na diagonal. Desenhados texel a texel a 2x, cor de osso com grão e a sombra de 1 texel, como
## as outras peças da interface. Contam de novo sempre que aparecem.

const PIXEL := 2.0
## Altura de um risco e o passo entre os riscos, entre os grupos e entre as linhas (texels).
const HEIGHT := 12
const STROKE_STEP := 4
const GROUP_STEP := 21
const ROW_STEP := 16
const PER_ROW := 6
const MAX_ROWS := 3
const BONE := Color8(214, 209, 194)
const SHADOW := Color8(6, 7, 7, 166)

var count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_recount()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_recount()


func _recount() -> void:
	count = mini(UiStyle.nights_marked(), PER_ROW * MAX_ROWS * 5)
	var groups := ceili(count / 5.0)
	var columns := mini(groups, PER_ROW)
	var rows := ceili(groups / float(PER_ROW))
	custom_minimum_size = Vector2(columns * GROUP_STEP - 4, rows * ROW_STEP - 3) * PIXEL if count > 0 else Vector2.ZERO
	# Sem riscos, o texto ao lado encosta na margem (o espaço entre os dois some).
	var row := get_parent() as HBoxContainer
	if row != null:
		row.add_theme_constant_override(&"separation", 28 if count > 0 else 0)
	queue_redraw()


func _draw() -> void:
	var texels: Array[Vector2i] = []
	for i in count:
		var group := i / 5
		var origin := Vector2i((group % PER_ROW) * GROUP_STEP, (group / PER_ROW) * ROW_STEP)
		var n := i % 5
		var h := _hash(i)
		if n < 4:
			# Em pé, de tamanho e prumo um pouco diferentes: um degrau de 1 texel no meio.
			var x := 1 + n * STROKE_STEP
			var top := h % 2
			var bottom := HEIGHT - 1 - (h / 2) % 2
			var jog := 3 + (h / 4) % 6
			var lean := 1 if (h / 32) % 2 == 0 else -1
			for y in range(top, bottom + 1):
				texels.append(origin + Vector2i(x + (lean if y < jog else 0), y))
		else:
			# O quinto corta os quatro, subindo da esquerda para a direita.
			texels.append_array(_line(origin + Vector2i(0, 9 - h % 2), origin + Vector2i(15, 2 + (h / 2) % 2)))
	for t in texels:
		draw_rect(Rect2((Vector2(t) + Vector2.ONE) * PIXEL, Vector2.ONE * PIXEL), SHADOW)
	for t in texels:
		# Grão: cada texel um pouco mais claro ou mais escuro.
		var shade := 0.88 + float(_hash(t.x * 131 + t.y * 977) % 13) * 0.012
		draw_rect(Rect2(Vector2(t) * PIXEL, Vector2.ONE * PIXEL), Color(BONE.r * shade, BONE.g * shade, BONE.b * shade))


## Bresenham de `a` até `b`, em texels.
static func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d := b - a
	var steps := maxi(absi(d.x), absi(d.y))
	for s in steps + 1:
		out.append(a + Vector2i(roundi(d.x * s / float(steps)), roundi(d.y * s / float(steps))))
	return out


## Número fixo por risco (o mesmo desenho toda vez que o menu abre).
static func _hash(n: int) -> int:
	var x := (n * 374761393 + 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return x ^ (x >> 16)
