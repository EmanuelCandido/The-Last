class_name CaveStash
extends Node3D
## O esconderijo da toca (F13, docs/plano_combate.md §10.2; experimental): um nicho atrás de uma
## laje de pedra encostada na rocha, montado pela receita &"stash" (só dentro da caverna). E guarda
## tudo o que o goblin carrega (menos o arco e a roupa); agachado, E pega tudo de volta. O que está
## guardado não cai na bolsa da morte. É também o jeito de tirar a armadura: guardar.
## Filho da Cave (grupo "persist").

const GROUP := &"cave_stash"
const SOUND := preload("res://assets/audio/real/pickup_1.ogg")
## O que nunca vai para o esconderijo.
const KEEP: Array[StringName] = [&"bow", &"yew_bow", &"clothes", &"fur_bed"]

var built := false
## O que está guardado: {"items": {...}, "wear": {...}}.
var stored := {}

var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveSystem.PERSIST_GROUP)
	add_to_group(&"interactable")
	_build()
	_refresh()


func build_now() -> void:
	built = true
	_refresh()


func count() -> int:
	var total := 0
	var items: Dictionary = stored.get("items", {})
	for item: String in items:
		total += int(items[item])
	return total


func interaction_prompt() -> String:
	if not built:
		return ""
	var crouching := Game.player != null and Game.player.is_crouching()
	if crouching:
		return "Pegar tudo do esconderijo (%d)" % count() if count() > 0 else "Esconderijo vazio"
	return "Guardar tudo no esconderijo" + ("  ·  agachado: pegar (%d)" % count() if count() > 0 else "")


func interaction_enabled() -> bool:
	if not built:
		return false
	if Game.player != null and Game.player.is_crouching():
		return count() > 0
	return _carrying()


func interact(_player: Node) -> void:
	if Game.player != null and Game.player.is_crouching():
		BagField.give_back(stored)
		stored = {}
		Events.notification_shown.emit("Pegou tudo do esconderijo.")
	else:
		var content := _take()
		var items: Dictionary = stored.get("items", {})
		var wear: Dictionary = stored.get("wear", {})
		for item: String in content.items:
			items[item] = int(items.get(item, 0)) + int(content.items[item])
		for item: String in content.wear:
			var units: Array = wear.get(item, [])
			units.append_array(content.wear[item])
			wear[item] = units
		stored = {"items": items, "wear": wear}
		Events.notification_shown.emit("Guardou no esconderijo. Agachado, pega de volta.")
	OccludedAudio.play_at(self, SOUND, global_position + Vector3.UP * 0.3, &"World", -6.0, 2.5)


func _carrying() -> bool:
	for item: StringName in Inventory.items():
		if item not in KEEP and Inventory.count(item) > 0:
			return true
	return false


## Tira do goblin o que vai para o esconderijo (como a bolsa da morte, mas a armadura também).
func _take() -> Dictionary:
	var items := {}
	var wear := {}
	for item: StringName in Inventory.items():
		if item in KEEP:
			continue
		var amount := Inventory.count(item)
		if amount <= 0:
			continue
		if Weapons.is_weapon(item) or item == Armor.SHIELD:
			var units: Array = []
			for i in amount:
				units.append(Inventory.wear(item))
				Inventory.remove(item)
			wear[String(item)] = units
		else:
			Inventory.remove(item, amount)
		items[String(item)] = amount
	return {"items": items, "wear": wear}


func save_data() -> Dictionary:
	return {"built": built, "stored": stored.duplicate(true)}


func load_data(data: Dictionary) -> void:
	built = bool(data.get("built", false))
	stored = (data.get("stored", {}) as Dictionary).duplicate(true)
	_refresh()


func _refresh() -> void:
	if _mesh != null:
		_mesh.visible = built


## Uma laje encostada na rocha e, atrás dela, a ponta de um saco de couro.
func _build() -> void:
	var builder := TreeBuilder.Builder.new()
	var rock := builder.tool_for(Workbench._rock_material())
	var slab := BoxMesh.new()
	slab.size = Vector3(0.7, 0.75, 0.08)
	rock.append_from(slab, 0, Transform3D(Basis(Vector3.RIGHT, -0.28), Vector3(0.0, 0.36, 0.12)))
	var leather := builder.tool_for(ArmorLook._mat(GoblinLook.LEATHER, Color(0.65, 0.52, 0.4)))
	var sack := SphereMesh.new()
	sack.radius = 0.18
	sack.height = 0.3
	sack.radial_segments = 8
	sack.rings = 4
	leather.append_from(sack, 0, Transform3D(Basis.IDENTITY, Vector3(0.22, 0.14, -0.05)))
	_mesh = MeshInstance3D.new()
	_mesh.mesh = builder.commit()
	add_child(_mesh)
