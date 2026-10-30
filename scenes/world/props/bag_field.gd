class_name BagField
extends Node3D
## A bolsa da morte (F13, docs/plano_combate.md §10.1; experimental). Ao morrer, o que o goblin
## carregava e não estava vestido (comida, materiais, flechas, as armas, a da mão também) fica numa
## bolsa onde ele caiu; a armadura, a roupa, o escudo e o arco vão com ele. Se um orc estava perto,
## ele leva a bolsa para o baú do acampamento (OrcCamp). Senão ela fica no chão até o fim do dia
## seguinte e se perde. A fumaça da toca, os marcos e os troncos riscados viram o jeito de voltar.
##
## Filho da floresta (grupo "persist"): guarda a bolsa (lugar, itens, desgaste, dia) e monta o nó.

const GROUP := &"bag_field"
## O que fica com o goblin ao morrer.
const KEEP: Array[StringName] = [&"bow", &"yew_bow", &"clothes", &"fur_bed", &"hide_shield",
	&"leather_hood", &"skull_helm", &"fitted_helmet", &"leather_vest", &"fitted_chest"]

## A bolsa no chão: {"at": [x, y, z], "items": {...}, "wear": {...}, "day": n} (vazio = nenhuma).
var bag := {}
## O último aviso a dar quando o goblin acordar ("" = nenhum).
var _notice := ""
var _node: DroppedBag


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveSystem.PERSIST_GROUP)
	Events.player_died.connect(_on_died)
	Events.woke_up.connect(_on_woke)
	Clock.day_started.connect(_on_day)


## Tira do goblin o que vai na bolsa. Devolve {"items", "wear"}.
static func take_carried() -> Dictionary:
	var items := {}
	var wear := {}
	for item: StringName in Inventory.items():
		if item in KEEP or Armor.LIST.has(item):
			continue
		var amount := Inventory.count(item)
		if amount <= 0:
			continue
		if Weapons.is_weapon(item):
			var units: Array = []
			for i in amount:
				units.append(Inventory.wear(item))
				Inventory.remove(item)
			wear[String(item)] = units
		else:
			Inventory.remove(item, amount)
		items[String(item)] = amount
	return {"items": items, "wear": wear}


## Devolve ao goblin o que estava em `content` ({"items", "wear"}).
static func give_back(content: Dictionary) -> void:
	var items: Dictionary = content.get("items", {})
	var wear: Dictionary = content.get("wear", {})
	for item: String in items:
		var key := StringName(item)
		if wear.has(item):
			for worn: Variant in wear[item]:
				Inventory.add(key, 1, float(worn))
		else:
			Inventory.add(key, int(items[item]))


func _on_died(_cause: StringName) -> void:
	var player := Game.player
	if player == null or Game.welcome:
		return
	var content := take_carried()
	if (content.items as Dictionary).is_empty():
		return
	var orc := Orc.nearest(get_tree(), player.global_position, Tuning.ORC_LOOT_RANGE)
	var camp := get_tree().get_first_node_in_group(OrcCamp.GROUP) as OrcCamp
	if orc != null and camp != null:
		camp.store(content)
		_notice = "Os orcs levaram a sua bolsa para o acampamento da Pedra Rachada."
		Story.add_count(&"bag_taken", 1)
		return
	_clear()
	bag = content
	var at := player.global_position
	bag["at"] = [at.x, at.y, at.z]
	bag["day"] = Clock.day
	_build()
	_notice = "A bolsa ficou onde você caiu. Vá buscar antes que a floresta a engula."


func _on_woke(reason: StringName) -> void:
	if reason == &"death" and _notice != "":
		Events.notification_shown.emit(_notice)
	_notice = ""


## A bolsa se perde no começo do segundo dia depois da morte.
func _on_day(day: int) -> void:
	if not bag.is_empty() and day - int(bag.get("day", day)) >= 2:
		_clear()


## O goblin pegou a bolsa.
func pick_up() -> void:
	if bag.is_empty():
		return
	give_back(bag)
	_clear()
	Events.notification_shown.emit("Pegou a bolsa de volta.")


func _clear() -> void:
	bag = {}
	if _node != null and is_instance_valid(_node):
		_node.queue_free()
	_node = null


func _build() -> void:
	if bag.is_empty():
		return
	var at: Array = bag.get("at", [0.0, 0.0, 0.0])
	_node = DroppedBag.new()
	_node.field = self
	add_child(_node)
	_node.global_position = Vector3(float(at[0]), float(at[1]), float(at[2]))


func save_data() -> Dictionary:
	return {"bag": bag.duplicate(true)}


func load_data(data: Dictionary) -> void:
	_clear()
	bag = (data.get("bag", {}) as Dictionary).duplicate(true)
	_build()
