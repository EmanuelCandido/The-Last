extends Node
## Inventário simples: quantidade por item. Salvo junto com a partida.
## A carne estraga (F9): cada pedaço de carne crua e assada tem uma idade em horas de jogo
## (`_ages`, o mais velho primeiro). Comer ou gastar tira o mais velho; passando de
## Tuning.MEAT_SPOIL_HOURS (crua) ou COOKED_SPOIL_HOURS (assada), vira carne estragada. As horas
## correm com o relógio e o sono pula de uma vez (Clock.skipped).

signal changed(item: StringName, amount: int)

## Nome de cada item na tela.
const NAMES := {
	&"bow": "Arco",
	&"arrow": "Flechas",
	&"wood": "Madeira",
	&"meat": "Carne crua",
	&"cooked_meat": "Carne assada",
	&"hide": "Couro",
	&"clothes": "Roupa de couro",
	&"feathered_arrow": "Flechas emplumadas",
	&"feather": "Penas",
	&"stone": "Pedras",
	&"snare": "Laços",
	&"white_meat": "Carne branca",
	&"bone": "Ossos",
	&"bone_arrow": "Flechas de osso",
	&"berries": "Frutinhas",
	&"mushroom": "Cogumelos",
	&"smoked_meat": "Carne defumada",
	&"rotten_meat": "Carne estragada",
	&"yew_bow": "Arco de teixo",
	&"fur_bed": "Cama de peles",
}
## Ordem dos itens na linha do HUD (o que não está aqui não aparece: arco e roupa se veem no goblin).
const HUD_ORDER: Array[StringName] = [
	&"arrow", &"feathered_arrow", &"bone_arrow", &"stone", &"wood", &"meat", &"cooked_meat", &"smoked_meat",
	&"rotten_meat", &"berries", &"mushroom", &"white_meat", &"hide", &"bone", &"feather", &"snare",
]
## O que a carne vira quando estraga.
const SPOILS_INTO := &"rotten_meat"

var _items := {}
## Idade (horas de jogo) de cada pedaço dos itens que estragam, o mais velho primeiro.
var _ages := {}
var _last_hour := -1.0


func _ready() -> void:
	Clock.skipped.connect(age)


func _process(_delta: float) -> void:
	if Game.resting or Game.awake or Game.menu_open:
		_last_hour = Clock.hour
		return
	if _last_hour < 0.0:
		_last_hour = Clock.hour
		return
	var hours := Clock.hour - _last_hour
	if hours < 0.0:
		hours += 24.0
	_last_hour = Clock.hour
	if hours > 0.0 and hours < 1.0:
		age(hours)


## Em quantas horas `item` estraga (0 = não estraga).
static func spoil_hours(item: StringName) -> float:
	match item:
		&"meat":
			return Tuning.MEAT_SPOIL_HOURS
		&"cooked_meat":
			return Tuning.COOKED_SPOIL_HOURS
	return 0.0


## A idade do pedaço mais velho de `item` (horas; 0 sem nenhum).
func oldest_age(item: StringName) -> float:
	var ages: Array = _ages.get(item, [])
	return float(ages[0]) if not ages.is_empty() else 0.0


## Passaram `hours` horas: a carne envelhece e a que passou do ponto estraga.
func age(hours: float) -> void:
	for item: StringName in _ages.keys():
		var limit := spoil_hours(item)
		var ages: Array = _ages[item]
		_sync(item)
		var spoiled := 0
		for i in ages.size():
			ages[i] = float(ages[i]) + hours
			if float(ages[i]) >= limit:
				spoiled += 1
		if spoiled > 0:
			remove(item, spoiled)
			add(SPOILS_INTO, spoiled)
			Events.notification_shown.emit("%s estragou." % ("A carne crua" if item == &"meat" else "A carne assada"))


## Garante uma idade para cada pedaço (um save antigo não tinha idades: começam do zero).
func _sync(item: StringName) -> void:
	var ages: Array = _ages.get(item, [])
	while ages.size() < count(item):
		ages.append(0.0)
	while ages.size() > count(item):
		ages.pop_front()
	_ages[item] = ages


func count(item: StringName) -> int:
	return _items.get(item, 0)


func has(item: StringName, amount := 1) -> bool:
	return count(item) >= amount


func add(item: StringName, amount := 1) -> void:
	_items[item] = count(item) + amount
	if spoil_hours(item) > 0.0:
		var ages: Array = _ages.get(item, [])
		for i in amount:
			ages.append(0.0)
		_ages[item] = ages
	changed.emit(item, _items[item])


## Tira itens se houver o bastante. Devolve false (e não mexe em nada) se faltar.
func remove(item: StringName, amount := 1) -> bool:
	if not has(item, amount):
		return false
	_items[item] = count(item) - amount
	# Sai o mais velho primeiro (come a carne que vai estragar antes).
	if _ages.has(item):
		var ages: Array = _ages[item]
		for i in mini(amount, ages.size()):
			ages.pop_front()
	changed.emit(item, _items[item])
	return true


## Esvazia tudo (a Reciclagem).
func clear() -> void:
	var held := _items.keys()
	_items.clear()
	_ages.clear()
	for item: StringName in held:
		changed.emit(item, 0)


func items() -> Dictionary:
	return _items.duplicate()


func save_data() -> Dictionary:
	var data := {}
	for item: StringName in _items:
		data[String(item)] = _items[item]
	var ages := {}
	for item: StringName in _ages:
		ages[String(item)] = (_ages[item] as Array).duplicate()
	data["__ages"] = ages
	return data


func load_data(data: Dictionary) -> void:
	_items.clear()
	_ages.clear()
	for item: String in data:
		if item.begins_with("__"):
			continue
		_items[StringName(item)] = int(data[item])
	var ages: Dictionary = data.get("__ages", {})
	for item: String in ages:
		_ages[StringName(item)] = (ages[item] as Array).map(func(value: Variant) -> float: return float(value))
	for item: StringName in _items:
		if spoil_hours(item) > 0.0:
			_sync(item)
	for item: StringName in _items:
		changed.emit(item, _items[item])
