class_name Weapons
extends RefCounted
## Armas de mão do goblin (F11, docs/plano_combate.md §5). Para criar, cortar ou mudar uma arma,
## edite esta lista; a MeleeAbility, o PlayerGear e o animador só a interpretam.
##
## Dano na unidade da flechada (1,0 = uma flechada média, como em Animal.take_hit). Cada arma:
##   "name": texto na tela; "called": como os avisos falam dela ("a lança");
##   "hands": 1 ou 2 (a de duas mãos não deixa segurar a tocha);
##   "kind": &"cut" (corte), &"pierce" (perfuração) ou &"blunt" (impacto), §3.6;
##   "style": a família de golpes no animador (&"knife", &"club", &"spear");
##   "light"/"heavy": dano do golpe leve e do forte;
##   "reach": quanto a lâmina passa da mão (m); "length": tamanho da malha (m);
##   "stamina"/"heavy_stamina": fôlego que cada golpe gasta (0..1);
##   "poise"/"heavy_poise": quanto o golpe soma na postura de quem leva;
##   "speed": multiplica a velocidade dos golpes (> 1 = mais rápido);
##   "wear": quantos golpes a arma aguenta até quebrar;
##   "stealth": multiplica o dano num bicho que não viu o goblin (§3.9);
##   "repair": {item: quantidade} para consertar na bancada;
##   "brace": multiplica o dano da investida que bate na lança firmada (só a lança);
##   "throw": dá para arremessar com a tecla de jogar pedra.

const LIST := {
	&"stone_knife": {
		"name": "Faca de pedra", "called": "a faca de pedra", "hands": 1, "kind": &"cut", "style": &"knife",
		"light": 0.5, "heavy": 0.8, "reach": 0.2, "length": 0.24,
		"stamina": 0.1, "heavy_stamina": 0.22, "poise": 0.15, "heavy_poise": 0.35,
		"speed": 1.15, "wear": 60, "stealth": 4.0, "repair": {&"stone": 1},
	},
	&"bone_knife": {
		"name": "Faca de osso", "called": "a faca de osso", "hands": 1, "kind": &"cut", "style": &"knife",
		"light": 0.7, "heavy": 1.0, "reach": 0.22, "length": 0.27,
		"stamina": 0.1, "heavy_stamina": 0.22, "poise": 0.15, "heavy_poise": 0.35,
		"speed": 1.15, "wear": 90, "stealth": 4.0, "repair": {&"bone": 1},
	},
	&"club": {
		"name": "Porrete", "called": "o porrete", "hands": 1, "kind": &"blunt", "style": &"club",
		"light": 0.6, "heavy": 1.1, "reach": 0.42, "length": 0.5,
		"stamina": 0.16, "heavy_stamina": 0.32, "poise": 0.5, "heavy_poise": 1.0,
		"speed": 0.85, "wear": 80, "stealth": 2.0, "repair": {&"wood": 1},
	},
	&"spear": {
		"name": "Lança", "called": "a lança", "hands": 2, "kind": &"pierce", "style": &"spear",
		"light": 0.9, "heavy": 1.4, "reach": 0.8, "length": 1.15,
		"stamina": 0.14, "heavy_stamina": 0.28, "poise": 0.3, "heavy_poise": 0.6,
		"speed": 0.9, "wear": 70, "stealth": 3.0, "repair": {&"wood": 1},
		"brace": 3.0, "throw": true,
	},
	# F12: as armas dos orcs. Revistando o orc, o goblin fica com elas (gastas): para ele, o machado
	# é arma e ferramenta (derruba pinheiro vivo) e a espada, que para o orc é curta, pede as duas mãos.
	&"orc_axe": {
		"name": "Machado orc", "called": "o machado orc", "hands": 1, "kind": &"cut", "style": &"club",
		"light": 1.0, "heavy": 1.6, "reach": 0.4, "length": 0.55,
		"stamina": 0.18, "heavy_stamina": 0.34, "poise": 0.4, "heavy_poise": 0.8,
		"speed": 0.85, "wear": 70, "stealth": 3.0, "repair": {&"iron_scrap": 1}, "chop": true,
	},
	&"orc_sword": {
		"name": "Espada orc", "called": "a espada orc", "hands": 2, "kind": &"cut", "style": &"club",
		"light": 1.2, "heavy": 2.0, "reach": 0.6, "length": 0.72,
		"stamina": 0.24, "heavy_stamina": 0.42, "poise": 0.5, "heavy_poise": 1.0,
		"speed": 0.72, "wear": 90, "stealth": 3.0, "repair": {&"iron_scrap": 1},
	},
}

## Ordem em que a troca de arma (Tab) passa pelas armas; &"" é o arco (ou as mãos vazias).
const CYCLE: Array[StringName] = [&"", &"stone_knife", &"bone_knife", &"club", &"spear", &"orc_axe", &"orc_sword"]


static func is_weapon(item: StringName) -> bool:
	return LIST.has(item)


## A ficha da arma (vazia se não for arma).
static func spec(item: StringName) -> Dictionary:
	return LIST.get(item, {})


## A família de golpes da arma (&"" = sem arma de mão).
static func style_of(item: StringName) -> StringName:
	return LIST.get(item, {}).get("style", &"")


static func two_handed(item: StringName) -> bool:
	return int(LIST.get(item, {}).get("hands", 1)) == 2


## Tempo dos golpes de cada família: duração (s) e a janela em que a arma acerta (início, fim),
## antes de dividir pela "speed" da arma. O forte tem preparação longa: é a janela do outro.
const SWINGS := {
	&"knife": {"light": [0.5, 0.16, 0.28], "heavy": [0.85, 0.42, 0.56]},
	&"club": {"light": [0.62, 0.22, 0.36], "heavy": [1.05, 0.55, 0.7]},
	&"spear": {"light": [0.58, 0.2, 0.32], "heavy": [0.95, 0.5, 0.64]},
}


## [duração, começo da janela, fim da janela] do golpe, já com a velocidade da arma.
static func swing(item: StringName, heavy: bool) -> Array:
	var weapon := spec(item)
	var timing: Array = SWINGS.get(weapon.get("style", &"knife"), SWINGS[&"knife"])["heavy" if heavy else "light"]
	var speed: float = weapon.get("speed", 1.0)
	return [float(timing[0]) / speed, float(timing[1]) / speed, float(timing[2]) / speed]
