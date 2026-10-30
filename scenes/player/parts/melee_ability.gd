class_name MeleeAbility
extends Node
## Luta de mão (F11, docs/plano_combate.md §3; experimental). Com uma arma na mão (Inventory.held):
## tocar o ataque dá o golpe leve, que encadeia até Tuning.COMBO_MAX; segurar Tuning.HEAVY_HOLD dá o
## forte, lento e pesado. Segurar a defesa (o botão de mirar) segura golpes de frente, gastando
## fôlego; erguida bem na hora (Tuning.PARRY_WINDOW antes do golpe), apara e atordoa quem bateu;
## com a lança, a defesa é a lança firmada, que recebe a investida do javali. A esquiva (C) pula
## de lado com um instante de invulnerabilidade, com ou sem arma. Tab troca o arco pelas armas.
##
## O fôlego e a postura não têm barra: sem fôlego o golpe sai lento e fraco e o goblin ofega; com
## postura demais ele cambaleia, e passando do limite cai sentado e levanta.
##
## Também recebe os golpes dos bichos (Player.receive_attack -> defend): esquiva, lança firmada,
## aparo, defesa ou o golpe cheio, com sangramento, tranco e queda.
##
## Parte do goblin: um nó filho do Player. Tirar o nó tira a luta (os golpes voltam direto à vida).

const SWING_SOUNDS := [
	preload("res://assets/audio/sfx/swing_1.wav"), preload("res://assets/audio/sfx/swing_2.wav"),
	preload("res://assets/audio/sfx/swing_3.wav"),
]
const BLOCK_SOUNDS := [preload("res://assets/audio/sfx/block_1.wav"), preload("res://assets/audio/sfx/block_2.wav")]
const PARRY_SOUND := preload("res://assets/audio/sfx/parry.wav")
const BREAK_SOUND := preload("res://assets/audio/sfx/weapon_break.wav")
const HIT_SOUNDS := Arrow.HIT_FLESH
## A trava suave: vira para o bicho mais perto dentro deste raio (m) e deste cone da câmera (graus).
const SOFT_LOCK_RANGE := 3.5
const SOFT_LOCK_CONE := 100.0

## Fôlego (0..1) e postura (0..; passa de Tuning.POISE_MAX e cambaleia).
var stamina := 1.0
var poise := 0.0
## Segurando a defesa agora (com a lança, firmada).
var guarding := false

## Segundos desde que a defesa subiu (o aparo é no começo).
var _guard_time := 0.0
var _iframes := 0.0
var _regen_wait := 0.0
## Segurando o ataque (segundos; -1 = solto): passando de HEAVY_HOLD sai o golpe forte.
var _hold := -1.0
## O golpe em andamento: {item, heavy, tired, active, closed} (vazio = nenhum).
var _swing := {}
var _combo := 0
var _queued := false
## Armas que já avisaram que estão rachando.
var _warned := {}
var _trace := WeaponTrace.new()
## Vida perdida na luta de agora (F14): passando de Tuning.FIGHT_HURT_LIMIT, a Vigilância sobe e a
## próxima visita ao Abrigo tem menos lucidez. Esquece depois de um minuto sem levar golpe.
var _fight_hurt := 0.0
var _fight_timer := 0.0

@onready var _player: Player = get_parent()


func _ready() -> void:
	# A lâmina do goblin não pega na área de acerto dele mesmo (F12).
	await get_tree().process_frame
	_trace.exclude = [_player.hitbox_rid()]


func _unhandled_input(event: InputEvent) -> void:
	if not _player.controls_on():
		return
	if event.is_action_pressed("weapon_swap"):
		get_viewport().set_input_as_handled()
		_swap()
		return
	if event.is_action_pressed("dodge"):
		get_viewport().set_input_as_handled()
		_dodge()
		return
	if Inventory.held() == &"":
		return
	if event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		if not _swing.is_empty():
			_queued = true
		elif _player.can_act():
			_hold = 0.0
	elif event.is_action_released("attack") and _hold >= 0.0:
		get_viewport().set_input_as_handled()
		_hold = -1.0
		_start_swing(false)


func _physics_process(delta: float) -> void:
	_iframes = maxf(_iframes - delta, 0.0)
	_fight_timer -= delta
	if _fight_timer <= 0.0:
		_fight_hurt = 0.0
	poise = maxf(poise - Tuning.POISE_DECAY * delta, 0.0)
	var animator := _player.animator()
	# Um golpe que outra ação cortou não volta: esquece.
	if not _swing.is_empty() and animator != null and not animator.is_busy():
		_cancel_swing()

	var want_guard := Inventory.held() != &"" and _player.controls_on() and _player.can_act() \
		and _swing.is_empty() and Input.is_action_pressed("aim")
	if want_guard and not guarding:
		_guard_time = 0.0
	guarding = want_guard
	if guarding:
		_guard_time += delta
		_player.speed_factors[&"guard"] = 0.5
	else:
		_player.speed_factors.erase(&"guard")

	if _hold >= 0.0:
		_hold += delta
		if not Input.is_action_pressed("attack"):
			_hold = -1.0
		elif _hold >= Tuning.HEAVY_HOLD:
			_hold = -1.0
			_start_swing(true)

	if guarding or not _swing.is_empty():
		_regen_wait = Tuning.STAMINA_REGEN_DELAY
	elif _regen_wait > 0.0:
		_regen_wait -= delta
	else:
		stamina = minf(stamina + Tuning.STAMINA_REGEN * delta, 1.0)
	if stamina < Tuning.LOW_STAMINA:
		_player.exert(0.75)

	if _swing.get("active", false):
		_sweep()


## Quanto fôlego falta para cansar (0 = sem fôlego). Para os roteiros e a interface.
func is_tired() -> bool:
	return stamina < Tuning.LOW_STAMINA


func is_swinging() -> bool:
	return not _swing.is_empty()


# --- Golpes do goblin ----------------------------------------------------------------

## `chained` = vem no fim do golpe anterior, que ainda ocupa o corpo.
func _start_swing(heavy: bool, chained := false) -> void:
	var item := Inventory.held()
	if item == &"":
		return
	if not chained and not _player.can_act():
		return
	var spec := Weapons.spec(item)
	var timing := Weapons.swing(item, heavy)
	var tired := stamina < Tuning.LOW_STAMINA
	var slow := Tuning.STAMINA_SLOW if tired else 1.0
	var duration: float = float(timing[0]) * slow
	var opens: float = float(timing[1]) * slow
	var closes: float = float(timing[2]) * slow
	stamina = maxf(stamina - float(spec.heavy_stamina if heavy else spec.stamina) * Armor.factor("stamina"), 0.0)
	_combo = 0 if heavy else _combo + 1
	var style := Weapons.style_of(item)
	var action := StringName("%s_heavy" % style) if heavy else StringName("%s_%d" % [style, 2 - _combo % 2])
	_swing = {"item": item, "heavy": heavy, "tired": tired, "active": false, "closed": false}
	_queued = false
	_player.face(_strike_direction())
	var animator := _player.animator()
	if animator != null:
		animator.strike_window = Vector2(opens, closes)
	_player.perform(action, duration, [[opens, _open], [closes, _close], [maxf(duration - 0.03, closes), _finish]])


## A janela abriu: a lâmina passa a acertar, o corpo vai um pouco para a frente e o ar assobia.
func _open() -> void:
	if _swing.is_empty():
		return
	_swing.active = true
	_trace.begin()
	_sweep()
	var heavy: bool = _swing.heavy
	_player.shove(_player.facing() * Tuning.SWING_LUNGE * (1.3 if heavy else 1.0), 0.12)
	OccludedAudio.play_at(_player, SWING_SOUNDS.pick_random(), _player.global_position + Vector3.UP * 0.6, &"World",
		-6.0 if heavy else -9.0, 3.0, randf_range(0.85, 1.1) * (0.85 if heavy else 1.0))
	Events.noise_made.emit(_player.global_position, Tuning.SWING_NOISE)


## A janela fechou. Se a lâmina não pegou em ninguém, pode ter pegado numa árvore.
func _close() -> void:
	if _swing.is_empty():
		return
	_sweep()
	_swing.active = false
	_swing.closed = true
	if not _trace.hit_anything():
		var reach: float = Weapons.spec(_swing.item).get("reach", 0.3)
		if _player.strike_tree(0.75 + reach):
			_wear(_swing.item, Tuning.WEAR_TREE)


## O golpe acabou: se o ataque foi apertado no meio dele, vem o próximo da sequência.
func _finish() -> void:
	if _swing.is_empty():
		return
	var chain := _queued and not bool(_swing.heavy) and _combo < Tuning.COMBO_MAX and Inventory.held() != &""
	_swing = {}
	if chain:
		_start_swing(false, true)
	else:
		_combo = 0
		_queued = false


func _cancel_swing() -> void:
	_swing = {}
	_queued = false
	_hold = -1.0
	_combo = 0


func _sweep() -> void:
	var segment := _player.weapon_segment()
	if segment.size() < 2 or _swing.is_empty():
		return
	for hit: Dictionary in _trace.sweep(_player.get_world_3d(), segment[0], segment[1]):
		_land(hit)


func _land(hit: Dictionary) -> void:
	var target: Node3D = hit.target
	var item: StringName = _swing.item
	var spec := Weapons.spec(item)
	var damage: float = spec.heavy if _swing.heavy else spec.light
	if _swing.tired:
		damage *= Tuning.STAMINA_WEAK
	# Quem não viu o goblin chegar (agachado, por trás) leva o golpe inteiro (§3.9).
	var unaware := false
	if target is Animal:
		unaware = (target as Animal).awareness < Animal.SUSPICIOUS
	elif target is Orc:
		unaware = (target as Orc).unaware()
	if unaware and _player.is_crouching():
		damage *= float(spec.get("stealth", 1.0))
	if target is Orc:
		# O orc sabe o tipo do golpe (armadura) e a postura (ajoelha).
		(target as Orc).strike(damage, spec.kind, hit.point, hit.direction, float(spec.heavy_poise if _swing.heavy else spec.poise))
	else:
		target.take_hit(0.5, hit.point, hit.direction, damage)
	OccludedAudio.play_at(Game.current_level if Game.current_level != null else _player, HIT_SOUNDS.pick_random(), hit.point, &"World", -2.0, 4.0, randf_range(0.85, 1.05))
	Events.noise_made.emit(hit.point, Tuning.MELEE_HIT_NOISE)
	_wear(item, 1.0)


## Para onde o golpe vai: o bicho mais perto na frente da câmera (a trava suave) ou a câmera.
func _strike_direction() -> Vector3:
	var aim := _player.aim_direction()
	aim.y = 0.0
	aim = aim.normalized() if aim.length_squared() > 0.0001 else _player.facing()
	var best := SOFT_LOCK_RANGE
	var direction := aim
	for node in get_tree().get_nodes_in_group(&"animals"):
		var animal := node as Animal
		if animal == null or animal.state == Animal.State.DEAD:
			continue
		var to := animal.global_position - _player.global_position
		to.y = 0.0
		var distance := to.length()
		if distance < best and distance > 0.01 and rad_to_deg(aim.angle_to(to / distance)) < SOFT_LOCK_CONE * 0.5:
			best = distance
			direction = to / distance
	return direction


## Gasta a arma em uso: avisa quando racha e quebra no fim.
func _wear(item: StringName, hits: float) -> void:
	var spec := Weapons.spec(item)
	if spec.is_empty():
		return
	var called := String(spec.get("called", spec.name))
	var title := called.left(1).to_upper() + called.substr(1)
	if Inventory.wear_down(item, hits / float(spec.wear)):
		OccludedAudio.play_at(_player, BREAK_SOUND, _player.global_position + Vector3.UP * 0.5, &"World", -3.0, 3.0)
		Events.notification_shown.emit("%s quebrou." % title)
		_warned.erase(item)
		_cancel_swing()
		return
	if Inventory.wear(item) > Tuning.WEAR_WARN:
		_warned.erase(item)
	elif not _warned.has(item):
		_warned[item] = true
		Events.notification_shown.emit("%s está rachando. Conserte na bancada." % title)


## O escudo segurou um golpe: gasta e, no fim, quebra.
func _wear_shield() -> void:
	if Inventory.wear_down(Armor.SHIELD, 1.0 / float(Armor.SHIELD_WEAR)):
		OccludedAudio.play_at(_player, BREAK_SOUND, _player.global_position + Vector3.UP * 0.5, &"World", -3.0, 3.0)
		Events.notification_shown.emit("O escudo quebrou.")


# --- Esquiva e troca de arma ---------------------------------------------------------

func _dodge() -> void:
	if stamina < 0.08:
		return
	var recovering: bool = not _swing.is_empty() and bool(_swing.closed)
	if not _player.can_act() and not recovering:
		return
	var direction := _player.move_direction()
	direction.y = 0.0
	direction = direction.normalized() if direction.length_squared() > 0.01 else -_player.facing()
	_cancel_swing()
	guarding = false
	stamina = maxf(stamina - Tuning.DODGE_STAMINA, 0.0)
	_regen_wait = Tuning.STAMINA_REGEN_DELAY
	_iframes = Tuning.DODGE_IFRAMES
	_player.perform(&"dodge", Tuning.DODGE_TIME + 0.1)
	_player.shove(direction * (Tuning.DODGE_DISTANCE / Tuning.DODGE_TIME), Tuning.DODGE_TIME)
	Events.noise_made.emit(_player.global_position, 3.0)


func _swap() -> void:
	if not _player.can_act():
		return
	var owned: Array[StringName] = []
	for item: StringName in Weapons.CYCLE:
		if item == &"" or Inventory.has(item):
			owned.append(item)
	if owned.size() <= 1:
		Events.notification_shown.emit("Nenhuma arma de mão. Faça uma faca, um porrete ou uma lança ({craft}).".format(Settings.key_labels()))
		return
	var next: StringName = owned[(owned.find(Inventory.held()) + 1) % owned.size()]
	_player.perform(&"equip", 0.55, [[0.28, _equip.bind(next)]])


func _equip(item: StringName) -> void:
	Inventory.hold(item)
	if item == &"":
		Events.notification_shown.emit("Arco na mão." if Inventory.has(&"bow") else "Mãos vazias.")
	else:
		Events.notification_shown.emit("Na mão: %s." % String(Weapons.spec(item).get("called", item)))


# --- Golpes no goblin ----------------------------------------------------------------

## O golpe de alguém chegou (ver Player.receive_attack). Devolve o que aconteceu.
func defend(attack: Dictionary) -> StringName:
	var damage := float(attack.get("damage", 0.0))
	var from: Vector3 = attack.get("from", _player.global_position)
	var push: Vector3 = attack.get("push", Vector3.ZERO)
	var attacker: Node = attack.get("attacker")
	var charge: bool = attack.get("charge", false)
	var gained := float(attack.get("poise", 0.3))
	if _iframes > 0.0:
		return &"dodged"
	var to := from - _player.global_position
	to.y = 0.0
	var away := to.normalized() if to.length_squared() > 0.0001 else _player.facing()
	var in_front := rad_to_deg(_player.facing().angle_to(away)) < Tuning.BLOCK_ARC_DEG * 0.5
	var item := Inventory.held()
	var spec := Weapons.spec(item)
	if guarding and in_front:
		if charge and spec.has("brace"):
			# A investida bate na ponta da lança firmada: quem se fere é o bicho.
			if attacker != null and attacker.has_method("take_hit"):
				attacker.take_hit(1.0, from + Vector3.UP * 0.5, -away, Tuning.SPEAR_BRACE_DAMAGE * float(spec.brace))
			stamina = maxf(stamina - 0.15, 0.0)
			OccludedAudio.play_at(_player, HIT_SOUNDS.pick_random(), from + Vector3.UP * 0.5, &"World", 0.0, 5.0, 0.8)
			_wear(item, 3.0)
			_player.shove(-away * 1.4, 0.15)
			return &"braced"
		if not charge and _guard_time <= Tuning.PARRY_WINDOW:
			if attacker != null and attacker.has_method("stagger"):
				attacker.stagger(Tuning.PARRY_STAGGER)
			stamina = minf(stamina + 0.1, 1.0)
			OccludedAudio.play_at(_player, PARRY_SOUND, _player.global_position + Vector3.UP * 0.6, &"World", -2.0, 4.0, randf_range(0.95, 1.05))
			Events.noise_made.emit(_player.global_position, Tuning.MELEE_HIT_NOISE)
			_wear(item, 0.5)
			return &"parried"
		# Com o escudo (F13) a defesa passa menos e cansa menos; quem gasta é o escudo.
		var shield := Armor.shield_in_use()
		var cost := damage * Tuning.BLOCK_STAMINA_PER_DAMAGE * (2.0 if charge else 1.0) * (Armor.SHIELD_STAMINA if shield != &"" else 1.0)
		if stamina >= cost:
			stamina -= cost
			_regen_wait = Tuning.STAMINA_REGEN_DELAY
			OccludedAudio.play_at(_player, BLOCK_SOUNDS.pick_random(), _player.global_position + Vector3.UP * 0.6, &"World", -3.0, 4.0, randf_range(0.9, 1.1))
			if shield != &"":
				_wear_shield()
			else:
				_wear(item, 1.0)
			var leak := Armor.SHIELD_LEAK if shield != &"" else Tuning.BLOCK_LEAK
			_take(damage * leak * (1.6 if charge else 1.0), attack, push * 0.5, gained * (1.0 if charge else 0.4) * (0.5 if shield != &"" else 1.0))
			return &"blocked"
		# Sem fôlego, a defesa cede: o golpe passa inteiro e derruba.
		stamina = 0.0
		guarding = false
		gained = Tuning.POISE_KNOCKDOWN
	_take(damage, attack, push, gained)
	return &"hit"


func _take(damage: float, attack: Dictionary, push: Vector3, gained: float) -> void:
	var kind: StringName = attack.get("kind", &"blunt")
	# A armadura vestida (F13): passa só uma parte, pelo tipo do golpe.
	damage *= Armor.protection(kind)
	Vitals.damage(damage, attack.get("cause", &"hit"))
	var before := _fight_hurt
	_fight_hurt += damage
	_fight_timer = 60.0
	if before < Tuning.FIGHT_HURT_LIMIT and _fight_hurt >= Tuning.FIGHT_HURT_LIMIT:
		Story.add_vigilance(Tuning.VIGILANCE_FIGHT_HURT)
		Story.set_flag(&"hard_fight_today")
	if (kind == &"cut" or kind == &"bite") and damage >= 5.0 and randf() < Tuning.BLEED_CHANCE:
		Vitals.bleed(Tuning.BLEED_SECONDS)
	poise += gained
	if Vitals.health > 0.0:
		if poise >= Tuning.POISE_KNOCKDOWN:
			_cancel_swing()
			guarding = false
			poise = 0.0
			_player.perform(&"knockdown", Tuning.KNOCKDOWN_TIME)
		elif poise >= Tuning.POISE_MAX:
			_cancel_swing()
			_player.perform(&"stagger", Tuning.STAGGER_TIME)
	# O tranco vem por último: a ação nova (cair, cambalear) zera a velocidade.
	if push != Vector3.ZERO:
		_player.shove(push, 0.25)
