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
python tools/generate_ui.py                                             # regera assets/ui/ (fonte Toca e texturas da interface)
python tools/process_real_sounds.py --raw=PASTA                         # corta e trata as gravações reais (CREDITS.md)
powershell -ExecutionPolicy Bypass -File tests\run_all.ps1              # todos os roteiros de tests/ (-Only f8 roda só um)
& $godot --headless --path . --export-release "Windows Desktop"         # build/A Toca.exe (--export-debug liga o diário de playtest)
```

- **Argumentos do DevTools** (depois de `--`), documentados em `autoload/dev_tools.gd`:
  - `--frames`, `--hold`, `--press`, `--give`;
  - `--load`, `--save`, `--pause`, `--tips`;
  - `--screenshot`, `--skip-intro`, `--teleport=x,z`, `--camera=yaw,pitch`;
  - `--set=story.act:2,story.flag:moss_fell,vitals.satiety:10,clock.hour:19,weather.rain:3` (põe o estado global em qualquer ponto; `weather.rain:n` chove n horas, 0 para);
  - `--shelter` (acorda Ari no Abrigo, já de pé) e `--flash=n` (começa o flash n, para prints);
  - `--menu` (abre o menu principal; sem `--frames` nem `--screenshot` ele já abre sozinho) e `--welcome` (começa o Bem-vindo de volta);
  - `--equip=<arma>` (F11: põe a arma na mão, dando uma se faltar);
  - `--run=roteiro.gd`.
- **`--run`:** recebe um `RefCounted` com `func run() -> void` (pode usar `await`). É o jeito de testar mecânicas de ponta a ponta: pegar o arco, quebrar árvore, caçar, furtividade, assar, dormir, farejar, jogar pedra, fabricar. Roteiro que não existe ou não compila fecha o jogo na hora (código 1).
- **`tests/`:** os roteiros de cada fase (`test_f1` a `test_f9`, `test_life`, `test_melhorias`), versionados. Imprimem `[T] ok`/`[T] FALHOU` e terminam com `[T] FIM: TUDO OK`. O `run_all.ps1` guarda e devolve os arquivos do jogador (`save.json`, `settings.cfg`, `toca.cfg`, a carta, o `ciclo_346.sav`, `playtest/`), roda um por um com limite de tempo (`-Timeout`, 300 s) e grava a saída em `%TEMP%\toca_tests`. Roteiro novo `tests/test_*.gd` entra sozinho. A exportação deixa `tests/` de fora.
- **Diário de playtest (`Playtest`, autoload):** em build de depuração (editor e `--export-debug`) ou com `--playtest`, grava `user://playtest/sessao_*.log` (eventos, flags, mortes, sono, anotações, posição a cada 2 min e o tempo em cada ato). Fica desligado nos testes do DevTools e no export de lançamento.
- **OneDrive:** o projeto fica numa pasta do OneDrive marcada para sempre ficar no PC (`attrib +P`). Arquivo novo herda; se o Godot reclamar de arquivo "só na nuvem", rode `attrib +P "<pasta>\*" /S /D` (e `attrib +P +H` no `.git`).
- Roteiros que dormem salvam de verdade em `%APPDATA%/Godot/app_userdata/Jogo Pessoal/save.json`. Apague esse save depois do teste. Roteiros que mexem nas Configurações gravam `settings.cfg` na mesma pasta (apague também). Os finais também escrevem `toca.cfg` na mesma pasta (o título do jogo); `MetaFiles.forget_endings()` limpa. Num roteiro (`DevTools.scripted`), o Final 3 não fecha o jogo.
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
autoload/            Events, Settings, Wind, Inventory, Clock, Weather, Vitals, Story, Game, SaveSystem, MetaFiles, DevTools, Playtest
scenes/
  main/              cena raiz: LevelRoot + UI (HUD, ScreenFade, PauseMenu); abre o menu principal
  endings/           Endings (as cenas dos três finais) e WelcomeBack (o Bem-vindo de volta)
  player/            goblin: player.gd (movimento, arco, soco, interação), PlayerCamera (câmera sobre o ombro),
                     EdgeBalance (equilíbrio na borda), StepClimber (subir degraus), PlayerGear (arco na mão e
                     aljava), goblin_animator.gd (animação procedural no esqueleto), GoblinActions (poses das ações),
                     GoblinIdle (manias parado) e goblin_look.gd (texturas)
  player/parts/      mecânicas novas do goblin como nós filhos: EatAbility (F), BodyFeedback (fome), ColdExposure (frio),
                     SniffAbility (X), BreathControl (Q), StoneThrow (G), MudCamouflage, CraftAbility (R), TorchCarry,
                     SnareSetter, LeatherClothes, AimGuide (mira com fôlego), Practice (aprender pela prática),
                     TreeMarker (riscar o tronco) e GoblinAutopilot (a IA que joga no Bem-vindo de volta)
  items/             arco (pickup na caverna), HeldBow (arco na mão, corda que puxa), flecha (projétil), pedra jogada,
                     tocha, BowMesh e MeatMesh (malhas)
  levels/forest/     fase da floresta: forest.tscn/gd e ForestLayout (pontos-chave do mapa)
  levels/test_level/ fase de teste antiga (blocos CSG)
  world/terrain/     Terrain: relevo, malha em blocos, HeightMapShape3D, mapa de abrigo do vento
  world/cave/        Cave: casca de rocha procedural + fogueira, pele de dormir (e a cama de peles), riscos na parede
                     (WallMarks), pintura no teto (CavePainting), troféus (Trophies), arco, gotejamento e a fumaça
                     vista de longe (CaveSmoke)
  world/vegetation/  TreeBuilder (malhas por código) e Vegetation (espalha, instancia, derruba árvores)
  world/props/       fogueira (lenha, assar), folhas caindo, monte de pedras, poça de lama, laço (Snare e SnareField),
                     defumador (SmokingRack), coleta (ForageField e ForageSpot), tocaias (BlindField), marcos de
                     pedra (CairnField), troncos riscados (TreeMarks) e PropLook (materiais compartilhados dos props
                     montados por código)
  world/tracks/      Tracks: pegadas dos bichos (MultiMesh)
  world/clues/       Clues: as pistas do Ato I e os sons que vazam do mundo real
  world/ruin/        Ruin (capela, espadana e sala-espelho), RuinDoor (porta e discos), Sarcophagus e RuinBell (o sino)
  world/ambience/    Ambience: vento 3D, folhas nas árvores e os tocadores de chamados (call_at);
                     InsectField: grilos e gafanhotos de verdade no capim
  world/day_night/   DayNight: sol, céu e neblina pela hora (Clock.night)
  world/north_void/  NorthVoid: o mundo acabando ao norte depois do R3 (clima cortado)
  world/memory/      Memory346: a memória do ciclo 346 (o goblin riscando ACORDA), que passa ao carregar o ciclo_346.sav
  animals/           Animal (sentidos, fuga, ferimento, caça, sono), Herd (manada com casa e agenda), Deer, WhiteDeer,
                     OldDeer (o Velho), Rabbit, Boar (javali), CrowFlock e Crow, Wolf e WolfPack, Watchers (os olhos do
                     Zelador: corvos sentinela e espiões, cervo branco); birds/: BirdLife e Bird (pássaros
                     pousados nas árvores); CreatureModel (modelo com esqueleto preso a pivôs), AnimalLook
                     (pelo pixelado por região), QuadrupedGait (passo e galope das pernas de três juntas) e
                     CreatureDeath (a queda e o corpo morto dos de quatro patas)
  shelter/           o Abrigo 9 (mundo real, 2 km abaixo): Shelter (salas por código), ShelterLook (materiais e peças),
                     CareCapsule, VitalsMonitor, WindowBlinds, FlickerLight, Caretaker (corpo do Zelador), Keeper (a IA
                     dele), Visit (lucidez e objetivos da visita), ShelterSwitch (fusível, alicate, cabo, cartão), Ari
                     (primeira pessoa), FlashDirector (os flashes), ControlRoom (sala de controle: cartão, câmeras,
                     terminal, servidor e a conversa) e Outside (Final 2: a escada e a cidade na neblina)
  ui/                HUD (ação, avisos, itens, mira), menu de pausa (com Dicas e a lista de Carregar), ScreenFade,
                     BlurredVision (visão borrada), VitalsHud (ECG e oxigênio no canto), FakeFreeze (o falso travamento),
                     MainMenu, Credits, KeeperConsole (o console do Zelador no terminal), SettingsMenu (a tela de
                     Configurações) e UiStyle (theme/: paleta, painel de rocha, logo, botões de menu)
components/          Footsteps (passos por chão), OccludedAudio (som 3D abafado atrás de rocha), Senses (visão, audição e
                     térmico de quem vigia)
assets/
  textures/ shaders/ gerados por tools/ (exceto shaders)
  ui/                o Theme único (ui_theme.tres), a fonte pixelada Toca (font/, BMFont), as texturas 9-patch,
                     os painéis de rocha, o logo e os ícones, gerados por tools/generate_ui.py (exceto o .tres)
  audio/             sintéticos gerados por tools/; audio/real/ = gravações reais CC0 (ver CREDITS.md)
  models/goblin/     goblin.glb + source/ (goblin.blend, polish_goblin.py, export_goblin.py)
  models/animals/    deer, old_deer, rabbit, boar, wolf, crow, songbird, woodpecker e owl (.glb) + source/build_animals.py
tools/               geradores Python de texturas e sons (numpy + Pillow)
tests/               roteiros --run de cada fase e o run_all.ps1
```

## Arquitetura

- **Configurações (`Settings`, autoload):** vídeo (tela cheia, vsync, escala 3D em `root.scaling_3d_scale`, limite de
  FPS, campo de visão, brilho, filtro retrô), áudio (geral, Ambience, World), controles (sensibilidade, inverter Y, teclas) e jogo
  (tamanho de avisos/prompt/legendas, dicas de controle). Salvas em `user://settings.cfg`, fora do save; carregam no
  início e valem na hora. Padrões em `Tuning.SETTINGS_*`.
  - Quem muda chama `set_value(chave, valor)`, `set_volume(bus, 0..1)` ou `rebind(ação, evento)`; `reset_section`
    devolve os padrões de uma aba (`InputMap.load_from_project_settings` nas teclas). Tudo emite `changed(chave)`.
  - Leem: `Player` e `Ari` (`mouse_sensitivity`, `invert_y`, `fov`; mirando fecha `SETTINGS_AIM_FOV_DROP`), o HUD
    (`text_scale()`, `show_hints`) e a `BlurredVision` (legendas em 32 × `text_scale()`).
  - Volume geral é um `AudioEffectAmplify` no Master (o volume do Master é do ouvido, `Game.open_ears`); "Efeitos"
    mexe em World e Shelter juntos (a tela não pode contar que o Abrigo existe). Brilho é uma curva de gama
    (`brightness.gdshader`) num `CanvasLayer` de camada -1, abaixo de toda a interface.
  - **Filtro retrô (`retro`, "Filtro retrô" no Vídeo):** o visual do jogo inteiro (floresta, Abrigo, flashes,
    menu). `retro_filter.gdshader` num `CanvasLayer` de camada -2 (abaixo do brilho e da interface): pixel grande
    (blocos inteiros de `Tuning.RETRO_VIRTUAL_HEIGHT` linhas, média de 4 amostras lineares; os mipmaps da tela do
    Godot vêm borrados e só servem para o brilho), halo quente em volta das luzes (`RETRO_BLOOM_THRESHOLD`), cor
    quente e um pouco dessaturada com as tintas de luminância ~1 (a escuridão é da cena, não do filtro), vinheta,
    grão a 24 trocas por segundo e `RETRO_LEVELS` cores por canal com Bayer 4×4 na grade dos blocos.
  - Teclas: `REMAPPABLE` lista as ações da tela; `rebind` troca a principal (primeira tecla ou botão do mouse) e
    tira a mesma tecla das outras ações, que recebem a antiga (as duas trocam). Textos que mostram tecla usam
    `key_label(ação)` ou `key_labels()` com `String.format` (`{interact}`, `{eat}`...): prompt do Player e de Ari,
    dicas de controle, Dicas do pause, lista de fabricar e o disco da porta da ruína.
- **Interface (`assets/ui/ui_theme.tres`, tema do projeto em `gui/theme/custom`):** pedra escura, linha de ferro
  gasta, osso e ocre de vela, tudo pontilhado e com filtro nearest (`default_texture_filter` do canvas). A fonte
  Toca é pixelada com base 16 (tamanhos bons: 16, 32, 48, 64), com negrito e itálico gerados e uma fonte do sistema
  de reserva para letras que faltam.
  - Variações: `Title` (64), `MenuTitle` (48, negrito e espaçado: "PAUSADO"), `Heading` (32, ocre), `Hint`
    (apagado), `MenuItem` (botão de menu, 32, com a faixa quente no foco), `TabButton`, `PanelDark`, `Smudge`
    (mancha atrás do prompt, dos avisos e das dicas) e `Keycap` (a tecla do prompt).
  - A fonte de reserva do sistema entra na altura da linha (Toca a 32 = 44 px de linha): a coluna de itens da
    pausa usa separação -12 para dar um item a cada 41 px.
  - Peças desenhadas (`tools/generate_ui.py`, sempre em escala inteira): os painéis de rocha `rock_menu`,
    `rock_pause` e `rock_wide` (a 3x, 240 linhas = 720 px; a borda direita é uma silhueta em degraus que se
    desfaz em pontilhado), o `logo` "A TOCA" (O trocado pelo arco da caverna, a 3x), a
    `cave_icon`, a tecla-lápide `key_icon` do rodapé, o `marker` laranja do foco, as setas `up_down` e o atlas
    `item_icons` (12×12 + sombra, na ordem de `ICONS` no gerador e de `UiStyle.ICONS`).
  - `UiStyle` tem a paleta (`INK`, `INK_DIM`, `ACCENT`, `MOSS`, `MARK`... e `hex()` para BBCode) e as peças:
    `rock_panel(kind)`, `sprite(textura, escala)`, `menu_title()`, `tally_line(texto)` (os riscos da parede e o
    texto apagado ao lado: `TallyMarks` desenha texel a texel um risco por dia, `Clock.day` (o Dia 1 já
    tem um), ou o dia do save no menu principal, `UiStyle.days_marked()`; em grupos de cinco como na caverna), `footer(pai, texto)` (lápide e "[Esc] Voltar ao jogo" no canto de baixo), `menu_button()` (com
    `add_marker`: o marcador laranja à esquerda, só no foco), `item_icon(item)`, `hud_font_size()` (32, 48 ou 64
    pelo tamanho de texto das Configurações), `fog_backdrop()` (neblina em Bayer, `ui_fog.gdshader`, nos créditos)
    e `separator()`.
  - Menus: painel de rocha à esquerda, o mundo à direita sem escurecer, a coluna em `UiStyle.MENU_LEFT`. O
    `MainMenu` tem o logo, os riscos (com o save ao lado) e "[Enter] Confirmar"; o `PauseMenu` (montado em código)
    tem a boca da caverna, "PAUSADO", os riscos com o dia (ou o aviso, como "Jogo salvo.") e "[Esc] Voltar ao
    jogo"; a lista de Carregar aparece no lugar dos itens. As Dicas e o `SettingsMenu` usam o painel largo.
    Com o jogo pausado, o HUD some. Os créditos mostram o logo.
  - HUD: os itens são ícone e quantidade no canto de baixo, direto sobre a cena; a lista de fabricar
    (`CraftAbility`) fica em cima deles, uma receita por vez: marcador, nome, custo (ou o que falta) embaixo,
    setas ▲▼ e "[E] Fazer"/"[R] Fechar" à direita.
  - `SettingsMenu` abre por cima do `MainMenu` e do `PauseMenu` (quem abre esconde o próprio painel e volta no
    sinal `closed`); Esc fecha ou cancela a troca de tecla. O HUD separa o "[E]" do prompt numa tecla desenhada.
  - Fora do tema de propósito: a caixa do `FakeFreeze` (tema próprio com a fonte do Windows) e o `KeeperConsole`
    (fonte monoespaçada do sistema).
- **Main** passa o `LevelRoot` e a `UI` para o `Game` e abre o menu principal (`Game.open_menu`); nos testes do DevTools (`--frames`/`--screenshot`) carrega direto `Game.FIRST_LEVEL` (a floresta).
- **Game:** `change_level(path)` troca a fase e cria o jogador no `PlayerSpawn`. Também cuida da pausa e do mouse.
- **Events:** só sinais.
  - `level_loaded`, `game_paused`, `screen_fade_requested`;
  - `noise_made(pos, raio)`: barulho que assusta bichos;
  - `notification_shown`: avisos na tela;
  - `prompt_changed`: ação disponível agora.
- **Inventory:** quantidade por item (`bow`, `arrow`, `feathered_arrow`, `bone_arrow`, `wood`, `stone`, `meat`, `cooked_meat`, `smoked_meat`, `rotten_meat`, `white_meat`, `berries`, `mushroom`, `hide`, `bone`, `feather`, `snare`, `clothes`, `yew_bow`, `fur_bed`). Emite `changed` e vai junto no save. `Inventory.HUD_ORDER` diz o que aparece no HUD. A carne estraga (F9): cada pedaço de `meat` e `cooked_meat` tem idade em horas (`_ages`, o mais velho primeiro, sai primeiro); passando de `Tuning.MEAT_SPOIL_HOURS`/`COOKED_SPOIL_HOURS` vira `rotten_meat`. As idades vão no save na chave `__ages`.
- **Plano e maleabilidade:** `docs/plano.md` é a fonte da história e das mecânicas, dividida em fases (F1 a F9 feitas). Receitas ficam em `Recipes` (`data/recipes.gd`). Números ficam em `Tuning` (`data/tuning.gd`), nunca soltos no código. Acontecimentos da história ficam em `StoryBeats` (`data/story_beats.gd`): cada beat tem gatilho (`on`), condições (`when`) e ações (`do`). Os sistemas reagem a flags (`Story.flag_changed`), sem saber qual beat as ligou.
- **Story:** ato, ciclo (347), riscos deste ciclo (`marks`) e antigos (`old_marks`), flags, contadores (`deer_harvested`, `sleeps_act_2`...), anotações (`notes`, que viram a seção ANOTAÇÕES das Dicas), a Vigilância (`vigilance`, 0..100, só do Ato II em diante) e os objetivos reais (`objectives`, F6). Avalia os beats quando acontece `start`, `slept`, `woke`, `died`, `harvested`, `ate`, `ritual`, `objective`, `memory`, `shelter` (`control_room`, `recordings`) ou `choice` (`ficar`, `acordar`, `trocar`); beat com `"repeat"` dispara toda vez. Ações de beat: `set_flag`, `set_act`, `add_note`, `notify`, `flash` (0 = sorteado entre os vistos), `recycle`, `vigilance`, `wake_real` (Ari acorda no Abrigo), `freeze` e `ending` (um dos finais).
- **Vigilância e Reciclagem:** `Story.add_vigilance()` sobe e desce (números em `Tuning.VIGILANCE_*`); em 100, `Events.recycle_requested`. `Game.recycle()` desmancha a tela (`recycle.gdshader`), roda `Story.recycle()` (ciclo +1, riscos viram antigos, Vigilância 30, desfaz o último objetivo; ato, flags e anotações ficam), zera o inventário e o corpo, volta ao dia 1 e recarrega a fase.
- **Watchers (os olhos do Zelador):** do Ato II em diante, corvos sentinela pousados na boca da caverna (`ForestLayout.CAVE_CROW`) e no ninho da ruína (somem com o flag `blind_spot`), corvos que pousam perto do goblin de tempos em tempos (fora do capim alto) e, com Vigilância alta, um cervo branco por dia. `Watchers.watching(ponto)` responde se algum corvo pousado vê o ponto. `Crow` tem o modo do bando e o modo pousado (`perch`: desce planando, segue o goblin com a cabeça, vai embora).
- **Pistas (`Clues`):** os beats do Ato I só ligam flags; o `Clues` faz cada pista na hora certa (cervo que trava com `Animal.freeze`, corvo que encara, três bipes à noite na caverna, ventilador na rajada forte) e liga `<flag>_seen`. Do Ato II em diante, bipe e ventilador voltam a vazar às vezes; do Ato III em diante, o bipe fica sempre no fundo da caverna, baixinho (`Tuning.LEAK_BEEP_STEADY_DB`).
- **Ruína (`Ruin`):** capela no fim da trilha, montada por código; cada bloco de parede acompanha o chão. Porta lisa com 4 discos (`RuinDoor`, código em `StoryBeats.DOOR_CODE`, só depois do flag `saw_ruin_window`) e, atrás, a sala-espelho com o `Sarcophagus` (deitar: `Player.lie_at`/`get_up`), a frase de Ari e o ninho. O ritual (`BreathControl`): deitado no sarcófago, ou agachado no fundo da caverna, o ar não acaba e aos 20 s sai `Events.ritual_completed`.
- **Pintura (`CavePainting`):** 2 cervos, 7 corvos, 1 lobo e 4 coelhos (o código 2714) no teto da caverna, legível com a fogueira cheia.
- **O Abrigo (`Shelter`, F5):** o mundo real, no mesmo World3D, 2 km abaixo (`Tuning.SHELTER_ORIGIN`), filho do `Game` e montado na primeira vez que é preciso (`Game.get_shelter()`). Fora de uso fica escondido e parado (`set_active`). As malhas ficam na camada visual `Shelter.LAYER`, que o `Sun` da floresta não ilumina (`forest.gd` tira do `light_cull_mask`); a câmera usa `Shelter.environment` (sem neblina); o som vai para o bus `Shelter`. A arquitetura é uma malha por material (`_add_box` junta num `SurfaceTool`) com colisão em caixas; as peças que mexem são nós próprios.
- **Troca de mundo:** `Game.wake_in_shelter(instant)` (pedido por `Events.real_wake_requested`, ação de beat `wake_real`) e `Game.return_to_forest(instant)` (E na cápsula). Com `Game.awake`, a fase fica com `process_mode` desligado, os buses `Ambience` e `World` ficam mudos, o relógio e o corpo param, o HUD esconde itens e teclas, `SaveSystem.save_game()` recusa, e `load_game()` volta antes. Emitem `shelter_entered` e `shelter_left`.
- **Ari (`Ari`):** primeira pessoa, mesmo corpo do goblin: manca (fase da passada; no passo da perna ruim a velocidade cai `Tuning.ARI_LIMP` e a cabeça afunda e pende), rasteja (Ctrl), prende o ar (Q), E no que está no meio da tela (grupo `interactable` dentro do Abrigo, com `interaction_point()` opcional). `noise_level()` é o raio do barulho que o Zelador ouve. Passos pelo mesmo `Footsteps` (piso com `surface = stone`).
- **Visita (`Visit`, F6):** `Shelter.begin_visit(segundos)` a cada `wake_in_shelter`; a lucidez vem de `Visit.lucidity_seconds()` (menos com fome e depois de morrer). Nos últimos `Tuning.LUCIDITY_WARNING` s o coração dispara e `BlurredVision.tunnel` fecha a visão. O fim é sempre um destes três: deitar na cápsula (`return_to_forest`: `end_visit(true)` devolve os objetivos pendentes e o `Game` chama `Story.complete_objective`), desmaiar (`ran_out`) ou ser sedado (`Keeper.captured`); os dois últimos chegam por `Shelter.fainted` em `Game.faint_in_shelter`, perdem os pendentes, somam Vigilância e acordam o goblin na pele. `Shelter.hold_visit()` congela a lucidez e o Zelador enquanto a visita acaba. Do Ato III em diante (`Tuning.DEATH_VISIT_ACT`), morrer leva a uma visita curta em vez do flash.
- **Objetivos reais (R1–R4):** `StoryBeats.OBJECTIVES` (id = flag → o que precisa antes). `Visit.can()`/`add()` contam o pendente da própria visita; `Story.objective_ready()` só os guardados. Cada objetivo dispara o gatilho `objective` (beats `r1_room`..`r4_card`: anotações e Ato IV). No Abrigo, o estado dos objetivos guardados é reposto a cada visita (fusível puxado, cabo cortado, cartão fora do peito). Os efeitos na floresta vêm dos flags: `blind_spot` (Watchers sem sentinelas), `climate_cut` (`NorthVoid` e o Zelador dormente até o R4) e `access_card` (voz do Zelador nos chamados do `Ambience`).
- **Mistério meta (F7):**
  - **Arquivos de verdade (`MetaFiles`):** reagem a flags de beat. `old_save` (flash 2) escreve `user://ciclo_346.sav`, e `letter_left` (R1) escreve `leia_me_se_lembrar.txt` na pasta do jogo (`MetaFiles.game_folder()`: a do executável exportado, ou `user://` no editor e sem permissão). A carta termina com `Story.password()` (`MUSGO-` e 4 dígitos, sorteada uma vez e salva em `Story.secret`). Os textos ficam em `StoryBeats.LETTER` e `OLD_SAVE`. Carregar o save recria um arquivo apagado (`MetaFiles.ensure`), e `MetaFiles.remove_all()` limpa os testes.
  - **Menu de pausa:** com o `ciclo_346.sav` no disco, "Carregar" abre a lista de saves; com a carta, aparece "Abrir pasta do jogo" (`OS.shell_show_in_file_manager`).
  - **A memória (`Memory346`):** `Game.play_memory()` guarda o estado (`SaveSystem.snapshot()`), passa a cena na floresta de verdade e devolve tudo (`SaveSystem.restore()`). A cena tem noite, fogo alto, os riscos escondidos (`WallMarks.hide_marks`), o goblin na ação `scratch` andando com a letra e a palavra aparecendo traço a traço (`WallMarks.carve`, letras em `WallMarks.LETTERS`). Depois vem o corvo na boca da caverna, em silhueta contra o fogo, que vira para a câmera. Por cima fica `memory_glitch.gdshader`. No fim roda o gatilho `memory` (beat `memory_346`) e o menu de pausa volta.
  - **Falso travamento (`FakeFreeze`):** a ação de beat `freeze` (em `first_wake`) emite `Events.fake_freeze_requested`; o próximo `wake_in_shelter` começa por ele em vez do escurecer. Tem a imagem parada (o último quadro), o som cortado com o `stuck_buzz` em loop, o título da janela "(Não está respondendo)", a caixa de diálogo e o preto.
  - **`Game.cutscene`:** liga durante as duas cenas. Bloqueia a pausa e esconde o HUD do goblin.
  - **HUD vital (`VitalsHud`, filho do HUD):** ECG (`ecg_hud.gdshader`), batimento e SpO₂. No Abrigo fica sempre lá; o coração sobe com a lucidez acabando e com o Zelador atrás de Ari, e o oxigênio cai com o ar preso. Na floresta aparece com `climate_cut` e a vida abaixo de `Tuning.LOW_HEALTH`, de leve e falhando.
  - **Voz do Zelador no Abrigo:** `Keeper._say` usa o alto-falante (`Caretaker.speak`) e a legenda (`StoryBeats.LINES`) quando ele acha a cápsula vazia, vê ou ouve Ari e seda, no máximo uma fala a cada `Tuning.KEEPER_SPEECH_COOLDOWN`.
- **Verdade e finais (F8):**
  - **Sala de controle (`ControlRoom`, filho do `Shelter`):** porta com leitor de cartão (abre com o flag `access_card`, ou sozinha para o Zelador), mesa com terminal e rádio, 4 telas (`camera_feed.gdshader`, Vilarrasa com gente; data em `ControlRoom.RECORDING_DATE`), o servidor da simulação e a ordem de evacuação. Entrar dispara `shelter`/`control_room`; "Abrir as gravações" liga as telas e dispara `shelter`/`recordings`, cujo beat liga `confession`, e o `ControlRoom.confess()` faz a conversa (o `Keeper` em `TALK` vai até `talk_point()`; falas em `StoryBeats.LINES`, `Keeper.say()` devolve a duração). Depois da conversa a lucidez para (`visit.active = false`) e o Zelador espera Ari na sala em toda visita.
  - **Console do Zelador (`KeeperConsole`):** "Usar o terminal" abre um `CanvasLayer` com `LineEdit`. Comandos: `ajuda`, `status`, `neblina off|on` (flag `fog_off`, que `forest.gd` lê), `teleport <lugar>` (`Game.forest_teleport`: onde o goblin acorda), `give <item> [n]`, `sair` e os dos finais (`ficar`, `acordar`, `trocar <senha>`, que só aceita `Story.secret`). Um final emite `chose`, e o `ControlRoom` roda o gatilho `choice`.
  - **Finais (`Endings`, filho do `Game`, pela ação de beat `ending` → `Events.ending_requested`):**
    - `stay` (ficar): "Obrigado.", `Game.leave_shelter_by_choice()`, título "Ninho", salva e passa os `Credits` por cima do jogo (`over_world`), que segue. O flag `ending_stay` desliga Vigilância, Reciclagem, ritual e visita da morte; dormir soma `Story.forward_marks` (setas na parede, `WallMarks._build_forward`).
    - `wake` (acordar): `Shelter.open_exit()` sobe a porta blindada e monta o `Outside`; o `Keeper` em `ESCORT` segue Ari a `Tuning.KEEPER_ESCORT_DISTANCE` sem passar da soleira (`Keeper.EXIT_LIMIT_Z`). Lá fora, a neblina adensa conforme sobe; na rua, sino e vozes; perto da vitrine da ótica e olhando para ela, o rosto de Ari (`ari_reflection.png`) aparece atrás do vidro. Visto por `Tuning.REFLECTION_HOLD` s (ou `OUTSIDE_TIMEOUT`), escurece, créditos no preto e `Game.back_to_menu()`.
    - `swap` (trocar, secreto): a lente do Zelador se apaga enquanto o terminal conta a transferência (`ControlRoom.show_transfer`), título "welcome" e `Game.quit_after_swap()` fecha o jogo.
  - **Título (`MetaFiles`, em `user://toca.cfg`):** `title_mode()` é `""`, `ninho` ou `welcome`; `title()` dá o nome da janela e do menu. `welcome_done()` liga depois de assistir ao Bem-vindo de volta.
  - **Menu principal (`MainMenu`, `Game.open_menu`):** a floresta de verdade atrás (câmera fora da caverna, goblin parado, `Game.menu_open`). Continuar (`SaveSystem.load_game(true)`: põe os globais antes de criar a fase), Novo jogo (confirma, apaga save, arquivos e finais: `Game.start_new_game`) e Sair. No modo `welcome`: Assistir, Novo ciclo (depois de assistir) e Sair. O pause ganhou "Menu principal" (`Game.back_to_menu`). `Events.game_started` volta a mostrar as dicas de controle.
  - **Bem-vindo de volta (`WelcomeBack`, `Game.start_welcome`, `Game.welcome`):** nada salva, o HUD some e o `GoblinAutopilot` (filho do Player) joga apertando as ações do `Input`: pega o arco, caça (cervo antes, coelho de perto; chega agachado, mira com a queda da flecha), coleta, come, fabrica flechas e dorme de noite. Depois de dormir uma vez (ou `Tuning.WELCOME_MAX_HOURS`), os riscos viram OBRIGADO (`WallMarks.carve`, `word_spot`), o goblin olha para a câmera e o menu volta com "Novo ciclo".
- **Caça e vida na toca (F9, §8b do plano):**
  - **Chuva (`Weather`, autoload salvo):** a cada hora, `Tuning.RAIN_CHANCE_PER_HOUR` de começar; dura `RAIN_HOURS_MIN..MAX` e entra e sai em `RAIN_FADE_SECONDS` (`Weather.rain`, 0..1). Para com o relógio; o sono pula de uma vez. A floresta faz os riscos (`Rain`, GPUParticles3D em volta da câmera, some na caverna), adensa a neblina (`RAIN_FOG`) e o `DayNight` escurece (`RAIN_DARK`); o `Ambience` toca o `rain_loop` e cala os insetos. Os bichos ouvem e farejam menos (`RAIN_HEARING`, `RAIN_SCENT`). Molhado (fora da caverna e longe da copa, `Vegetation.canopy_at`), o dia não esquenta e o frio soma `RAIN_COLD`.
  - **Manadas (`Herd`, filho de Animals):** uma por casa em `ForestLayout.DEER_HOMES`, de `HERD_SIZE_MIN..MAX` cervos. A manada tem um centro; cada cervo pasta em volta dele (`Animal.home = centro`, `home_radius`) e anda até ele quando fica longe (`Animal.regroup`). Modos pelo `Clock`: `ROAM` (de dia o centro vai de pasto em pasto pelo vale a `HERD_ROAM_SPEED`), `HOMEWARD` (fim da tarde), `SLEEP` (de noite em casa, `Animal.sleep`, estado `SLEEP`: `SLEEP_SIGHT` e `SLEEP_HEARING`) e `SHELTER` (chovendo, vai para `forest.shelter_near`, a copa mais fechada por perto, e fica parada, `Animal.stand`; ali, o cervo a mais de `HERD_SHELTER_REJOIN` m além do espalhamento volta para debaixo da copa: com a distância de sempre, 9 m, metade pastava na chuva). Depois de uma fuga o centro passa a ser onde os cervos pararam. O sono do goblin põe a manada em casa (`place_near`). A cada amanhecer ela volta ao tamanho e a floresta repõe coelhos e javalis (`_restock`), sempre a mais de `RESTOCK_MIN_DISTANCE` do goblin.
  - **Caça legível:** o corpo avisa antes da fuga: com `DEER_ALERT_AT` o bicho para de pastar (orelhas em pé), desconfiado encara em silêncio e com `DEER_STOMP_AT` bate a pata e bufa (`Animal._on_stomp`). A ferida sangra até matar (`Animal._wound`, `BLEED_PER_DAMAGE`, mais rápido correndo). O cervo se acalma a 40 m (`calm_distance`); sozinho muda de casa, com manada volta para ela. Coletar dá `bone`.
  - **Mira com fôlego (`AimGuide`):** com o arco puxado e o ar preso, desenha a queda da flecha (`Arrow.start_velocity`, `Arrow.gravity_of`) até bater ou `AIM_GUIDE_MAX`.
  - **Tocaia (`BlindField`, persist):** a receita especial `&"blind"` monta galhos aos pés do goblin (no máximo `BLIND_MAX`); agachado a menos de `BLIND_RADIUS`, `visibility_factors[&"blind"] = BLIND_VISIBILITY`.
  - **Coleta (`ForageField`, persist):** `FORAGE_MUSHROOMS` tufos ao pé de árvores vivas e `FORAGE_BERRIES` arbustos onde a mata começa, sempre nos mesmos lugares (semente fixa). Cada `ForageSpot` colhido volta em `FORAGE_REGROW_DAYS`. Comidas novas em `Tuning.FOODS` e `FOOD_PREFERENCE`.
  - **Defumador (`SmokingRack`, filho da Cave, persist):** até `SMOKE_RACK_SLOTS` pedaços crus; com a fogueira acesa, `SMOKE_HOURS` de fumaça viram `smoked_meat` (no sono, conta o que a lenha durou).
  - **Equipamento:** receitas `bone_arrows` (dano `BONE_ARROW_DAMAGE`, vai primeiro na corda), `yew_bow` (`Arrow.speed_scale = YEW_BOW_SPEED`, `Player.tremor_factors[&"yew"]`) e `fur_bed` (`Vitals.rest` com `FUR_BED_HEAL`/`FUR_BED_SATIETY`; a pele ganha mais camadas). `GoblinAnimator.tremor_scale` multiplica o tremor do arco.
  - **Prática (`Practice`):** contadores `stealth_seconds` (andando agachado) e `arrow_hits` (`Events.arrow_hit`) no Story; o ganho é `1 - e^(-x/k)` até `PRACTICE_STEALTH_MAX` de barulho a menos (`noise_factors[&"practice"]`) e `PRACTICE_STEADY_MAX` de tremor a menos.
  - **Troféus (`Trophies`, filho da Cave):** galhadas (`deer_harvested`), presas (`boar_harvested`) e o crânio do Velho (`old_deer_harvested`), presos na parede por raios.
  - **O Velho (`OldDeer`):** do dia `OLD_DEER_FROM_DAY` em diante, `OLD_DEER_CHANCE` por amanhecer (`forest._maybe_old_deer`, `spawn_old_deer`) até ser caçado; maior, mais vida e sentidos; vai embora às 19h longe do goblin.
  - **Javali (`Boar`):** em `ForestLayout.BOAR_HOMES`. Assustado de longe foge; a menos de `BOAR_CHARGE_RANGE` ou ferido, investe (`Boar.charge`: `RUN` → `PAST` → `GLARE`, vira a `CHARGE_TURN` para dar para desviar), fere `BOAR_DAMAGE` e, depois de `BOAR_CHARGES` investidas, foge.
- **Zelador (`Keeper`, F6):** a IA (o corpo é o `Caretaker`). Estados `DOCKED`, `ROUND`, `CHECK`, `FOUND`, `CAPTURE`, `DORMANT`, `TALK` e `ESCORT` (os dois da F8, sem sentidos), com a lente verde, âmbar e vermelha. Sentidos pelo `Senses`: cone de `Tuning.KEEPER_FOV`, alcance menor no escuro (`Shelter.is_dark`) e com Ari rastejando; ouve `noise_level()` e `Events.noise_made`; térmico de 3 m através de parede; o sensor do corredor (`Shelter.sensor_active`) avisa quando Ari passa embaixo. Anda pelo grafo `Keeper.POINTS`/`LINKS`, ou reto quando dois raios (0,4 e 1,1 m) passam livres. Números em `Tuning.KEEPER_*`.
- **Vazio do norte (`NorthVoid`, R3):** com `climate_cut`, `Terrain.set_north_cut` e `Vegetation.set_north_cut` escondem os blocos além de `Tuning.VOID_EDGE_Z`, que precisa cair numa divisa de bloco de 48 m. Na borda ficam um corte preto sem neblina, uma parede invisível e um fundo preto distante que some no céu. `openness(ponto)` abre a neblina no setor norte (`forest.gd`) e escurece o chão do céu (`DayNight.void_amount`).
- **Voz do Zelador na floresta (Ato III):** corvo espião com `Crow.speech` fala no primeiro crocito pousado; um salto de Vigilância ≥ `Tuning.KEEPER_ROCK_VOICE_RISE` faz o `Clues` tocar a voz dentro do chão ao lado do goblin. As falas ficam em `StoryBeats.LINES`, e a legenda é `Game.vision.say()`.
- **Flashes (`FlashDirector`):** `Events.flash_requested` guarda o pedido; `Game.pass_out` mostra o flash no escuro, antes de acordar (`Game.play_flash`, com a versão curta na morte). Cada flash é uma função do tempo (`seek(t)` reproduz qualquer instante), com a câmera `Shelter.eyes` deitada na cápsula, a `BlurredVision` (`amount` = borrão, `lids` = pálpebras, `say()` = legenda) e o Zelador. No fim liga `flash_<n>_seen`.
- **Clock:** dia e hora (1 h de jogo = 60 s). Para enquanto `Game.resting`. Dormir pula o tempo de uma vez e emite `skipped(horas)` (a fogueira queima a lenha, a matilha some). `night()` vai de 0 (dia) a 1 (noite fechada, 20h30–5h), suave no anoitecer e no amanhecer.
- **Dia e noite (`DayNight`):** sol, cor e energia do céu e cor da neblina misturam `Tuning.DAY_LIGHT` e `NIGHT_LIGHT` por `Clock.night()`, com lusco-fusco quente no meio. A luz ambiente vem do céu, então a noite escurece tudo o que o fogo não ilumina; de noite, `NIGHT_AMBIENT_FLOOR` dela vira um piso azulado fixo (`NIGHT_AMBIENT_COLOR`, o olho acostumado). Na toca, a `Cave` acende de noite um holofote fraco sem sombra apontado para o chão (`NightFill`, `CAVE_NIGHT_FILL`), que não alcança a pintura do teto: a luz ambiente da sonda quase não mexia na imagem. De noite os bichos enxergam pior o goblin (`Tuning.NIGHT_VISIBILITY`).
- **Vitals:** o corpo de Ari: saciedade, vida, frio e enjoo. Fome zerada machuca, frio no máximo machuca, queda acima de 8 m/s machuca (`Player`), mordida de lobo machuca; vida 0 emite `Events.player_died`. Sem barra no HUD: o corpo avisa (ronco, mão na barriga, tremor, vapor da respiração, dentes batendo, borda escura da tela com vida baixa).
- **Frio (`ColdExposure`):** mede o ganho por segundo: noite × fora/dentro da caverna (`level.indoor_at`), vezes o vento no goblin, metade com a roupa (`clothes`); perto de fogo aceso (`Campfire.distance_to_fire`, grupo `fire`) esquenta. Dormir zera o frio.
- **Dormir e morrer (`Game.pass_out(reason)`):** mesma sequência. A tela escurece, o som fecha (`close_ears`), o relógio vai para as 6h30, e então Vitals descansa (sono) ou revive com a carne perdida (morte). O goblin volta para a pele e roda o `wake`. Emite `slept` e `woke_up(reason)`. Dormir salva.
- **Save:** além dos nós `persist` da fase, o `SaveSystem` salva os autoloads de `_globals()` (Inventory, Story, Clock, Vitals). Chave faltando carrega o padrão, então saves antigos abrem. `snapshot()` e `restore(payload)` fazem o mesmo na memória, sem disco; `describe_save()` dá "Dia 4 · Ciclo 347" para a lista de Carregar.
- **Wind:** força num ponto = `abrigo(p) × clima(t) × (0.35 + 0.9 × rajada(p, t))`.
  - A rajada é o `macro_noise.png` arrastado na direção do vento: as frentes de rajada atravessam a grama como ondas.
  - O abrigo vem do mapa `Terrain.build_wind_exposure()`: mata fechada, vales e caverna abrigam.
  - CPU (`Wind.strength_at`) e GPU (`foliage.gdshader`, globais `wind_*`) fazem a mesma conta.
  - O som, as folhas caindo e a poeira no ar usam `strength_at`.
- **Câmera:** braço próprio (`CameraPivot/CameraArm`), sem SpringArm. Na `PlayerCamera` (`_place`), uma esfera de 0,22 m vai da nuca até o ombro (deslocamento lateral real, não `h_offset`) e de lá para trás, só contra a camada 1. Ao bater, encolhe na hora; quando abre, volta devagar. Colada no goblin, o que está perto da lente some em dither, pixel a pixel (`Tuning.CAMERA_FADE_NEAR..FAR`: `distance_fade` em `PIXEL_DITHER` nos materiais comuns e `camera_fade_near/far` no `goblin_skin.gdshader`, ligados por `PlayerCamera._dither_near_camera` também nos itens que chegam na mão), e abaixo de `CAMERA_HIDE_DISTANCE` some de vez. Nada de `GeometryInstance3D.transparency`: a transparência de verdade mostrava o interior da boca e dos olhos. A casca da caverna tem `backface_collision` para a esfera não passar pelo verso dos triângulos. Mirando, a câmera chega a `Tuning.AIM_CAMERA_DISTANCE` com o ombro em `AIM_SHOULDER` e o pivô sobe `AIM_PIVOT_RISE` (com 1,5 m e 0,6 a cabeça do goblin tapava um quarto da tela).
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
- **Riscos na parede (`WallMarks`):** um por noite dormida, em grupos de 5, colados na rocha por raios (na primeira volta da física). Os antigos ficam sob um musgo (`moss_patch.gdshader`) que despenca quando o flag `moss_fell` liga: no 5º risco com um cervo coletado, ou no 8º (as pistas do Ato I vêm nos riscos 1 a 4). Isso abre o Ato II.
- **Árvores:** `Vegetation.trees` registra cada árvore em pé (posição, raio do tronco, seca ou não, instância no MultiMesh e colisão). `hit_tree()` derruba as secas depois de 4 golpes: a instância some, a colisão sai e uma cópia tomba.
- **Animação do goblin (`GoblinAnimator`):** 100% procedural, direto no esqueleto; as animações do glb ficam paradas.
  - Cada frame monta uma *pose* (dicionário: altura do quadril, alvo de cada pé, ângulos de tronco, cabeça, braços e orelhas) e só no fim converte em rotações de osso (`_rotate`: eixos do modelo em repouso, carregados pelo pai).
  - Pernas com IK de duas juntas: o pé segue uma trajetória (apoio no chão + arco no ar), então não escorrega e o joelho dobra. O sinal `foot_planted` toca o passo na hora em que o pé encosta.
  - Marcha (`_gait`, 0 = andar, 1 = disparar, pela velocidade): a perna tem 28 cm, então a cadência sai do alcance dela (`reach`) e o pé apoiado vai para trás na velocidade do chão. Andando, o pé pousa à frente com o calcanhar, o quadril sobe no meio do apoio e o calcanhar sobe atrás logo depois; correndo, há tempo no ar, o pé pousa quase embaixo do quadril, o calcanhar chuta até o traseiro, o joelho puxa o pé por baixo e o quadril afunda no apoio. Acima de ~1,5 m/s o passo já vira trote, por isso a caminhada (`Player.walk_speed`) é 2 m/s (passo ligeiro, no limite), agachado 1,5 m/s e o disparo 4,6 m/s. Correndo, a cadência tem teto (período mínimo 0,33 s): a velocidade a mais vira tempo no ar, não passos mais rápidos. O barulho dos passos vai de `Tuning.WALK_NOISE` andando a 1 no disparo; os bichos veem o movimento como velocidade ÷ `SIGHT_MOTION_SPEED`, nunca abaixo de `UPRIGHT_MOTION` andando de pé.
  - `_curve` é uma cúbica monotônica: passa pelas chaves do meio sem parar e não passa do valor das vizinhas. Chaves de ação podem ser densas sem o corpo "travar" em cada uma.
  - Camadas: andar/correr, respirar e olhar em volta parado, curva, agachar, pulo, aterrissar, mira e orelhas com mola.
  - Pulo (`_jump_pose`): o `Player` não sai do chão na hora; chama `begin_jump` e o corpo agacha por `Tuning.JUMP_PREP` (peito à frente, braços para trás), e só então vem o impulso (`jump_velocity` 2,9 m/s, uns 45 cm de altura, pouco mais que o quadril) e `jump_launched`. No ar a pose segue `vertical_speed`: pernas esticando com a ponta do pé no impulso, joelhos encolhidos no alto, pernas à frente procurando o chão e braços abertos na queda. Correndo vira salto: uma perna à frente e a outra dobrada para trás (`_jump_lead`), braços cruzados com as pernas. No pouso os braços vêm à frente.
  - **Nada perfeito:** a pose neutra (`_neutral`) já é a postura do goblin, curvada e assimétrica (ombro caído, cabeça torta, pés abertos para fora, braços pendurados). Por cima entram oscilações lentas (`_wave`) em cada parte, passadas com altura e abertura sorteadas, ritmo manco (pé direito atrasado), apoio que troca de perna parado e fôlego (ofega e apoia as mãos nos joelhos depois de correr).
  - Manias parado (`GoblinIdle.overlay`, com o estado delas): coçar a orelha, farejar, olhar para trás, examinar as garras. Não travam o jogador; qualquer movimento corta.
  - Arco: base de arqueiro (quadril e peito de lado, ombro do arco para o alvo, cabeça de volta olhando pela flecha, pés afastados), braço treme se segurar a corda puxada por mais de 1 s e coice ao soltar.
  - Mira com IK (`_aim_arms`, depois de toda a pose): a empunhadura vai para a linha que sai do canto da mandíbula, por fora da bochecha direita (`ANCHOR_REST`; embaixo do queixo a mão ficava longe demais do ombro e o antebraço atravessava o pescoço), até `aim_point`, um `draw_length` à frente; a mão da corda vai até `nock_depth` atrás da empunhadura real. `_reach` é IK de duas juntas por giros (braço até o cotovelo com `pole`, torção para o antebraço ficar no plano da dobra, antebraço até o punho), partindo dos ângulos da pose.
  - Pés: `_orient` deixa o pé paralelo ao chão no espaço do esqueleto, girado por `foot_*_yaw`; a perna abre com `leg_*_out`.
  - Pés no chão (`_ground_feet`): um raio por pé acha a altura e a inclinação do chão embaixo dele (degrau, pedra, encosta). O quadril desce para o pé mais baixo com apoio; pé sem chão fica pendurado, e com só um pé apoiado o peso vai para ele. `foot_supported` é lido pelo Player.
  - Coluna: o giro do tronco se divide entre `tronco` (lombar) e `peito`; por cima entram `spine_arch` (costas redondas em cima, lombar arqueada), `spine_bend` (curva de lado em S) e `neck_fwd` (`pescoco`). A soma lombar + peito é o giro antigo + arch / 2, então as poses dos braços continuam calibradas.
  - Borda (`_balance_overlay`): com `teeter` > 0 abre e gira os braços, joga o corpo para longe do vazio e olha para baixo.
  - Ações cronometradas com eventos (as poses ficam em `GoblinActions.pose`): `wake` (acordar), `pickup`, `harvest` (coletar caça), `punch`, `eat`, `cook` e `lie_down` (deitar para dormir). Faminto, a mania mais comum parado é a mão na barriga (`starving`). O Player só pega o item ou acerta o golpe no evento, quando a mão chega. Cada ação mexe o corpo todo (quadril, coluna, pescoço), com preparação e continuação: o soco arma girando quadril e ombro para trás e solta com o quadril na frente; pegar dobra no quadril com as costas curvas e sobe com o peito na frente.
  - Mecânica do corpo (`_body_mechanics`, depois das ações e antes do equilíbrio): (1) dobradiça, em que a inclinação acima de 0,2 rad vai em parte para a bacia (`pelvis_pitch`), o quadril recua (`pelvis_z`) e as costas arredondam; (2) braços, em que esticar um traz o ombro (giro do peito) e erguer acima do ombro inclina o tronco; (3) molas, em que o tronco segue o quadril por uma mola (~2,4 Hz), comprimindo a coluna (`_squash`) nos passos e na aterrissagem, e a velocidade do peito segue a do corpo (~1,2 Hz), inclinando ao arrancar e ao frear. A cabeça compensa a mola. Sinal de giro: `torso_yaw`/`pelvis_yaw` positivos levam o ombro/quadril direito para a frente (vira para a esquerda, +X).
  - Precisa dos ossos `perna/canela/pe`, `braco/antebraco/mao`, `orelha`, `tronco`, `peito`, `pescoco`, `cabeca` e `quadril`. Sem eles o animador desliga sozinho.
- **Equilíbrio (`EdgeBalance.update`):** no chão, se não há chão logo embaixo do centro do corpo, ele está na borda. O equilíbrio cai (mais rápido com um pé solto ou andando para o vazio; sem nenhum pé apoiado cai em ~0,25 s) e volta se ele andar para dentro ou se agachar. Se acabar, ele tomba para o lado do vazio (`_tipping`, sem `floor_snap`).
- **Arco:** `Player` mira com o botão direito (a câmera aproxima). Ao erguer o arco, encaixa uma flecha. Segura e solta o esquerdo para atirar. `Arrow` voa com gravidade, testada por raio a cada frame de física, e finca no que acerta.
  - Escala do goblin (braço de 32 cm): arco de 60 cm, corda a 8 cm da empunhadura, puxada de mais 21 cm, flecha de 38 cm.
  - `HeldBow` (filho do `Visual`, sem socket): o Player o põe todo frame em `GoblinAnimator.bow_grip_position()`, a pose do mesmo frame, porque um socket atrasaria um frame em relação à mão da corda. Carregado, fica deitado para a frente (`CARRY_RISE`) e balança com o antebraço; mirando, barriga para o alvo e um pouco deitado (`BOW_CANT`). Braços que dobram com `draw`, corda até `nock_depth(draw)` (volta reta ao soltar) e a flecha encaixada. A flecha sai da empunhadura para o ponto no centro da tela.
  - Depois do tiro, `RELOAD_TIME` (0,75 s): a mão vai até a aljava (`GoblinAnimator.reload`) e só então a próxima flecha aparece na corda, com o som de encaixe.
- **Grama no relevo:** `Terrain.publish_height_texture()` publica as alturas como global `terrain_height`. Com `follow_ground = 1` (grama e samambaia), o `foliage.gdshader` sobe ou desce cada vértice com o chão embaixo dele.
- **Lobos:** `WolfPack` (filho de Animals) traz `Tuning.WOLF_COUNT` lobos a partir do dia 3: às 20h30 eles aparecem na borda do vale esperando (`Wolf.waiting`: rondam ali sem seguir o rastro do goblin) e um deles uiva o aviso; chegada às 21h, saída às 5h30, e somem se o goblin dorme. `Wolf extends Animal` reaproveita os sentidos e troca a reação: ronda (a área de caça escorrega para o goblin), espreita a 9 m rosnando, caça e morde. Não chega a menos de 6 m de fogo aceso e, ao contrário dos outros bichos, pode entrar na caverna. Uma flechada o faz fugir e ir embora; duas matam.
- **Pegadas (`Tracks`):** bicho com `track_size` deixa uma pegada a cada `Tuning.TRACK_SPACING` andados (alternando os lados da fila com `track_side`). O MultiMesh tem um pool de `Tuning.TRACK_POOL` (1600: as cinco manadas e os coelhos carimbam ~10 por segundo, e com 200 o rastro sumia em 20 s) e o shader (`track_print.gdshader`) desenha casco, pata de coelho ou de lobo e apaga pela idade. `Tracks.nearest(espécie, ponto, raio)` acha a pegada fresca mais perto (o laço usa). Dormir envelhece todas.
- **Farejar (`SniffAbility`, X):** agachado e parado, até `Tuning.SNIFF_MAX_SECONDS`. Fecha o som com `Game.close_ears`, mostra riscos de vento e uma trilha de cheiro (partículas por cima de tudo, a 1 m do chão) de cada bicho até `Tuning.SNIFF_RANGE` cujo cheiro o vento traz.
- **Fôlego (`BreathControl`, Q):** prendendo o ar, parado não faz barulho (a respiração ofegante depois de correr faz) e o arco puxado não treme; o coração bate cada vez mais rápido. Passando do limite, bufa (`noise_made`) e fica ofegante.
- **Pedras e susto:** G joga uma `ThrownStone` (`StoneThrow`); onde ela bate faz `noise_made` de `Tuning.STONE_NOISE`. O `Animal` guarda o susto (`_startle`, 3 s): o perigo fica sendo o lugar do barulho (ou de onde a manada se assustou) até ele ver o goblin com clareza. É o que deixa tocar a manada.
- **Lama:** `MudPuddle` ("Esfregar lama", ação `rub_mud`) põe `Vitals.mud` em 1; `MudCamouflage` gasta em um dia (mais rápido correndo), põe os multiplicadores de visibilidade e cheiro e a global de shader `goblin_mud` (manchas no `goblin_skin.gdshader`).
- **Fabricar (`CraftAbility`, R):** lista no canto com `Recipes.LIST`. O tempo não para; a animação `craft` dura `Tuning.CRAFT_TIME` e o custo sai no fim. Emite `Events.crafted(id)`, que o Story conta.
- **Tocha (`Torch`, `TorchCarry`):** na mão direita, segue o socket da mão. É fogo (grupo `fire`): esquenta e afasta lobo. Os bichos veem mais o goblin (`Tuning.TORCH_VISIBILITY`). Mirando, ela é fincada no chão.
- **Laço (`Snare`, `SnareField`):** armado sobre pegada de coelho; `SnareField` (persist) sorteia a captura com o goblin longe, e as horas dormidas contam de uma vez. Pegou: um `Rabbit` morto (`Animal.kill()`) fica no laço para coletar.
- **Corvos:** cada corvo do `CrowFlock` é um `Crow` com área de acerto (camada 4). Flechada derruba; no chão, E dá penas. A `Arrow` acerta qualquer área cujo dono tenha `take_hit` e devolve o próprio tipo de flecha (`Arrow.collect_from`).
- **Bichos** (`Animal`, ver também F9 acima):
  - visão em cone com linha de visada e movimento pesando mais que forma parada; pastando enxergam mal;
  - audição do `noise_level()` do jogador e de `noise_made`;
  - olfato quando o vento sopra do jogador para o bicho;
  - `awareness` leva a desconfiado e depois a fuga; a manada foge junta. A atenção não passa de estímulo × `Tuning.ANIMAL_AWARENESS_CEILING`: sinal fraco (longe, de lado, cheiro ralo) só deixa desconfiado, por mais que dure. Um cervo alerta foge do goblin andando de pé a ~18 m (alcances de visão, audição e faro em cada espécie: cervo 25/19/19 m, Velho 30/23/25, coelho 16/12/10, javali 14/16/27, lobo 19/22/50, cervo branco 12/8/10);
  - passos com os mesmos sons de chão do goblin (`Footsteps.SOUNDS` pelo `surface_at`), andando (`step_stride`) e correndo (`gallop_stride`, `Tuning.ANIMAL_RUN_STEP_DB` mais alto);
  - ferido, sangra e fica lento; morto, vira `interactable`;
  - **corpo (`CreatureModel`):** o modelo da espécie (`assets/models/animals/*.glb`) com esqueleto. Cada osso vira um
    pivô (Node3D com o nome do osso, na junta, sem giro) e o código do bicho anima os pivôs; `Animal._process` chama
    `model.sync()`, que dá a cada osso o mesmo movimento do pivô desde o repouso (até `CreatureModel.SYNC_RANGE`).
    Flechas presas (no pivô `corpo`) e as pegadas seguem iguais. Ossos: `corpo`, `peito`,
    `pescoco`, `cabeca`, `orelha_E/D`, `cauda` e as pernas `d_`/`t_` (`coxa` → `canela` → `pata`, `_E`/`_D`); aves:
    `corpo`, `cabeca`, `asa_E/D` (o corvo também `pernas` e `cauda`). Asas e pernas escondidas = pivô com escala ~0;
  - **pelo (`AnimalLook`):** cada região do modelo (`bicho.pelo`, `bicho.claro`, `bicho.casco`...) recebe da paleta
    da espécie [textura, tinta] (`pelt.png`, `bristle.png`, `plumage.png` no `animal_skin.gdshader`, projetado na
    pose de repouso como a pele do goblin) ou uma cor lisa. Malha e materiais são feitos uma vez por espécie;
  - **passo (`QuadrupedGait`):** cervo, javali e lobo andam em quatro tempos e galopam com tempo no ar; o ciclo anda
    com a distância (`stride_walk`/`stride_run`), e no ar o carpo e o jarrete dobram. `fold()` deita, `lift_front()`
    bate a pata;
  - **morte (`CreatureDeath`, só quem tem `t_coxa_E`: cervos, coelho, javali e lobo; aves não):** `Animal._fall` parte da
    pose em que o bicho estava: as dianteiras dobram, o peito desce, o corpo tomba de lado (para onde a flechada
    empurrou, `_hit_side`), bate e assenta com as pernas moles, o pescoço para trás e a cabeça no chão; depois a
    traseira de cima chuta e vem o último fôlego (parado em `CreatureDeath.STILL`). Correndo, escorrega uns 3 m com o
    embalo (`_slide`), e o bicho todo deita junto com a encosta. Cada espécie ajusta em `_setup_death` (altura
    deitado = `dead_height`, rolagem, pernas, pescoço; o Velho apoia a cabeça na galhada). `kill()` (laço) já põe
    a pose final.

  O jogador expõe `noise_level()` e `visibility()` (agachado, parado e coberto por capim ou mata).
- **Física, camadas:** 1 `world` (terreno, caverna, pedras, troncos caídos), 2 `trees`, 3 `player`, 4 `animals` (Area3D de acerto), 5 `combat` (áreas de acerto do goblin e dos orcs, F12), 6 `monsters` (corpo dos orcs; o goblin esbarra). Raios de som só testam a camada 1. Visão dos bichos: 1 e 2. Flechas: 1, 2, 4 e 5.
- **Bichos do ambiente:** regra: **todo som de bicho sai de um bicho de verdade**, no ponto onde ele está (nada de
  loop no ouvido nem chamado de ponto sorteado). Números em `Tuning` (bloco "Bichos do ambiente").
  - **Insetos (`InsectField`, filho do `Ambience`, montado por `Ambience.build_life`):** `CRICKET_COUNT` grilos
    (de noite, capim até a borda da mata) e `GRASSHOPPER_COUNT` gafanhotos (de dia, no aberto), sempre nos mesmos
    lugares, cada um com tom e hora de começar próprios. Os `INSECT_VOICES` mais perto que cantam ganham um
    `AudioStreamPlayer3D` com o canto de um bicho só (`cricket_song`, `grasshopper_song`). Os de longe (até
    `INSECT_CHORUS_RANGE`) são agrupados em células de `CLUSTER_CELL` m: as `CLUSTERS` que mais soam ganham um
    `OccludedAudio` com o coro (`crickets_loop`, `grasshoppers_loop`) no meio dos que cantam ali, a
    `CLUSTER_DB` + 10·log10(quantos). Goblin andando perto ou `Events.noise_made` calam; o gafanhoto do pé pula.
    Chuva e vento forte calam todos.
  - **Pássaros (`BirdLife`, filho de Animals, e `Bird`):** canoros na copa das vivas, pica-paus agarrados no tronco
    das secas (o eixo torto vem do meta `trunk` da malha, `TreeBuilder.build_dead_tree`) e corujas na mata fechada.
    Cantam do galho pelo `Ambience.call_at` (abafa atrás de rocha; depois do R4 traz a voz do Zelador), com o coro
    do amanhecer. O goblin a menos de `BIRD_FLUSH_RADIUS` (metade agachado e devagar) ou um barulho espanta: pio de
    alarme, bater de asas e voo para outra árvore. Árvore derrubada também espanta. Só cantam perto do ouvido
    (`BIRD_ACTIVE_RANGE`).
  - **Corvos:** a voz do bando (`CrowFlock`) voa junto com o corvo que grasna.
  - **Uivos (`WolfPack`):** `Wolf.howl(segundos)` para o lobo de focinho para cima, e o som sai de
    `mouth_position()` pelo `Ambience.call_at` (`Ambience.howl_sound()` escolhe a gravação). Matilhas distantes:
    cada noite sorteia de 0 a 3 rodadas (`DISTANT_HOWL_WEIGHTS`) entre 21h e 4h; cada uivo é um `Wolf` com
    `distant` (parado, sem caçar) além da borda do vale (`DISTANT_HOWL_RING`, a mais de `DISTANT_HOWL_MIN_DISTANCE`
    do goblin), que some `DISTANT_WOLF_SECONDS` depois. Outros respondem (`HOWL_ANSWER`), e às vezes uma matilha
    distante responde ao aviso da do vale (`DISTANT_HOWL_REPLY`).
- **Ouvido (`Game.open_ears`):** passa-baixa no Master. Toda troca de fase abre o som em 2,5 s (quem chega a um lugar); o despertar da floresta abre em 7,5 s, de -42 dB e 160 Hz: o volume sobe primeiro e os agudos chegam por último. Loops de ambiente e `OccludedAudio` com autoplay começam num ponto sorteado.
- **Áudio, buses:**
  - `Ambience`: sons de fora. Passa-baixa que fecha dentro da caverna e eco de vale.
  - `World`: fogo, passos, flechas. Reverb que abre dentro da caverna.
  - `AmbienceMuffled` e `WorldMuffled`: passa-baixa, para sons atrás de rocha (OccludedAudio troca sozinho).
- **ForestLayout** é a fonte única dos pontos do mapa. Terreno, vegetação, bichos e som leem dali.
- **Regra de comunicação:** pai → filho por chamada; filho → pai por sinal; sistemas distantes pelo `Events`.

## F10: polimento e orientação

- **Subir degraus (`StepClimber`):** depois do `move_and_slide`, andando contra uma parede, três `body_test_motion` (sobe `Tuning.STEP_HEIGHT`, anda `STEP_PROBE`, desce até chão não íngreme) dizem se cabe um degrau; cabendo, o corpo sobe e `offset` (≤ 0) desce o `Visual` e o pivô da câmera, voltando a 0 em `STEP_SMOOTH`. Degrau acima de 30 cm continua sendo parede.
- **Marcos na neblina:**
  - **Marco de pedras** (receita `&"cairn"`, 3 pedras): a `CraftAbility` chama `CairnField.build_at` 0,7 m à frente do goblin; torre de `CAIRN_STONES` pedras (`ThrownStone.stone_mesh`), com colisão, no máximo `CAIRN_MAX`, salva (persist).
  - **Tronco riscado:** a parte `TreeMarker` (como a `SnareSetter`) vai para o pinheiro vivo a até `TREE_MARK_REACH`; "Riscar o tronco" faz a ação `scratch` e `TreeMarks.mark` desenha a casca raspada (`tree_blaze.png`) dos dois lados do tronco. Salvo por id de árvore (`forest.tree_base`, `tree_radius`, `tree_standing`).
  - **Fumaça da toca (`CaveSmoke`):** partículas acima da boca da caverna, só com a fogueira acesa (`amount_ratio` pela lenha; reaplicar `emitting`/`amount_ratio` reinicia as partículas, então só muda quando muda). Fica fora da neblina (`disable_fog`) e some pela distância (`CAVE_SMOKE_FADE`), sem turbulência; o vento deita a coluna (`CAVE_SMOKE_WIND`, aceleração constante).
  - **O sino da ruína (`RuinBell`):** pende da espadana (`Ruin._build_bell_gable`) e balança com `Wind.aloft_at` (clima × rajada, sem o abrigo do chão). Acima de `BELL_WIND_THRESHOLD`, o badalo bate (`bell_clank_1/2`, sintético) no fim de cada ida, com `BELL_COOLDOWN`. Pista de duas leituras: é o sino da cidade do Final 2.
- **Dicas progressivas:** o contador automático `stuck_sleeps` soma a cada sono e zera quando liga um flag de `StoryBeats.PROGRESS_FLAGS` ou o ato muda. Os beats `hint_*` (`on: slept`) põem anotações de Ari apontando o próximo passo (porta, ritual, R1–R4, sala de controle, gravações, o `ciclo_346.sav`) depois de alguns dias parado. O Ato I não tem dica.
- **Aviso de anotação:** o HUD emite "Anotação nova. [Esc] Dicas" em cada `Story.note_added`; no escuro (sono, flash, Abrigo, cena) espera e sai `NOTE_NOTICE_DELAY` s depois de acordar.
- **Sair sem salvar:** o `SaveSystem` conta os segundos de jogo desde o último salvar/carregar/começo (`unsaved_seconds`, `can_lose_progress`). "Menu principal" e "Sair do jogo" do pause passam por `PauseMenu.ask_leave(ação)`, que pergunta ("Salvar e sair", "Sair sem salvar", "Voltar") depois de `UNSAVED_WARN_SECONDS`. O X da janela também (`Game._notification`, `set_auto_accept_quit(false)`).
- **Controle:** o `Settings` guarda o último aparelho (`using_gamepad`, emite `changed(&"input_device")`). `key_label`/`key_labels` mostram os botões do controle (`PAD_NAMES`: A, B, X, Y, LB, RB, LT, RT, Menu, L3, Cruz ↓...; `{move}` vira LS); a tela de teclas usa `keyboard_label`. Ari olha com o analógico direito (`ARI_GAMEPAD_LOOK_SPEED`). O console do Zelador tem comandos rápidos navegáveis e fecha com B.

## F11: luta (experimental, branch `experimento/combate`)

Plano completo em `docs/plano_combate.md` (F11 a F14). Feito até agora:

- **Armas (`Weapons`, `data/weapons.gd`):** faca de pedra, faca de osso, porrete e lança (dano na unidade da flechada, tipo, alcance, fôlego, postura, velocidade, desgaste, furtivo, conserto). `Inventory.held()`/`hold()` é a arma na mão (&"" = o arco); desgaste por unidade (`wear`, `wear_down`, `repair`, chave `__wear`; `add(item, n, worn)`).
- **`MeleeAbility` (parte do Player):** golpe leve (encadeia até `COMBO_MAX`), forte segurando `HEAVY_HOLD`, defesa (o botão de mirar com arma de mão; com a lança, firmada), aparo nos primeiros `PARRY_WINDOW` s, esquiva (`dodge`) com invulnerabilidade, fôlego e postura sem barra. A lâmina acerta pelo `WeaponTrace` (`components/`): esferas no caminho dela entre dois quadros, contra as camadas 4 e 5. Tab (`weapon_swap`) passa pelas armas.
- **Golpes no goblin:** sempre por `Player.receive_attack(attack)` (dano, tipo, de onde, postura, causa, quem bateu, tranco, investida), que passa pela `MeleeAbility.defend` e devolve `hit`, `blocked`, `parried`, `dodged` ou `braced`. O lobo e o javali usam; quem pode ser aparado implementa `stagger(segundos)`. `Player.shove(v, s)` é o tranco (a velocidade é do empurrão por `s`).
- **Corpo:** poses de luta em `GoblinActions` medidas por `GoblinAnimator.strike_window`; `weapon_style` e `guarding` no animador (`_weapon_overlay`). O `PlayerGear` põe a arma na mão a cada quadro (uma mão: o cabo sai `ONE_HAND_TILT` acima do antebraço; a lança vai da mão direita para a esquerda) e o arco nas costas.
- **Cura:** `Vitals.bleeding` e `herb`; F põe a bandagem sangrando e come a erva ferido. Musgo no tronco das árvores secas (some quando a árvore cai), erva na mata fechada.
- **Bancada (`Workbench`, filha da Cave):** receita `&"bench"` só dentro da toca; receitas com `"station": &"bench"` e o conserto (`&"repair"`) só perto dela.
- **Equipamento de guerra (F13-A):** `Armor` (`data/armor.gd`): peças por lugar (cabeça, corpo), a melhor que o goblin tem é a vestida (`Armor.worn`), proteção por tipo (`protection`) aplicada na `MeleeAbility._take`, e custos (`factor("noise"|"speed"|"stamina"|"cold")`) no Player e no ColdExposure; o escudo (`shield_in_use`, só com arma de uma mão) na defesa. Visual na parte `ArmorLook`. Couro curtido no defumador, machado no pinheiro vivo, flecha de ferro (`&"iron"` no orc).
- **Morte e guardar (F13-B):** `BagField` (filho da floresta) põe o que não está vestido (`BagField.KEEP` e as armaduras ficam) num `DroppedBag` onde o goblin caiu, ou no baú do `OrcCamp` com um orc perto (`ORC_LOOT_RANGE`); `take_carried`/`give_back` levam o desgaste junto. `OrcCamp` (filho da floresta, `pick_center` acha o chão livre perto de `ForestLayout.ORC_CAMP`): paliçada, tendas, tambor, fogueira, `OrcChest` e guardas. `CaveStash` (filho da Cave, receita `&"stash"`): guarda tudo; agachado, pega.
- **Guerra e segunda leitura (F13-C e F14):** o chefe (`Orc.kind == &"chief"`, `resident`, investida `_start_charge`/`_charge_step` que o deixa tonto num `is_on_wall`, golpe de cima que o prende, flag `chief_dead`), a Investida na `OrcBand` (`warn_raid`, `start_raid` com `raider` = tocha e a toca liberada, `end_raid`; flag `raid_tonight` bloqueia a pele de dormir), `TrapField` (estacas e corda de ossos, receitas especiais `&"stakes"`/`&"bones"`). A luta agita Ari (`OrcBand.on_fight`, `Tuning.VIGILANCE_FIGHT*`), a luta pesada encurta a visita (`hard_fight_today`), o gatilho `orc` do Story (`seen`, `killed`, `chief`) com as anotações, e `confession_orcs` põe as falas das máscaras na conversa (`ControlRoom.confess`).
- **Orcs (F12, `scenes/monsters/orc/`):** o modelo sai do goblin (`assets/models/orc/source/build_orc.py`, mesmo esqueleto) e usa o `GoblinAnimator` com o nó escalado (`ORC_MODEL_SCALE`). `Orc` (CharacterBody3D, camada 6; área de acerto na 5): estados, sentidos pelo `Senses`, golpe pelo `WeaponTrace` curvando o corpo (`strike_bend`), zonas e ferro (`Orc.strike(dano, tipo, ponto, direção, postura)`), ajoelha aparado, foge com a moral baixa, revistar. `OrcBand` (filho da floresta, grupo `orc_band`): chegada por dia, rotas, grito, vez de atacar; desligado no Bem-vindo, depois de Ficar e com `orcs_off` (`ameaca off` no console). Nos testes, só com `--orcs` ou `--spawn=orc:x,z[:warrior]`. O goblin tem `Hitbox` (camada 5) e `take_hit`; os bichos (menos o lobo) fogem do orc.

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
- A neblina (`fog_density` 0,016) esconde o corte de distância. A neblina é a mesma dentro e fora da caverna: de dentro, o vale tem de parecer igual.

## Assets

- **Texturas:** 100% procedurais (`tools/generate_textures.py`; as da interface em `tools/generate_ui.py`).
- **Fonte:** a Toca é desenhada pixel a pixel em `tools/generate_ui.py` (maiúsculas de 9 px, acentos compostos) e
  sai em BMFont. Letra nova: acrescente em `GLYPHS` (ou `COMPOSED`) e rode o gerador.
- **Sons:**
  - Gravações reais CC0 em `assets/audio/real/`:
    - passos em grama, terra, pedra e tronco, casco do cervo, impactos de flecha, golpe na madeira, rangido, coleta e faca (Kenney). Pedra e tronco passaram por passa-baixa, porque o goblin anda descalço;
    - puxar, encaixar e soltar o arco (Medieval SFX, OpenGameArt).
  - Passos em terra (`step_dirt_*`): gravação real numa estrada de terra (Freesound, CC0), cortada passo a passo com um expansor para o ambiente da gravação não sobrar no fim. A caverna (`step_cave_*`) usa os mesmos cortes, com passa-baixa de 3 kHz e um tom abaixo. Já foram testados e rejeitados: as gravações de sapato do RPG Audio (o "toc-toc" de salto e ponta), passo sintético e passos de carpete ou neve abafados.
  - Gravações do Freesound e do Wikimedia (CC0) no lugar de 27 sintéticos: folhas, fogueira, lâmpada, ventilador,
    sino, bater de asas, corvo 1, bufo e pata do cervo, guincho do javali, rosnados e ganido do lobo, puxar e soltar
    o ar, farejar, roncos da barriga, mastigar, dentes batendo (montado com um estalo real repetido), mordida (montada: rosnado,
    mandíbula, carne e esmagar), árvore caindo,
    pedra jogada, persiana, glitch e porta blindada. Os brutos ficam fora do
    repositório (links no CREDITS.md); `tools/process_real_sounds.py --raw=PASTA` corta, põe em mono, iguala o volume
    ao do sintético que saiu (`LEVELS`) e grava em `audio/real/`: loops em WAV com chunk smpl e emenda cruzada de
    2 s, o resto em OGG. O sino lá fora tem três badaladas e o `Outside` o repete pela duração dele.
  - O resto é sintético (`tools/generate_sounds.py`); os sons que viraram gravação saíram de lá.
  - A lama (`mud_rub`) é modelo físico preso ao tempo da animação `rub_mud`: bolhas que sobem de tom (`mud_bubble`),
    o barro escoando com gorgolejo (`mud_sink`), a sucção da mão saindo (`mud_suction`), o esfregar na velocidade da
    mão (`mud_smear`) e as gotas da sacudida (`mud_flick`). O caráter da lama fica em `MUD` (wet, thick, sticky...).
    Nenhuma gravação CC0 serviu em quatro rodadas de audição.
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
  - Nada perfeito também na malha: o crânio é um `blob` deformado por `skull_shape` (testa baixa, alto da cabeça estreito subindo para trás, têmporas fundas, calombos, lado esquerdo mais cheio), e depois da união a pele inteira ganha calombos lentos (ondas com semente 346), mais fracos no rosto e em volta dos olhos.
  - Nada colado por cima da pele: boca, narinas, órbitas, concha da orelha e unhas são entalhadas na própria malha do corpo. Depois do decimate, só essas regiões (e as pontas dos dedos) são subdivididas (`near_feature`), entalhadas (sulco da boca entre os lábios, furos das narinas, órbita que afunda atrás do globo, de modo que as pálpebras são a pele em volta) e pintadas face a face (`boca`, `orelha_interna`, `unha`). Os olhos são globos (`EYE_R`) com a pupila em fenda pintada no próprio globo, e as presas nascem de dentro do sulco. O nariz é uma cunha (`corpo_nariz`) que nasce larga do rosto e afina até a ponta; as sobrancelhas são saliências afundadas no crânio.
- **Bichos:** `assets/models/animals/source/build_animals.py` (Blender, por linha de comando) monta cada espécie como o
  goblin: corpo de lofts, tubos e bolhas fundido por remesh de voxel, suavizado, com calombos e reduzido; detalhes à
  parte (cascos, olhos, focinho, orelhas, galhada, presas, crina, garras, bico, rêmiges); regiões por função da
  posição; pesos pela distância ao osso em "raios de carne", mas na perna a pele é do osso mais perto e só se
  mistura com o vizinho perto da junta (`_joint_blend`; antes a coxa grossa puxava a canela fina e a perna torcia).
  Os anéis dos tubos seguem o anterior (`_frames`, transporte paralelo): com um referencial solto por anel, a
  perna quase vertical virava de lado no carpo e saía com cintura de ampulheta. As medidas ficam no espaço do
  Godot. Regerar:
  ```powershell
  & $blender --background --python assets\models\animals\source\build_animals.py -- [especie ...] [--preview=pasta]
  ```
  `--preview` grava renders de conferência (lado, frente, trás). Depois rode o `--import` do Godot.
- **Arco e flechas:** montados em código.
- **Props montados por código** (arbusto e cogumelos da coleta, tocaia, defumador, troféus): nada de caixa com cor chapada. Galhos com `TreeBuilder.add_branch`/`crooked_line` e a casca das árvores, folhagem em cartões no `foliage.gdshader` (`bush_card.png`, `berry_card.png`, `pine_branch.png`) e osso/cogumelo com textura pixelada triplanar, tudo pelos materiais de `PropLook`.
- **Assets de terceiros:** só CC0 ou licença compatível, registrados em `assets/CREDITS.md`.

## Ainda não existe

- Diálogos, missões, atributos (a luta corpo a corpo está entrando na branch `experimento/combate`).
- Água.
