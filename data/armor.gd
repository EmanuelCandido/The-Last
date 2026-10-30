class_name Armor
extends RefCounted
## Armaduras e o escudo do goblin (F13, docs/plano_combate.md §5.2 e §5.3; experimental). Para criar,
## cortar ou mudar uma peça, edite esta lista; o Player, a MeleeAbility e a ArmorLook só a interpretam.
##
## Dois lugares no corpo: cabeça (&"head") e corpo (&"body"). O goblin veste, em cada lugar, a melhor
## peça que tem (a ordem de SLOTS); para tirar, é guardar no esconderijo. A roupa de couro (`clothes`)
## é a camada de baixo, contra o frio, e não ocupa lugar. Cada peça:
##   "slot": &"head" ou &"body"; "called": como os avisos falam dela;
##   "protect": quanto passa de cada tipo de golpe (1 = tudo, como sem nada), §3.6;
##   "noise": multiplica o barulho do goblin (os bichos ouvem antes);
##   "speed": multiplica a velocidade; "stamina": multiplica o fôlego que os golpes gastam;
##   "cold": multiplica o frio que entra (o ferro gela à noite).
## Armadura de ferro é luta; couro é caça.

const LIST := {
	&"leather_hood": {
		"slot": &"head", "called": "o capuz de couro",
		"protect": {&"cut": 0.8, &"pierce": 0.85, &"blunt": 0.9, &"bite": 0.8},
		"noise": 1.0, "speed": 1.0, "stamina": 1.0, "cold": 0.95,
	},
	&"skull_helm": {
		"slot": &"head", "called": "o elmo de crânio",
		"protect": {&"cut": 0.65, &"pierce": 0.7, &"blunt": 0.75, &"bite": 0.65},
		"noise": 1.03, "speed": 1.0, "stamina": 1.0, "cold": 1.0,
	},
	&"fitted_helmet": {
		"slot": &"head", "called": "o elmo orc",
		"protect": {&"cut": 0.45, &"pierce": 0.55, &"blunt": 0.85, &"bite": 0.45},
		"noise": 1.1, "speed": 1.0, "stamina": 1.0, "cold": 1.05,
	},
	&"leather_vest": {
		"slot": &"body", "called": "o gibão de couro",
		"protect": {&"cut": 0.7, &"pierce": 0.8, &"blunt": 0.9, &"bite": 0.65},
		"noise": 1.05, "speed": 1.0, "stamina": 1.05, "cold": 0.9,
	},
	&"fitted_chest": {
		"slot": &"body", "called": "o peitoral orc",
		"protect": {&"cut": 0.4, &"pierce": 0.6, &"blunt": 0.9, &"bite": 0.4},
		"noise": 1.2, "speed": 0.92, "stamina": 1.15, "cold": 1.2,
	},
}

## A melhor primeiro: em cada lugar, o goblin veste a primeira que tem.
const SLOTS := {
	&"head": [&"fitted_helmet", &"skull_helm", &"leather_hood"],
	&"body": [&"fitted_chest", &"leather_vest"],
}

## Quanto do golpe cai na cabeça (o resto, no corpo).
const HEAD_SHARE := 0.3

## O escudo: só com arma de uma mão. Segurando, passa menos dano e cansa menos; segura flecha.
const SHIELD := &"hide_shield"
const SHIELD_LEAK := 0.15
const SHIELD_STAMINA := 0.6
const SHIELD_WEAR := 30


static func spec(item: StringName) -> Dictionary:
	return LIST.get(item, {})


## A peça vestida em `slot` (&"" = nada).
static func worn(slot: StringName) -> StringName:
	for item: StringName in SLOTS.get(slot, []):
		if Inventory.has(item):
			return item
	return &""


## O escudo, se estiver em uso agora: tem o escudo e a arma na mão é de uma mão.
static func shield_in_use() -> StringName:
	var held := Inventory.held()
	if Inventory.has(SHIELD) and held != &"" and not Weapons.two_handed(held):
		return SHIELD
	return &""


## Quanto passa de um golpe do tipo `kind` pelo que o goblin veste (cabeça e corpo).
static func protection(kind: StringName) -> float:
	var head: float = spec(worn(&"head")).get("protect", {}).get(kind, 1.0)
	var body: float = spec(worn(&"body")).get("protect", {}).get(kind, 1.0)
	return HEAD_SHARE * head + (1.0 - HEAD_SHARE) * body


## O produto de `key` ("noise", "speed", "stamina", "cold") das peças vestidas.
static func factor(key: String) -> float:
	var value := 1.0
	for slot: StringName in SLOTS:
		value *= float(spec(worn(slot)).get(key, 1.0))
	return value
