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

## Um beat pediu um flash do mundo real (o Game mostra durante o sono ou a morte). `number`
## 0 = sorteado entre os já vistos.
signal flash_requested(number: int)

## Um beat pediu para Ari acordar no mundo real (o ritual, §4.9).
signal real_wake_requested

## Um beat pediu o falso travamento (§7): o próximo despertar no Abrigo começa com o jogo
## "travando" em vez do escurecer.
signal fake_freeze_requested

## Ari acordou no Abrigo (a floresta parou) / voltou a dormir na cápsula (a floresta voltou).
signal shelter_entered
signal shelter_left

## A floresta vai se desmanchar e o ciclo recomeça. `reason`: "vigilance", "white_meat"...
signal recycle_requested(reason: StringName)

## Uma flechada derrubou um corvo (os olhos do Zelador).
signal crow_shot

## O ritual de acordar terminou: prendeu o ar o bastante num lugar de ritual.
signal ritual_completed(place: StringName)

## O goblin fabricou algo da lista (R). `recipe`: o id em Recipes ("arrows", "clothes"...).
signal crafted(recipe: StringName)

## Um beat pediu um dos finais (§8): "stay", "wake" ou "swap" (quem faz a cena é o Endings).
signal ending_requested(ending: StringName)

## Uma partida começou de verdade (o menu principal fechou): o HUD volta a mostrar as dicas.
signal game_started
