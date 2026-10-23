extends Node
## Inventário simples: quantidade por item. Salvo junto com a partida.

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
}
## Ordem dos itens na linha do HUD (o que não está aqui não aparece: arco e roupa se veem no goblin).
const HUD_ORDER: Array[StringName] = [&"arrow", &"feathered_arrow", &"stone", &"wood", &"meat", &"cooked_meat", &"white_meat", &"hide", &"feather", &"snare"]

var _items := {}


func count(item: StringName) -> int:
	return _items.get(item, 0)


func has(item: StringName, amount := 1) -> bool:
	return count(item) >= amount


func add(item: StringName, amount := 1) -> void:
	_items[item] = count(item) + amount
	changed.emit(item, _items[item])


## Tira itens se houver o bastante. Devolve false (e não mexe em nada) se faltar.
func remove(item: StringName, amount := 1) -> bool:
	if not has(item, amount):
		return false
	_items[item] = count(item) - amount
	changed.emit(item, _items[item])
	return true


## Esvazia tudo (a Reciclagem).
func clear() -> void:
	var held := _items.keys()
	_items.clear()
	for item: StringName in held:
		changed.emit(item, 0)


func items() -> Dictionary:
	return _items.duplicate()


func save_data() -> Dictionary:
	var data := {}
	for item: StringName in _items:
		data[String(item)] = _items[item]
	return data


func load_data(data: Dictionary) -> void:
	_items.clear()
	for item: String in data:
		_items[StringName(item)] = int(data[item])
	for item: StringName in _items:
		changed.emit(item, _items[item])
