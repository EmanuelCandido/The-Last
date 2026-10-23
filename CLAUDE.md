# Jogo Pessoal

RPG medieval em terceira pessoa feito em **Godot 4.7.1 + GDScript**, desenvolvido com o Claude. O jogador é um **goblin**: acorda numa caverna, pega um arco e caça na floresta.

- **Estilo visual: "realista retrô".** Céu nublado, neblina densa, paleta dessaturada e texturas pixeladas (filtro nearest), inclusive no goblin. A referência é uma cidade abandonada sob neblina, só que medieval.
- **Imersão em primeiro lugar.** O vento varia no espaço e bate forte só em alguns lugares. O som se propaga em 3D, com abafamento atrás de rocha e eco. A caça é crível (os bichos veem, ouvem e farejam) e o HUD some sozinho.
- **Meta: leve.** Quase tudo é procedural (terreno, árvores, texturas e sons), com instancing e distâncias de desenho.

Configuração: Forward+, física 3D Jolt, resolução base 1280×720.

Godot (versão console, mostra a saída no terminal):
`C:\Users\emano\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`

## Comandos (PowerShell, na raiz do projeto)

```powershell
$godot = "C:\Users\emano\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"

& $godot --headless --path . --import                                   # importa assets e gera .uid
& $godot --headless --path . --fixed-fps 60 -- --frames=60 --skip-intro # teste de fumaça
& $godot --headless --path . --fixed-fps 60 -- --frames=180 --skip-intro --hold=move_forward
& $godot --headless --path . --fixed-fps 60 -- --frames=5 --skip-intro --run=C:/caminho/roteiro.gd
& $godot --path . -- --frames=150 --skip-intro --teleport=14,12 --camera=-80,-6 --give=bow:1,arrow:6 --hold=aim --screenshot=C:/caminho/print.png
& $godot --path . -e                                                    # abre o editor
python tools/generate_textures.py                                       # regera assets/textures/*.png
python tools/generate_sounds.py                                         # regera assets/audio/**/*.wav
```

- **Argumentos do DevTools** (depois de `--`), documentados em `autoload/dev_tools.gd`:
  - `--frames`, `--hold`, `--press`, `--give`;
  - `--load`, `--save`, `--pause`, `--tips`;
  - `--screenshot`, `--skip-intro`, `--teleport=x,z`, `--camera=yaw,pitch`;
  - `--set=story.act:2,story.flag:moss_fell,vitals.satiety:10,clock.hour:19` (põe o estado global em qualquer ponto);
  - `--run=roteiro.gd`.
- **`--run`:** recebe um `RefCounted` com `func run() -> void` (pode usar `await`). É o jeito de testar mecânicas de ponta a ponta: pegar o arco, quebrar árvore, caçar, furtividade, assar, dormir, farejar, jogar pedra, fabricar.
- Roteiros que dormem salvam de verdade em `%APPDATA%/Godot/app_userdata/Jogo Pessoal/save.json`. Apague esse save depois do teste.
- **`--press`** gera eventos de ação de verdade. `--hold` só segura a ação e não dispara `_unhandled_input`, então E, R e o soco precisam de `--press`.
- `--fixed-fps 60` deixa o teste determinístico: 60 frames equivalem a 1 s de jogo. Os bichos nascem com semente aleatória.
- Depois de mexer em scripts ou cenas, rode o teste de fumaça. Erros aparecem como `SCRIPT ERROR`, `Parse Error` ou `ERROR:`.
- Mudança visual só está pronta depois de tirar um print e olhar a imagem.
- "N resources still in use at exit" com AudioStream é só som tocando quando o teste fecha. Pode ignorar.
- Texturas novas: depois da primeira importação, edite o `.png.import` com `compress/mode=0`, `mipmaps/generate=true` e `detect_3d/compress_to=0`, e importe de novo. Sem mipmaps, o filtro nearest cintila à distância.

## Estrutura

```
docs/                roteiro.md (rascunho) e plano.md (plano fechado de história e mecânicas, em fases)
data/                tuning.gd (todos os números de ajuste), story_beats.gd (acontecimentos da história) e recipes.gd (receitas)
autoload/            Events, Wind, Inventory, Clock, Vitals, Story, Game, SaveSystem, DevTools
scenes/
  main/              cena raiz: LevelRoot + UI (HUD, ScreenFade, PauseMenu)
  player/            goblin: player.gd (movimento, arco, soco, interação), goblin_animator.gd
                     (animação procedural no esqueleto) e goblin_look.gd (texturas)
  player/parts/      mecânicas novas do goblin como nós filhos: EatAbility (F), BodyFeedback (fome), ColdExposure (frio),
                     SniffAbility (X), BreathControl (Q), StoneThrow (G), MudCamouflage, CraftAbility (R), TorchCarry,
                     SnareSetter e LeatherClothes
  items/             arco (pickup na caverna), HeldBow (arco na mão, corda que puxa), flecha (projétil), pedra jogada,
                     tocha, BowMesh e MeatMesh (malhas)
  levels/forest/     fase da floresta: forest.tscn/gd e ForestLayout (pontos-chave do mapa)
  levels/test_level/ fase de teste antiga (blocos CSG)
  world/terrain/     Terrain: relevo, malha em blocos, HeightMapShape3D, mapa de abrigo do vento
  world/cave/        Cave: casca de rocha procedural + fogueira, pele de dormir, riscos na parede (WallMarks), arco, gotejamento
  world/vegetation/  TreeBuilder (malhas por código) e Vegetation (espalha, instancia, derruba árvores)
  world/props/       fogueira (lenha, assar), folhas caindo, monte de pedras, poça de lama, laço (Snare e SnareField)
  world/tracks/      Tracks: pegadas dos bichos (MultiMesh)
  world/ambience/    Ambience: vento 3D, folhas nas árvores, chamados de bichos (de dia e de noite)
  world/day_night/   DayNight: sol, céu e neblina pela hora (Clock.night)
  animals/           Animal (sentidos, fuga, ferimento, caça), Deer, Rabbit, CrowFlock e Crow, Wolf e WolfPack
  ui/                HUD (ação, avisos, itens, mira), menu de pausa (com Dicas), ScreenFade
components/          Footsteps (passos por chão), OccludedAudio (som 3D abafado atrás de rocha)
assets/
  textures/ shaders/ gerados por tools/ (exceto shaders)
  audio/             sintéticos gerados por tools/; audio/real/ = gravações reais CC0 (ver CREDITS.md)
  models/goblin/     goblin.glb + source/ (goblin.blend, polish_goblin.py, export_goblin.py)
tools/               geradores Python de texturas e sons (numpy + Pillow)
```

## Arquitetura

- **Main** passa o `LevelRoot` para o `Game` e carrega `Game.FIRST_LEVEL` (a floresta).
- **Game:** `change_level(path)` troca a fase e cria o jogador no `PlayerSpawn`. Também cuida da pausa e do mouse.
- **Events:** só sinais.
  - `level_loaded`, `game_paused`, `screen_fade_requested`;
  - `noise_made(pos, raio)`: barulho que assusta bichos;
  - `notification_shown`: avisos na tela;
  - `prompt_changed`: ação disponível agora.
- **Inventory:** quantidade por item (`bow`, `arrow`, `feathered_arrow`, `wood`, `stone`, `meat`, `cooked_meat`, `hide`, `feather`, `snare`, `clothes`). Emite `changed` e vai junto no save. `Inventory.HUD_ORDER` diz o que aparece no HUD.
- **Plano e maleabilidade:** `docs/plano.md` é a fonte da história e das mecânicas, dividida em fases (F1 a F3 feitas). Receitas ficam em `Recipes` (`data/recipes.gd`). Números ficam em `Tuning` (`data/tuning.gd`), nunca soltos no código. Acontecimentos da história ficam em `StoryBeats` (`data/story_beats.gd`): cada beat tem gatilho (`on`), condições (`when`) e ações (`do`). Os sistemas reagem a flags (`Story.flag_changed`), sem saber qual beat as ligou.
- **Story:** ato, ciclo (347), riscos deste ciclo (`marks`) e antigos (`old_marks`), flags, contadores (`deer_harvested`...) e anotações (`notes`, que viram a seção ANOTAÇÕES das Dicas). Avalia os beats quando acontece `start`, `slept`, `woke`, `died`, `harvested` ou `ate`.
- **Clock:** dia e hora (1 h de jogo = 60 s). Para enquanto `Game.resting`. Dormir pula o tempo de uma vez e emite `skipped(horas)` (a fogueira queima a lenha, a matilha some). `night()` vai de 0 (dia) a 1 (noite fechada, 20h30–5h), suave no anoitecer e no amanhecer.
- **Dia e noite (`DayNight`):** sol, cor e energia do céu e cor da neblina misturam `Tuning.DAY_LIGHT` e `NIGHT_LIGHT` por `Clock.night()`, com lusco-fusco quente no meio. A luz ambiente vem do céu, então a noite escurece tudo o que o fogo não ilumina. De noite os bichos enxergam pior o goblin (`Tuning.NIGHT_VISIBILITY`).
- **Vitals:** o corpo de Ari: saciedade, vida, frio e enjoo. Fome zerada machuca, frio no máximo machuca, queda acima de 8 m/s machuca (`Player`), mordida de lobo machuca; vida 0 emite `Events.player_died`. Sem barra no HUD: o corpo avisa (ronco, mão na barriga, tremor, vapor da respiração, dentes batendo, borda escura da tela com vida baixa).
- **Frio (`ColdExposure`):** mede o ganho por segundo: noite × fora/dentro da caverna (`level.indoor_at`), vezes o vento no goblin, metade com a roupa (`clothes`); perto de fogo aceso (`Campfire.distance_to_fire`, grupo `fire`) esquenta. Dormir zera o frio.
- **Dormir e morrer (`Game.pass_out(reason)`):** mesma sequência. A tela escurece, o som fecha (`close_ears`), o relógio vai para as 6h30, e então Vitals descansa (sono) ou revive com a carne perdida (morte). O goblin volta para a pele e roda o `wake`. Emite `slept` e `woke_up(reason)`. Dormir salva.
- **Save:** além dos nós `persist` da fase, o `SaveSystem` salva os autoloads de `_globals()` (Inventory, Story, Clock, Vitals). Chave faltando carrega o padrão, então saves antigos abrem.
- **Wind:** força num ponto = `abrigo(p) × clima(t) × (0.35 + 0.9 × rajada(p, t))`.
  - A rajada é o `macro_noise.png` arrastado na direção do vento: as frentes de rajada atravessam a grama como ondas.
  - O abrigo vem do mapa `Terrain.build_wind_exposure()`: mata fechada, vales e caverna abrigam.
  - CPU (`Wind.strength_at`) e GPU (`foliage.gdshader`, globais `wind_*`) fazem a mesma conta.
  - O som, as folhas caindo e a poeira no ar usam `strength_at`.
- **Câmera:** braço próprio (`CameraPivot/CameraArm`), sem SpringArm. Em `_place_camera`, uma esfera de 0,22 m vai da nuca até o ombro (deslocamento lateral real, não `h_offset`) e de lá para trás, só contra a camada 1. Ao bater, encolhe na hora; quando abre, volta devagar. Colada no goblin, ele fica transparente e some abaixo de 0,6 m. A casca da caverna tem `backface_collision` para a esfera não passar pelo verso dos triângulos.
- **Passos:** `Footsteps.surface_under()` lança um raio curto para baixo; se acertar uma colisão com meta `surface` (pedras `stone`, troncos `wood`, de `Vegetation._add_shape_collider`), vale ela, senão o `surface_at` do terreno (`cave` no salão da caverna, `stone`, `dirt`, `grass`).
- **Interação:** nós no grupo `interactable` implementam `interaction_prompt() -> String` e `interact(player)`. São o arco no chão, flecha fincada, bicho abatido, corvo caído, fogueira, pele de dormir, monte de pedras, pedra jogada, poça de lama, tocha fincada e laço. O Player pega o mais próximo dentro de 1,8 m.
  - Opcionais: `interaction_enabled()` (false = só mostra o texto, sem [E]), `interaction_action()` (`{action, duration, at}`: a animação e quando chamar `interact`; padrão `pickup`) e `interaction_started(player)`.
  - Ganha o mais próximo que pode ser feito; os desabilitados só aparecem se não houver outro.
  - Partes do goblin (`scenes/player/parts/`) usam:
    - ações: `Player.can_act()`, `perform(action, duração, eventos)`, `hold_in_hand(nó, segundos)`, `hand_socket()`, `face(direção)`, `aim_direction()`, `facing()` e `exert(cansaço)`;
    - estados que o corpo mostra: `sniffing`, `breath_held` e `torch_held`;
    - multiplicadores nos sentidos dos bichos, por nome: `visibility_factors`, `noise_factors` e `scent_factors` (ex.: `&"mud": 0.65`; tirar a chave tira o efeito).
  - Uma parte também pode ser interagível: a `SnareSetter` (Node3D `top_level`) se põe sobre a pegada de coelho mais perto.
- **Fogueira:** lenha 0–3 (começa com 1), queima 1 a cada 6 min, inclusive dormindo. E acende ou põe lenha e assa carne (animação `cook`, a carne escurece na mão). Chama, luz e estalos crescem com a lenha.
- **Riscos na parede (`WallMarks`):** um por noite dormida, em grupos de 5, colados na rocha por raios (na primeira volta da física). Os antigos ficam sob um musgo (`moss_patch.gdshader`) que despenca quando o flag `moss_fell` liga: no 7º risco com um cervo coletado, ou no 10º. Isso abre o Ato II.
- **Árvores:** `Vegetation.trees` registra cada árvore em pé (posição, raio do tronco, seca ou não, instância no MultiMesh e colisão). `hit_tree()` derruba as secas depois de 4 golpes: a instância some, a colisão sai e uma cópia tomba.
- **Animação do goblin (`GoblinAnimator`):** 100% procedural, direto no esqueleto; as animações do glb ficam paradas.
  - Cada frame monta uma *pose* (dicionário: altura do quadril, alvo de cada pé, ângulos de tronco, cabeça, braços e orelhas) e só no fim converte em rotações de osso (`_rotate`: eixos do modelo em repouso, carregados pelo pai).
  - Pernas com IK de duas juntas: o pé segue uma trajetória (apoio no chão + arco no ar), então não escorrega e o joelho dobra. O sinal `foot_planted` toca o passo na hora em que o pé encosta.
  - Camadas: andar/correr, respirar e olhar em volta parado, curva, agachar, no ar, aterrissar, mira e orelhas com mola.
  - **Nada perfeito:** a pose neutra (`_neutral`) já é a postura do goblin, curvada e assimétrica (ombro caído, cabeça torta, pés abertos para fora, braços pendurados). Por cima entram oscilações lentas (`_wave`) em cada parte, passadas com altura e abertura sorteadas, ritmo manco (pé direito atrasado), apoio que troca de perna parado e fôlego (ofega e apoia as mãos nos joelhos depois de correr).
  - Manias parado (`_idle_overlay`): coçar a orelha, farejar, olhar para trás, examinar as garras. Não travam o jogador; qualquer movimento corta.
  - Arco: base de arqueiro (quadril e peito de lado, ombro do arco para o alvo, cabeça de volta olhando pela flecha, pés afastados), braço treme se segurar a corda puxada por mais de 1 s e coice ao soltar.
  - Mira com IK (`_aim_arms`, depois de toda a pose): a empunhadura vai para a linha que sai do canto da boca (`ANCHOR_REST`) até `aim_point`, um `draw_length` à frente; a mão da corda vai até `nock_depth` atrás da empunhadura real. `_reach` é IK de duas juntas por giros (braço até o cotovelo com `pole`, torção para o antebraço ficar no plano da dobra, antebraço até o punho), partindo dos ângulos da pose.
  - Pés: `_orient` deixa o pé paralelo ao chão no espaço do esqueleto, girado por `foot_*_yaw`; a perna abre com `leg_*_out`.
  - Pés no chão (`_ground_feet`): um raio por pé acha a altura e a inclinação do chão embaixo dele (degrau, pedra, encosta). O quadril desce para o pé mais baixo com apoio; pé sem chão fica pendurado, e com só um pé apoiado o peso vai para ele. `foot_supported` é lido pelo Player.
  - Coluna: o giro do tronco se divide entre `tronco` (lombar) e `peito`; por cima entram `spine_arch` (costas redondas em cima, lombar arqueada), `spine_bend` (curva de lado em S) e `neck_fwd` (`pescoco`). A soma lombar + peito é o giro antigo + arch / 2, então as poses dos braços continuam calibradas.
  - Borda (`_balance_overlay`): com `teeter` > 0 abre e gira os braços, joga o corpo para longe do vazio e olha para baixo.
  - Ações cronometradas com eventos: `wake` (acordar), `pickup`, `harvest` (coletar caça), `punch`, `eat`, `cook` e `lie_down` (deitar para dormir). Faminto, a mania mais comum parado é a mão na barriga (`starving`). O Player só pega o item ou acerta o golpe no evento, quando a mão chega. Cada ação mexe o corpo todo (quadril, coluna, pescoço), com preparação e continuação: o soco arma girando quadril e ombro para trás e solta com o quadril na frente; pegar dobra no quadril com as costas curvas e sobe com o peito na frente.
  - Mecânica do corpo (`_body_mechanics`, depois das ações e antes do equilíbrio): (1) dobradiça, em que a inclinação acima de 0,2 rad vai em parte para a bacia (`pelvis_pitch`), o quadril recua (`pelvis_z`) e as costas arredondam; (2) braços, em que esticar um traz o ombro (giro do peito) e erguer acima do ombro inclina o tronco; (3) molas, em que o tronco segue o quadril por uma mola (~2,4 Hz), comprimindo a coluna (`_squash`) nos passos e na aterrissagem, e a velocidade do peito segue a do corpo (~1,2 Hz), inclinando ao arrancar e ao frear. A cabeça compensa a mola. Sinal de giro: `torso_yaw`/`pelvis_yaw` positivos levam o ombro/quadril direito para a frente (vira para a esquerda, +X).
  - Precisa dos ossos `perna/canela/pe`, `braco/antebraco/mao`, `orelha`, `tronco`, `peito`, `pescoco`, `cabeca` e `quadril`. Sem eles o animador desliga sozinho.
- **Equilíbrio (`Player._update_balance`):** no chão, se não há chão logo embaixo do centro do corpo, ele está na borda. O equilíbrio cai (mais rápido com um pé solto ou andando para o vazio; sem nenhum pé apoiado cai em ~0,25 s) e volta se ele andar para dentro ou se agachar. Se acabar, ele tomba para o lado do vazio (`_tipping`, sem `floor_snap`).
- **Arco:** `Player` mira com o botão direito (a câmera aproxima). Ao erguer o arco, encaixa uma flecha. Segura e solta o esquerdo para atirar. `Arrow` voa com gravidade, testada por raio a cada frame de física, e finca no que acerta.
  - Escala do goblin (braço de 32 cm): arco de 60 cm, corda a 8 cm da empunhadura, puxada de mais 21 cm, flecha de 38 cm.
  - `HeldBow` (filho do `Visual`, sem socket): o Player o põe todo frame em `GoblinAnimator.bow_grip_position()`, a pose do mesmo frame, porque um socket atrasaria um frame em relação à mão da corda. Carregado, fica deitado para a frente (`CARRY_RISE`) e balança com o antebraço; mirando, barriga para o alvo e um pouco deitado (`BOW_CANT`). Braços que dobram com `draw`, corda até `nock_depth(draw)` (volta reta ao soltar) e a flecha encaixada. A flecha sai da empunhadura para o ponto no centro da tela.
  - Depois do tiro, `RELOAD_TIME` (0,75 s): a mão vai até a aljava (`GoblinAnimator.reload`) e só então a próxima flecha aparece na corda, com o som de encaixe.
- **Grama no relevo:** `Terrain.publish_height_texture()` publica as alturas como global `terrain_height`. Com `follow_ground = 1` (grama e samambaia), o `foliage.gdshader` sobe ou desce cada vértice com o chão embaixo dele.
- **Lobos:** `WolfPack` (filho de Animals) traz `Tuning.WOLF_COUNT` lobos a partir do dia 3: uivo de aviso às 20h30 da borda do vale (`Ambience.howl_from`), chegada às 21h, saída às 5h30, e somem se o goblin dorme. `Wolf extends Animal` reaproveita os sentidos e troca a reação: ronda (a área de caça escorrega para o goblin), espreita a 9 m rosnando, caça e morde. Não chega a menos de 6 m de fogo aceso e, ao contrário dos outros bichos, pode entrar na caverna. Uma flechada o faz fugir e ir embora; duas matam.
- **Pegadas (`Tracks`):** bicho com `track_size` deixa uma pegada a cada `Tuning.TRACK_SPACING` andados (alternando os lados da fila com `track_side`). O MultiMesh tem um pool de `Tuning.TRACK_POOL` e o shader (`track_print.gdshader`) desenha casco, pata de coelho ou de lobo e apaga pela idade. `Tracks.nearest(espécie, ponto, raio)` acha a pegada fresca mais perto (o laço usa). Dormir envelhece todas.
- **Farejar (`SniffAbility`, X):** agachado e parado, até `Tuning.SNIFF_MAX_SECONDS`. Fecha o som com `Game.close_ears`, mostra riscos de vento e uma trilha de cheiro (partículas por cima de tudo, a 1 m do chão) de cada bicho até `Tuning.SNIFF_RANGE` cujo cheiro o vento traz.
- **Fôlego (`BreathControl`, Q):** prendendo o ar, parado não faz barulho (a respiração ofegante depois de correr faz) e o arco puxado não treme; o coração bate cada vez mais rápido. Passando do limite, bufa (`noise_made`) e fica ofegante.
- **Pedras e susto:** G joga uma `ThrownStone` (`StoneThrow`); onde ela bate faz `noise_made` de `Tuning.STONE_NOISE`. O `Animal` guarda o susto (`_startle`, 3 s): o perigo fica sendo o lugar do barulho (ou de onde a manada se assustou) até ele ver o goblin com clareza. É o que deixa tocar a manada.
- **Lama:** `MudPuddle` ("Esfregar lama", ação `rub_mud`) põe `Vitals.mud` em 1; `MudCamouflage` gasta em um dia (mais rápido correndo), põe os multiplicadores de visibilidade e cheiro e a global de shader `goblin_mud` (manchas no `goblin_skin.gdshader`).
- **Fabricar (`CraftAbility`, R):** lista no canto com `Recipes.LIST`. O tempo não para; a animação `craft` dura `Tuning.CRAFT_TIME` e o custo sai no fim. Emite `Events.crafted(id)`, que o Story conta.
- **Tocha (`Torch`, `TorchCarry`):** na mão direita, segue o socket da mão. É fogo (grupo `fire`): esquenta e afasta lobo. Os bichos veem mais o goblin (`Tuning.TORCH_VISIBILITY`). Mirando, ela é fincada no chão.
- **Laço (`Snare`, `SnareField`):** armado sobre pegada de coelho; `SnareField` (persist) sorteia a captura com o goblin longe, e as horas dormidas contam de uma vez. Pegou: um `Rabbit` morto (`Animal.kill()`) fica no laço para coletar.
- **Corvos:** cada corvo do `CrowFlock` é um `Crow` com área de acerto (camada 4). Flechada derruba; no chão, E dá penas. A `Arrow` acerta qualquer área cujo dono tenha `take_hit` e devolve o próprio tipo de flecha (`Arrow.collect_from`).
- **Bichos** (`Animal`):
  - visão em cone com linha de visada e movimento pesando mais que forma parada; pastando enxergam mal;
  - audição do `noise_level()` do jogador e de `noise_made`;
  - olfato quando o vento sopra do jogador para o bicho;
  - `awareness` leva a desconfiado e depois a fuga; a manada foge junta;
  - ferido, sangra e fica lento; morto, vira `interactable`.

  O jogador expõe `noise_level()` e `visibility()` (agachado, parado e coberto por capim ou mata).
- **Física, camadas:** 1 `world` (terreno, caverna, pedras, troncos caídos), 2 `trees`, 3 `player`, 4 `animals` (Area3D de acerto). Raios de som só testam a camada 1. Visão dos bichos: 1 e 2. Flechas: 1, 2 e 4.
- **Ouvido (`Game.open_ears`):** passa-baixa no Master. Toda troca de fase abre o som em 2,5 s (quem chega a um lugar); o despertar da floresta abre em 7,5 s, de -42 dB e 160 Hz: o volume sobe primeiro e os agudos chegam por último. Loops de ambiente e `OccludedAudio` com autoplay começam num ponto sorteado.
- **Áudio, buses:**
  - `Ambience`: sons de fora. Passa-baixa que fecha dentro da caverna e eco de vale.
  - `World`: fogo, passos, flechas. Reverb que abre dentro da caverna.
  - `AmbienceMuffled` e `WorldMuffled`: passa-baixa, para sons atrás de rocha (OccludedAudio troca sozinho).
- **ForestLayout** é a fonte única dos pontos do mapa. Terreno, vegetação, bichos e som leem dali.
- **Regra de comunicação:** pai → filho por chamada; filho → pai por sinal; sistemas distantes pelo `Events`.

## Convenções

- GDScript com tipagem estática. Valores tirados de `Array`/`Dictionary` ou de chamadas dinâmicas precisam de tipo explícito (`var x: Vector3 = arr[0]`, `var ok: bool = a and b.f()`), senão dá *Parse Error*.
- Arquivos e pastas em `snake_case`, nós em `PascalCase`. Identificadores em inglês; comentários e textos do jogo em português.
- **Modelos:** frente em **+Z** (MODEL_FRONT). Unidades em metros.
- **Malhas por código:** a face da frente é o sentido **horário** visto de fora (convenção do Godot).
- **Colisão de pedras e formas irregulares:** malha exata (`create_trimesh_shape`). O casco convexo sobra nas reentrâncias e deixa o jogador "em pé no ar".
- **Cartões de folhagem** usam `foliage.gdshader`, que é double-sided, já corrige a normal do verso e some perto da câmera (dither Bayer 4×4; padrões feitos com `floor` viram listras diagonais). Com a câmera baixa, a grama (`follow_ground`) no raio `part_radius` se deita para longe da lente.
- **Goblin:** `GoblinLook.apply()` troca os materiais pelo nome da paleta (`goblin.pele` etc.). Os com textura usam `goblin_skin.gdshader`: projeção dos três lados misturada pela normal, na pose de repouso (posição em UV/UV2, normal em COLOR). Sem emendas, e a textura não escorrega com os ossos.
  - Ossos (31): `raiz`, `quadril`, `tronco` (lombar), `peito`, `pescoco`, `cabeca`, `perna_*`, `canela_*`, `pe_*`, `braco_*`, `antebraco_*`, `mao_*`, `orelha_*` e partes do rosto. `_E` é o lado esquerdo (+X), `_D` o direito.
  - Sockets viram nós como `braco_E_mao`, presos ao osso `mao_E`.
  - Espaço do esqueleto: Y para cima, +Z frente.
- **Serialização em `.tscn`:** Transform3D grava as **linhas** da base e depois a origem.
- Versione os `.uid` e `.import`. Nunca versione `.godot/`.

## Desempenho (medido)

- Numa RTX 3050 Laptop: 120 FPS (limite do vsync), ~430–730 draw calls, 300–590 mil triângulos visíveis e ~10 ms de CPU em `_process`. O mundo é gerado em ~0,5 s.
- Vegetação em MultiMesh por blocos de 48 m com `visibility_range_end`: grama até 55 m, árvores até 170 m. A grama não projeta sombra.
- A neblina (`fog_density` 0,016) esconde o corte de distância. Dentro da caverna, `forest.gd` afina e escurece a neblina.

## Assets

- **Texturas:** 100% procedurais (`tools/generate_textures.py`).
- **Sons:**
  - Gravações reais CC0 em `assets/audio/real/`:
    - passos em grama, terra, pedra e tronco, casco do cervo, impactos de flecha, golpe na madeira, rangido, coleta e faca (Kenney). Pedra e tronco passaram por passa-baixa, porque o goblin anda descalço;
    - puxar, encaixar e soltar o arco (Medieval SFX, OpenGameArt).
  - Passos em terra (`step_dirt_*`): gravação real numa estrada de terra (Freesound, CC0), cortada passo a passo com um expansor para o ambiente da gravação não sobrar no fim. A caverna (`step_cave_*`) usa os mesmos cortes, com passa-baixa de 3 kHz e um tom abaixo. Já foram testados e rejeitados: as gravações de sapato do RPG Audio (o "toc-toc" de salto e ponta), passo sintético e passos de carpete ou neve abafados.
  - O resto é sintético (`tools/generate_sounds.py`).
  - Uivo do lobo: o jogo usa `assets/audio/animals/wolf_howl_real_N.(ogg|wav|mp3)` se existir; senão, o sintético.
  - Origem de cada arquivo em `assets/CREDITS.md`.
- **Goblin:**
  - Fonte: `assets/models/goblin/source/goblin.blend`, gerada por `polish_goblin.py`, que monta corpo contínuo, rosto, roupa, rig articulado e pesos de pele. Mudanças no modelo vão nesse script.
  - Regerar e exportar pela linha de comando do Blender:
    ```powershell
    $blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
    & $blender --background --python assets\models\goblin\source\polish_goblin.py
    & $blender --background --python assets\models\goblin\source\export_goblin.py   # valida malha/pesos e grava o glb
    ```
  - Não reexporte o `goblin_blueprint.json` com `export_game`: isso descarta o polimento e o rig articulado.
- **Bichos, arco e flechas:** montados em código.
- **Assets de terceiros:** só CC0 ou licença compatível, registrados em `assets/CREDITS.md`.

## Ainda não existe

- O resto do plano (`docs/plano.md`, fases F4–F8): pistas do Ato I, Vigilância, cervo branco, ruína, mundo real, Zelador e finais.
- Combate corpo a corpo de verdade, diálogos, missões, atributos.
- Menu principal e configurações (vídeo, áudio e controles).
- Subir degraus (step-up), água.
- A ruína medieval (`ForestLayout.RUINS`).
