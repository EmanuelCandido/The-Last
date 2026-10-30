class_name Recipes
extends RefCounted
## Receitas da lista de fabricar (R), §4.10. Para criar, cortar ou mudar uma receita,
## edite esta lista; a CraftAbility só a interpreta.
##
## Cada receita:
##   "id": nome curto (vai em Events.crafted e no contador "<id>_crafted" do Story);
##   "name": texto na lista;
##   "cost": {item: quantidade} que sai do inventário;
##   "gives": {item: quantidade} que entra;
##   "message": aviso ao terminar;
##   "once": true = só dá para ter uma (a roupa, vestida para sempre);
##   "special": algo que a CraftAbility faz além de dar itens (&"torch": acende a tocha na mão;
##   &"blind": monta a tocaia aos pés do goblin; &"cairn": empilha um marco de pedras na frente dele;
##   &"bench": monta a bancada da toca; &"repair": conserta a arma "item" que está em uso);
##   "station": &"bench" = só perto da bancada montada (F11);
##   "where": &"cave" = só dentro da caverna (F11).

const LIST: Array[Dictionary] = [
	{
		"id": &"arrows", "name": "Flechas (3)",
		"cost": {&"wood": 1}, "gives": {&"arrow": 3},
		"message": "+3 flechas",
	},
	{
		"id": &"feathered_arrows", "name": "Flechas emplumadas (3)",
		"cost": {&"wood": 1, &"feather": 2}, "gives": {&"feathered_arrow": 3},
		"message": "+3 flechas emplumadas: caem menos e ferem mais",
	},
	{
		"id": &"snare", "name": "Laço",
		"cost": {&"hide": 1, &"wood": 1}, "gives": {&"snare": 1},
		"message": "+1 laço. Arme sobre pegadas de coelho (E).",
	},
	{
		"id": &"clothes", "name": "Roupa de couro",
		"cost": {&"hide": 3}, "gives": {&"clothes": 1}, "once": true,
		"message": "Vestiu a roupa de couro: o frio pega menos.",
	},
	{
		"id": &"torch", "name": "Tocha",
		"cost": {&"wood": 1}, "gives": {}, "special": &"torch",
		"message": "Tocha acesa. Os bichos veem a luz de longe.",
	},
	# F9 (§8b): tocaia, pontas de osso, arco de teixo e cama de peles.
	{
		"id": &"blind", "name": "Tocaia de galhos",
		"cost": {&"wood": 3}, "gives": {}, "special": &"blind",
		"message": "Montou a tocaia. Agachado lá dentro, quase não o veem.",
	},
	{
		"id": &"bone_arrows", "name": "Flechas de osso (3)",
		"cost": {&"wood": 1, &"bone": 1}, "gives": {&"bone_arrow": 3},
		"message": "+3 flechas de osso: ferem mais fundo",
	},
	{
		"id": &"yew_bow", "name": "Arco de teixo",
		"cost": {&"wood": 3, &"hide": 1, &"bone": 2}, "gives": {&"yew_bow": 1}, "once": true,
		"message": "Arco de teixo: a flecha sai mais rápida e o braço treme menos.",
	},
	# F10: o marco de pedras, para achar o caminho de volta na neblina.
	{
		"id": &"cairn", "name": "Marco de pedras",
		"cost": {&"stone": 3}, "gives": {}, "special": &"cairn",
		"message": "Empilhou um marco de pedras. Na neblina, ele mostra o caminho.",
	},
	{
		"id": &"fur_bed", "name": "Cama de peles",
		"cost": {&"hide": 3}, "gives": {&"fur_bed": 1}, "once": true,
		"message": "Cama de peles na toca: o sono cura mais e dá menos fome.",
	},
	# F11 (plano_combate.md §6, experimental): armas de mão, a bancada e a cura.
	{
		"id": &"stone_knife", "name": "Faca de pedra",
		"cost": {&"stone": 1, &"wood": 1}, "gives": {&"stone_knife": 1},
		"message": "Faca de pedra pronta. [{weapon_swap}] põe na mão.",
	},
	{
		"id": &"club", "name": "Porrete",
		"cost": {&"wood": 2, &"stone": 1}, "gives": {&"club": 1},
		"message": "Porrete pronto: derruba e atordoa. [{weapon_swap}] põe na mão.",
	},
	{
		"id": &"spear", "name": "Lança",
		"cost": {&"wood": 2, &"stone": 1, &"sinew": 1}, "gives": {&"spear": 1},
		"message": "Lança pronta. Segure a defesa para firmá-la; {throw} arremessa.",
	},
	{
		"id": &"bandage", "name": "Bandagem de musgo",
		"cost": {&"moss": 2}, "gives": {&"bandage": 1},
		"message": "+1 bandagem. Sangrando, {eat} põe a bandagem.",
	},
	{
		"id": &"bench", "name": "Bancada da toca",
		"cost": {&"wood": 4, &"stone": 2}, "gives": {}, "special": &"bench", "where": &"cave",
		"message": "Montou a bancada. Perto dela dá para fazer e consertar mais coisas.",
	},
	{
		"id": &"bone_knife", "name": "Faca de osso",
		"cost": {&"bone": 2, &"sinew": 1}, "gives": {&"bone_knife": 1}, "station": &"bench",
		"message": "Faca de osso pronta: corta mais e dura mais.",
	},
	# F13: equipamento de guerra (bancada).
	{
		"id": &"hide_shield", "name": "Escudo de galhos",
		"cost": {&"wood": 3, &"hide": 1}, "gives": {&"hide_shield": 1}, "station": &"bench", "once": true,
		"message": "Escudo pronto: no braço esquerdo, com uma arma de uma mão. Defende melhor e segura flecha.",
	},
	{
		"id": &"leather_hood", "name": "Capuz de couro",
		"cost": {&"tanned_hide": 1}, "gives": {&"leather_hood": 1}, "station": &"bench", "once": true,
		"message": "Capuz de couro: a cabeça protegida, sem barulho.",
	},
	{
		"id": &"skull_helm", "name": "Elmo de crânio",
		"cost": {&"boar_skull": 1, &"sinew": 2}, "gives": {&"skull_helm": 1}, "station": &"bench", "once": true,
		"message": "Elmo de crânio de javali.",
	},
	{
		"id": &"leather_vest", "name": "Gibão de couro curtido",
		"cost": {&"tanned_hide": 2, &"sinew": 2}, "gives": {&"leather_vest": 1}, "station": &"bench", "once": true,
		"message": "Gibão de couro curtido: corte e mordida entram menos.",
	},
	{
		"id": &"fit_helmet", "name": "Ajustar o elmo orc",
		"cost": {&"orc_helmet": 1, &"hide": 1}, "gives": {&"fitted_helmet": 1}, "station": &"bench", "once": true,
		"message": "Elmo orc ajustado à cabeça do goblin. Ferro faz barulho.",
	},
	{
		"id": &"fit_chest", "name": "Ajustar o peitoral orc",
		"cost": {&"orc_chest": 1, &"sinew": 2}, "gives": {&"fitted_chest": 1}, "station": &"bench", "once": true,
		"message": "Peitoral orc ajustado. Protege muito, pesa, faz barulho e gela à noite.",
	},
	{
		"id": &"iron_arrows", "name": "Flechas de ferro (3)",
		"cost": {&"iron_scrap": 1, &"wood": 1}, "gives": {&"iron_arrow": 3}, "station": &"bench",
		"message": "+3 flechas de ferro: furam o ferro dos orcs.",
	},
	{
		"id": &"repair", "name": "Consertar a arma na mão",
		"cost": {}, "gives": {}, "special": &"repair", "station": &"bench",
		"message": "Arma consertada.",
	},
]


## O que falta para fazer `recipe` (texto vazio = dá para fazer).
static func missing(recipe: Dictionary) -> String:
	var player := Game.player
	if recipe.get("where", &"") == &"cave":
		var level := Game.current_level
		if player == null or level == null or not level.has_method("indoor_at") or not level.indoor_at(player.global_position):
			return "só dentro da toca"
		if recipe.get("special", &"") == &"bench" and not player.get_tree().get_nodes_in_group(Workbench.GROUP).any(
				func(node: Node) -> bool: return not (node as Workbench).built):
			return "já tem"
	if recipe.get("station", &"") == &"bench":
		if player == null or Workbench.near(player.get_tree(), player.global_position, Tuning.BENCH_RADIUS) == null:
			return "precisa da bancada"
	if recipe.get("special", &"") == &"repair":
		var weapon := Inventory.held()
		if weapon == &"":
			return "nenhuma arma na mão"
		if Inventory.wear(weapon) >= 0.999:
			return "não precisa"
		var parts: Dictionary = Weapons.spec(weapon).get("repair", {})
		for item: StringName in parts:
			var short: int = int(parts[item]) - Inventory.count(item)
			if short > 0:
				return "falta %d %s" % [short, item_word(item, short)]
		return ""
	if recipe.get("once", false):
		for item: StringName in recipe.gives:
			if Inventory.has(item):
				return "já tem"
	var lacking := PackedStringArray()
	for item: StringName in recipe.cost:
		var short: int = int(recipe.cost[item]) - Inventory.count(item)
		if short > 0:
			lacking.append("%d %s" % [short, item_word(item, short)])
	return "falta " + ", ".join(lacking) if not lacking.is_empty() else ""


## O que a receita gasta de verdade (o conserto gasta o material da arma na mão).
static func cost_of(recipe: Dictionary) -> Dictionary:
	if recipe.get("special", &"") == &"repair":
		return Weapons.spec(Inventory.held()).get("repair", {})
	return recipe.cost


## Custo em texto ("1 madeira, 2 penas").
static func cost_text(recipe: Dictionary) -> String:
	var parts := PackedStringArray()
	var cost := cost_of(recipe)
	for item: StringName in cost:
		var amount: int = cost[item]
		parts.append("%d %s" % [amount, item_word(item, amount)])
	return ", ".join(parts)


## Nome do item em minúscula, no singular ou plural.
static func item_word(item: StringName, amount: int) -> String:
	const WORDS := {
		&"wood": ["madeira", "madeiras"], &"feather": ["pena", "penas"], &"hide": ["couro", "couros"],
		&"stone": ["pedra", "pedras"], &"arrow": ["flecha", "flechas"], &"bone": ["osso", "ossos"],
		&"sinew": ["tendão", "tendões"], &"moss": ["musgo", "musgos"],
		&"tanned_hide": ["couro curtido", "couros curtidos"], &"iron_scrap": ["sucata", "sucatas"],
	}
	var words: Array = WORDS.get(item, [String(Inventory.NAMES.get(item, item)).to_lower()])
	return words[1] if amount != 1 and words.size() > 1 else words[0]
