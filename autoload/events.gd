extends Node
## Barramento de eventos global.
##
## Sistemas que não se conhecem conversam por aqui, sem referências diretas.
## Este arquivo só declara sinais: nada de estado ou lógica.

@warning_ignore_start("unused_signal")

## Uma fase acabou de ser instanciada dentro do LevelRoot.
signal level_loaded(level: Node3D)

## O jogo foi pausado ou despausado.
signal game_paused(paused: bool)

## Pede para a tela escurecer (alpha 1) ou clarear (alpha 0) em `duration` segundos.
signal screen_fade_requested(alpha: float, duration: float)

## Um barulho alto aconteceu (árvore caindo, flecha batendo): bichos em `radius` metros se assustam.
signal noise_made(position: Vector3, radius: float)

## Mensagem curta para o jogador ("+3 flechas", "Pegou o arco").
signal notification_shown(text: String)

## Texto da ação disponível agora ("[E] Pegar o arco"); vazio = nenhuma.
signal prompt_changed(text: String)

## O goblin dormiu uma noite na pele (a tela está escura; ainda não acordou).
signal slept

## O goblin começou a acordar na pele. `reason`: "sleep" (dormiu) ou "death" (morreu).
signal woke_up(reason: StringName)

## A vida acabou. `cause`: "hunger", "fall", "nausea"...
signal player_died(cause: StringName)

## O goblin coletou um bicho abatido. `kind`: "deer", "rabbit"...
signal animal_harvested(kind: StringName)

## O goblin comeu. `food`: o item do inventário ("meat", "cooked_meat").
signal ate(food: StringName)

## O goblin fabricou algo da lista (R). `recipe`: o id em Recipes ("arrows", "clothes"...).
signal crafted(recipe: StringName)
