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
##   &"blind": monta a tocaia aos pés do goblin; &"cairn": empilha um marco de pedras na frente dele).

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
]


## O que falta para fazer `recipe` (texto vazio = dá para fazer).
static func missing(recipe: Dictionary) -> String:
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


## Custo em texto ("1 madeira, 2 penas").
static func cost_text(recipe: Dictionary) -> String:
	var parts := PackedStringArray()
	for item: StringName in recipe.cost:
		var amount: int = recipe.cost[item]
		parts.append("%d %s" % [amount, item_word(item, amount)])
	return ", ".join(parts)


## Nome do item em minúscula, no singular ou plural.
static func item_word(item: StringName, amount: int) -> String:
	const WORDS := {
		&"wood": ["madeira", "madeiras"], &"feather": ["pena", "penas"], &"hide": ["couro", "couros"],
		&"stone": ["pedra", "pedras"], &"arrow": ["flecha", "flechas"], &"bone": ["osso", "ossos"],
	}
	var words: Array = WORDS.get(item, [String(Inventory.NAMES.get(item, item)).to_lower()])
	return words[1] if amount != 1 and words.size() > 1 else words[0]
