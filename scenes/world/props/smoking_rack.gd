class_name SmokingRack
extends Node3D
## O defumador (§8b-D): uma armação de galhos ao lado da fogueira da caverna, com uma vara onde a
## carne crua fica pendurada na fumaça. Cabem Tuning.SMOKE_RACK_SLOTS pedaços; com o fogo aceso,
## cada um fica pronto em Tuning.SMOKE_HOURS horas de jogo e vira carne defumada, que não estraga.
## Dormindo, conta o tempo em que a lenha durou. A carne pendurada não estraga.
## Filho da Cave (grupo "persist").

const HANG_SOUND := preload("res://assets/audio/real/pickup_2.ogg")
const RAW := Color(0.55, 0.16, 0.13)
const SMOKED := Color(0.24, 0.12, 0.07)

var campfire: Campfire
## Horas de fumaça de cada pedaço pendurado.
var pieces: Array[float] = []

var _meats: Array[MeshInstance3D] = []
var _last_fuel := 0.0


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(SaveSystem.PERSIST_GROUP)
	_build()
	Clock.skipped.connect(_on_skipped)


func _process(delta: float) -> void:
	if campfire == null:
		return
	_last_fuel = campfire.fuel
	if campfire.is_lit() and not Game.resting and not Game.awake:
		for i in pieces.size():
			pieces[i] = minf(pieces[i] + delta / Tuning.SECONDS_PER_HOUR, Tuning.SMOKE_HOURS)
	_refresh()


func ready_count() -> int:
	return pieces.filter(func(hours: float) -> bool: return hours >= Tuning.SMOKE_HOURS).size()


func interaction_prompt() -> String:
	if ready_count() > 0:
		return "Pegar carne defumada (%d)" % ready_count()
	if Inventory.has(&"meat") and pieces.size() < Tuning.SMOKE_RACK_SLOTS:
		return "Pendurar carne para defumar"
	if not pieces.is_empty():
		var left: float = Tuning.SMOKE_HOURS - float(pieces.max())
		return "Defumando: falta %d h%s" % [ceili(left), "" if campfire != null and campfire.is_lit() else " (fogo apagado)"]
	return "Defumador: pendure carne crua"


func interaction_enabled() -> bool:
	return ready_count() > 0 or (Inventory.has(&"meat") and pieces.size() < Tuning.SMOKE_RACK_SLOTS)


func interact(_player: Node) -> void:
	var done := ready_count()
	if done > 0:
		pieces = pieces.filter(func(hours: float) -> bool: return hours < Tuning.SMOKE_HOURS)
		Inventory.add(&"smoked_meat", done)
		Events.notification_shown.emit("+%d carne defumada" % done)
	elif Inventory.has(&"meat") and pieces.size() < Tuning.SMOKE_RACK_SLOTS:
		# Pendura o quanto couber de uma vez.
		var hung := mini(Inventory.count(&"meat"), Tuning.SMOKE_RACK_SLOTS - pieces.size())
		Inventory.remove(&"meat", hung)
		for i in hung:
			pieces.append(0.0)
		Events.notification_shown.emit("Pendurou %d pedaço%s. Mantenha o fogo aceso." % [hung, "s" if hung > 1 else ""])
	OccludedAudio.play_at(self, HANG_SOUND, global_position + Vector3.UP * 0.9, &"World", -6.0, 2.5)
	_refresh()


## O goblin dormiu: a fumaça contou enquanto a lenha durou.
func _on_skipped(hours: float) -> void:
	var lit_hours := minf(hours, _last_fuel * Tuning.FIRE_SECONDS_PER_FUEL / Tuning.SECONDS_PER_HOUR)
	for i in pieces.size():
		pieces[i] = minf(pieces[i] + lit_hours, Tuning.SMOKE_HOURS)
	_refresh()


func _refresh() -> void:
	for i in _meats.size():
		var meat := _meats[i]
		meat.visible = i < pieces.size()
		if meat.visible:
			var done := pieces[i] / Tuning.SMOKE_HOURS
			(meat.material_override as StandardMaterial3D).albedo_color = RAW.lerp(SMOKED, done)


## Dois cavaletes de galho e a vara de um a outro, com os ganchos para a carne.
func _build() -> void:
	var bark := Animal.flat_material(Color(0.26, 0.19, 0.13))
	for side: float in [-0.55, 0.55]:
		for lean: float in [-0.28, 0.28]:
			var leg := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.045, 1.25, 0.045)
			leg.mesh = box
			leg.material_override = bark
			leg.position = Vector3(side, 0.58, 0.0)
			leg.rotation.z = lean
			add_child(leg)
	var bar := MeshInstance3D.new()
	var rod := BoxMesh.new()
	rod.size = Vector3(1.3, 0.04, 0.04)
	bar.mesh = rod
	bar.material_override = bark
	bar.position = Vector3(0.0, 1.12, 0.0)
	add_child(bar)
	for i in Tuning.SMOKE_RACK_SLOTS:
		var meat := MeatMesh.instance(false)
		meat.scale = Vector3(1.6, 2.2, 1.6)
		meat.position = Vector3(-0.42 + i * 0.28, 0.95, 0.0)
		meat.material_override = (meat.material_override as StandardMaterial3D).duplicate()
		meat.visible = false
		add_child(meat)
		_meats.append(meat)


func save_data() -> Dictionary:
	return {"pieces": pieces.duplicate()}


func load_data(data: Dictionary) -> void:
	pieces.clear()
	for hours: Variant in data.get("pieces", []):
		pieces.append(float(hours))
	_refresh()
