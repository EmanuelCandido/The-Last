class_name Practice
extends Node
## Aprender pela prática (§8b-E), sem barras: andar agachado ensina a pisar leve, acertar flechas
## firma o braço. A prática fica nos contadores do Story ("stealth_seconds" e "arrow_hits"), que
## vão no save e ficam na Reciclagem (o corpo lembra).
##
## O ganho cresce rápido no começo e vai parando (1 - e^(-x/k)): até Tuning.PRACTICE_STEALTH_MAX de
## barulho a menos (Player.noise_factors) e PRACTICE_STEADY_MAX de tremor a menos
## (Player.tremor_factors). Um aviso discreto a cada quarto do caminho.
##
## Parte do goblin: filho do Player. Tirar o nó tira a mecânica.

const STEALTH_WORDS := ["Os passos agachados ficaram mais leves.", "Pisa sem quebrar galho.", "Já anda agachado quase sem som.", "Anda como bicho do mato."]
const STEADY_WORDS := ["O braço do arco firmou um pouco.", "A mira treme menos.", "O braço já segura a corda firme.", "Atira como quem nasceu com o arco."]
const GUARD_WORDS := ["Já lê o golpe que vem.", "A defesa sobe na hora certa.", "Desvia golpe como quem desvia galho.", "Ninguém pega o goblin desprevenido."]
const SWING_WORDS := ["O braço cansa menos no golpe.", "Golpeia sem perder o fôlego.", "A arma já pesa pouco.", "Luta como quem nasceu brigando."]

var _player: Player
## Segundos andando agachado ainda não somados ao Story (soma de 1 em 1).
var _pending := 0.0


func _ready() -> void:
	_player = get_parent() as Player
	Events.arrow_hit.connect(_on_arrow_hit)
	# F11+: a prática de luta.
	Events.guard_held.connect(_on_guard)
	Events.melee_hit.connect(_on_melee_hit)
	_apply()


func _physics_process(delta: float) -> void:
	if not _player.is_crouching() or _player.velocity.length() < 0.3 or not _player.is_on_floor():
		return
	_pending += delta
	if _pending < 1.0:
		return
	_pending -= 1.0
	var before := stealth()
	Story.add_count(&"stealth_seconds")
	_announce(before, stealth(), STEALTH_WORDS)
	_apply()


## O quanto já aprendeu a pisar leve (0..1).
static func stealth() -> float:
	return 1.0 - exp(-Story.count(&"stealth_seconds") / Tuning.PRACTICE_STEALTH_SECONDS)


## O quanto o braço já firmou (0..1).
static func steadiness() -> float:
	return 1.0 - exp(-Story.count(&"arrow_hits") / Tuning.PRACTICE_HITS)


## O quanto já lê os golpes (0..1): alarga o aparo.
static func guard() -> float:
	return 1.0 - exp(-Story.count(&"guards_held") / Tuning.PRACTICE_GUARDS)


## O quanto o braço já aguenta golpear (0..1): o golpe gasta menos fôlego.
static func swing() -> float:
	return 1.0 - exp(-Story.count(&"melee_hits") / Tuning.PRACTICE_MELEE_HITS)


func _on_guard(_result: StringName) -> void:
	var before := guard()
	Story.add_count(&"guards_held")
	_announce(before, guard(), GUARD_WORDS)
	_apply()


func _on_melee_hit(_kind: StringName) -> void:
	var before := swing()
	Story.add_count(&"melee_hits")
	_announce(before, swing(), SWING_WORDS)
	_apply()


func _on_arrow_hit(_kind: StringName) -> void:
	var before := steadiness()
	Story.add_count(&"arrow_hits")
	_announce(before, steadiness(), STEADY_WORDS)
	_apply()


func _apply() -> void:
	_player.noise_factors[&"practice"] = 1.0 - Tuning.PRACTICE_STEALTH_MAX * stealth()
	_player.tremor_factors[&"practice"] = 1.0 - Tuning.PRACTICE_STEADY_MAX * steadiness()
	_player.parry_bonus = Tuning.PRACTICE_PARRY_MAX * guard()
	_player.swing_stamina = 1.0 - Tuning.PRACTICE_SWING_MAX * swing()


## Passou de um quarto do caminho para o outro: avisa.
func _announce(before: float, after: float, words: Array) -> void:
	var step := floori(after * 4.0 + 0.0001)
	if step > floori(before * 4.0 + 0.0001) and step >= 1:
		Events.notification_shown.emit(String(words[mini(step - 1, words.size() - 1)]))
