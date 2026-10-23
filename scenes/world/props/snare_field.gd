class_name SnareField
extends Node3D
## Os laços armados pelo vale (§4.10), salvos com a partida (grupo "persist").
##
## Cada laço armado tem Tuning.SNARE_CHANCE de pegar um coelho em Tuning.SNARE_HOURS horas
## de jogo. O sorteio corre o tempo todo, mas só pega com o goblin longe
## (Tuning.SNARE_UNSEEN_DISTANCE), para ele não ver o coelho surgir; dormindo, as horas
## puladas contam de uma vez.

const GROUP := &"snare_field"

var terrain: Terrain


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveSystem.PERSIST_GROUP)
	Clock.skipped.connect(_on_time_skipped)


func _process(delta: float) -> void:
	if Game.resting or Game.player == null:
		return
	var chance := _chance_over(delta / Tuning.SECONDS_PER_HOUR)
	for snare in snares():
		if snare.state == Snare.State.ARMED and _unseen(snare) and randf() < chance:
			_catch(snare)


## Arma um laço em `at` (chão do mundo, x e z).
func place(at: Vector3, yaw := 0.0) -> Snare:
	var snare := Snare.new()
	add_child(snare)
	snare.global_position = Vector3(at.x, terrain.get_height(at.x, at.z), at.z)
	snare.rotation.y = yaw
	return snare


func snares() -> Array[Snare]:
	var found: Array[Snare] = []
	for child in get_children():
		if child is Snare and not child.is_queued_for_deletion():
			found.append(child)
	return found


## Para testes: pega um coelho agora no laço `snare`.
func catch_now(snare: Snare) -> void:
	_catch(snare)


func save_data() -> Dictionary:
	var list := []
	for snare in snares():
		list.append([snare.global_position.x, snare.global_position.z, snare.rotation.y, int(snare.state)])
	return {"snares": list}


func load_data(data: Dictionary) -> void:
	for snare in snares():
		if snare.rabbit != null and is_instance_valid(snare.rabbit):
			snare.rabbit.queue_free()
		snare.queue_free()
	for entry: Array in data.get("snares", []):
		if entry.size() < 4:
			continue
		var snare := place(Vector3(float(entry[0]), 0.0, float(entry[1])), float(entry[2]))
		match int(entry[3]):
			Snare.State.CAUGHT:
				_catch(snare, true)
			Snare.State.SPRUNG:
				snare.state = Snare.State.SPRUNG
				snare._show_state()


## Chance de pegar em `hours` horas, com Tuning.SNARE_CHANCE em Tuning.SNARE_HOURS.
static func _chance_over(hours: float) -> float:
	return 1.0 - pow(1.0 - Tuning.SNARE_CHANCE, hours / Tuning.SNARE_HOURS)


func _unseen(snare: Snare) -> bool:
	return Game.player.global_position.distance_to(snare.global_position) > Tuning.SNARE_UNSEEN_DISTANCE


func _catch(snare: Snare, quiet := false) -> void:
	var rabbit := Rabbit.new()
	get_parent().add_child(rabbit)
	var at := Vector2(snare.global_position.x, snare.global_position.z)
	rabbit.setup(terrain, at, randi())
	rabbit.position = snare.global_position + snare.global_basis.z * 0.12
	rabbit.rotation.y = snare.rotation.y + PI * 0.5
	rabbit.kill()
	snare.catch(rabbit, quiet)


func _on_time_skipped(hours: float) -> void:
	var chance := _chance_over(hours)
	for snare in snares():
		if snare.state == Snare.State.ARMED and randf() < chance:
			_catch(snare, true)
