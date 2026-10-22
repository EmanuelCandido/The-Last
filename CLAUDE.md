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
  - `--run=roteiro.gd`.
- **`--run`:** recebe um `RefCounted` com `func run() -> void` (pode usar `await`). É o jeito de testar mecânicas de ponta a ponta: pegar o arco, quebrar árvore, caçar, furtividade.
- **`--press`** gera eventos de ação de verdade. `--hold` só segura a ação e não dispara `_unhandled_input`, então E, R e o soco precisam de `--press`.
- `--fixed-fps 60` deixa o teste determinístico: 60 frames equivalem a 1 s de jogo. Os bichos nascem com semente aleatória.
- Depois de mexer em scripts ou cenas, rode o teste de fumaça. Erros aparecem como `SCRIPT ERROR`, `Parse Error` ou `ERROR:`.
- Mudança visual só está pronta depois de tirar um print e olhar a imagem.
- "N resources still in use at exit" com AudioStream é só som tocando quando o teste fecha. Pode ignorar.
- Texturas novas: depois da primeira importação, edite o `.png.import` com `compress/mode=0`, `mipmaps/generate=true` e `detect_3d/compress_to=0`, e importe de novo. Sem mipmaps, o filtro nearest cintila à distância.

## Estrutura

```
autoload/            Events, Wind, Inventory, Game, SaveSystem, DevTools
scenes/
  main/              cena raiz: LevelRoot + UI (HUD, ScreenFade, PauseMenu)
  player/            goblin: player.gd (movimento, arco, soco, interação), goblin_animator.gd
                     (animação procedural no esqueleto) e goblin_look.gd (texturas)
  items/             arco (pickup na caverna), flecha (projétil), BowMesh (malhas)
  levels/forest/     fase da floresta: forest.tscn/gd e ForestLayout (pontos-chave do mapa)
  levels/test_level/ fase de teste antiga (blocos CSG)
  world/terrain/     Terrain: relevo, malha em blocos, HeightMapShape3D, mapa de abrigo do vento
  world/cave/        Cave: casca de rocha procedural + fogueira, pele, arco, gotejamento
  world/vegetation/  TreeBuilder (malhas por código) e Vegetation (espalha, instancia, derruba árvores)
  world/props/       fogueira, folhas caindo
  world/ambience/    Ambience: vento 3D, folhas nas árvores, chamados de bichos
  animals/           Animal (sentidos, fuga, ferimento, caça), Deer, Rabbit, CrowFlock
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
- **Inventory:** quantidade por item (`bow`, `arrow`, `wood`, `meat`, `hide`). Emite `changed` e vai junto no save.
- **Wind:** força num ponto = `abrigo(p) × clima(t) × (0.35 + 0.9 × rajada(p, t))`.
  - A rajada é o `macro_noise.png` arrastado na direção do vento: as frentes de rajada atravessam a grama como ondas.
  - O abrigo vem do mapa `Terrain.build_wind_exposure()`: mata fechada, vales e caverna abrigam.
  - CPU (`Wind.strength_at`) e GPU (`foliage.gdshader`, globais `wind_*`) fazem a mesma conta.
  - O som, as folhas caindo e a poeira no ar usam `strength_at`.
- **Interação:** nós no grupo `interactable` implementam `interaction_prompt() -> String` e `interact(player)`. São o arco no chão, flecha fincada e bicho abatido. O Player pega o mais próximo dentro de 1,8 m.
- **Árvores:** `Vegetation.trees` registra cada árvore em pé (posição, raio do tronco, seca ou não, instância no MultiMesh e colisão). `hit_tree()` derruba as secas depois de 4 golpes: a instância some, a colisão sai e uma cópia tomba.
- **Animação do goblin (`GoblinAnimator`):** 100% procedural, direto no esqueleto; as animações do glb ficam paradas.
  - Cada frame monta uma *pose* (dicionário: altura do quadril, alvo de cada pé, ângulos de tronco, cabeça, braços e orelhas) e só no fim converte em rotações de osso (`_rotate`: eixos do modelo em repouso, carregados pelo pai).
  - Pernas com IK de duas juntas: o pé segue uma trajetória (apoio no chão + arco no ar), então não escorrega e o joelho dobra. O sinal `foot_planted` toca o passo na hora em que o pé encosta.
  - Camadas: andar/correr, respirar e olhar em volta parado, curva, agachar, no ar, aterrissar, mira (braço da corda torce e dobra na horizontal até o queixo) e orelhas com mola.
  - Ações cronometradas com eventos: `wake` (acordar), `pickup`, `harvest` (coletar caça) e `punch`. O Player só pega o item ou acerta o golpe no evento, quando a mão chega.
  - Precisa dos ossos `perna/canela/pe`, `braco/antebraco/mao`, `orelha`, `tronco`, `cabeca` e `quadril`. Sem eles o animador desliga sozinho.
- **Arco:** `Player` mira com o botão direito (a câmera aproxima). Ao erguer o arco, encaixa uma flecha. Segura e solta o esquerdo para atirar. `Arrow` voa com gravidade, testada por raio a cada frame de física, e finca no que acerta.
- **Grama no relevo:** `Terrain.publish_height_texture()` publica as alturas como global `terrain_height`. Com `follow_ground = 1` (grama e samambaia), o `foliage.gdshader` sobe ou desce cada vértice com o chão embaixo dele.
- **Bichos** (`Animal`):
  - visão em cone com linha de visada e movimento pesando mais que forma parada; pastando enxergam mal;
  - audição do `noise_level()` do jogador e de `noise_made`;
  - olfato quando o vento sopra do jogador para o bicho;
  - `awareness` leva a desconfiado e depois a fuga; a manada foge junta;
  - ferido, sangra e fica lento; morto, vira `interactable`.

  O jogador expõe `noise_level()` e `visibility()` (agachado, parado e coberto por capim ou mata).
- **Física, camadas:** 1 `world` (terreno, caverna, pedras, troncos caídos), 2 `trees`, 3 `player`, 4 `animals` (Area3D de acerto). Raios de som só testam a camada 1. Visão dos bichos: 1 e 2. Flechas: 1, 2 e 4.
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
- **Cartões de folhagem** usam `foliage.gdshader`, que é double-sided, já corrige a normal do verso e some perto da câmera.
- **Goblin:** `GoblinLook.apply()` gera UV por projeção em caixa e troca os materiais pelo nome da paleta (`goblin.pele` etc.).
  - Ossos (29): `raiz`, `quadril`, `tronco`, `cabeca`, `perna_*`, `canela_*`, `pe_*`, `braco_*`, `antebraco_*`, `mao_*`, `orelha_*` e partes do rosto. `_E` é o lado esquerdo (+X), `_D` o direito.
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
    - passos em grama, terra e pedra, impactos de flecha, golpe na madeira, rangido, coleta e faca (Kenney);
    - puxar, encaixar e soltar o arco (Medieval SFX, OpenGameArt).
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

- Comer, fome e vida do goblin.
- Combate corpo a corpo de verdade, diálogos, missões, atributos.
- Menu principal e configurações (vídeo, áudio e controles).
- IK dos pés no relevo: em encosta, os pés seguem a base do modelo e não o chão.
- Subir degraus (step-up), água, ciclo de dia e noite.
- A ruína medieval (`ForestLayout.RUINS`).
