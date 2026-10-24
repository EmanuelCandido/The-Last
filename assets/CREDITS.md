# Créditos de assets

Feito para o projeto:

- texturas: `tools/generate_textures.py`;
- sons sintéticos (vento, caverna, insetos, grilo e gafanhoto sozinhos, pássaros, pio de alarme, corvo 2, pica-pau, uivo de reserva do lobo, gotas, guincho do coelho, carne chiando, musgo caindo, grilos, coruja, mordida do lobo, coração, pedra caindo, lama, laço fechando, bipe do monitor, porta de pedra, disco de pedra, ar de sala fechada, servo, roda e bipe de passo do Zelador, voz sintética do Zelador, áudio travado, pedra riscando a rocha, multidão, chuva, grunhido do javali): `tools/generate_sounds.py`;
- cortes e tratamento das gravações que substituíram sintéticos (tabela "Freesound e Wikimedia" abaixo): `tools/process_real_sounds.py`.
- goblin: `models/goblin/source/` (blender-agent + polimento procedural no Blender).

Gravações reais de terceiros, em `audio/real/`. Todas são CC0 (domínio público): não exigem crédito, mas ficam registradas aqui.

| Arquivos | Origem | Autor | Licença |
|---|---|---|---|
| `step_grass_*` (footstep_grass), `step_stone_*` (footstep_concrete, com passa-baixa de 2,4 kHz: pé descalço), `step_wood_*` (footstep_wood, passa-baixa de 3,2 kHz), `arrow_hit_wood_*` (impactWood_light), `arrow_hit_ground_*` (impactSoft_medium), `arrow_hit_flesh_*` (impactPunch_medium), `tree_hit_1..3` (impactWood_heavy) | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 |
| `hoof_dirt` (footstep02, casco do cervo correndo), `tree_hit_4` (chop), `wood_creak_*` (creak), `pickup_*` (cloth, handleSmallLeather), `craft_*` (knifeSlice, drawKnife) | [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney | CC0 |
| `bow_draw_*`, `bow_nock_*`, `bow_release_*` (cortes de English Longbow Draw/Nock/Shoot e Scythian Recurve Shoot, convertidos para 48 kHz mono) | [Medieval sound effects – Weapon Textures](https://opengameart.org/content/medieval-sound-effects-weapon-textures) | OpenGameArt | CC0 |
| `step_dirt_1..6` (seis passos cortados de "Footsteps Dirt Road 1.wav" em 0,11 / 0,68 / 1,10 / 2,09 / 2,655 / 3,13 s, 0,3 s cada, com expansor no fim; prévia OGG de alta qualidade); `step_cave_1..6` (os mesmos cortes com passa-baixa de 3 kHz e 5 a 10 % mais graves) | [Freesound #682127](https://freesound.org/people/HenKonen/sounds/682127/) | HenKonen | CC0 |
| `animals/wolf_howl_real_1..3` (três uivos cortados de "Cooper Creek 20160313 014852 solitary wolf howl very clear") | [Freesound #500646](https://freesound.org/people/betchkal/sounds/500646/) | betchkal | CC0 |

### Freesound e Wikimedia (substituíram sons sintéticos)

Todas CC0 ou domínio público. Usada a prévia OGG de alta qualidade do Freesound (o original pede login); cortes, mono, 48 kHz no máximo e o mesmo volume do sintético que substituíram, por `tools/process_real_sounds.py` (os loops ganham emenda cruzada de 2 s).

| Arquivo em `audio/real/` | Uso no jogo | Origem | Autor | Licença |
|---|---|---|---|---|
| `leaves_wind_loop.wav` | folhas ao vento (loop) | [Freesound #378725](https://freesound.org/people/lunchmoney/sounds/378725/) "Leaves Rustling in Wind - Zoom H6" | lunchmoney | CC0 |
| `campfire_loop.wav` | fogueira e tocha (loop) | [Freesound #729396](https://freesound.org/people/HECKFRICKER/sounds/729396/) "Campfire 02" | HECKFRICKER | CC0 |
| `fluorescent_buzz_loop.wav` | lâmpada que falha no Abrigo (loop) | [Freesound #638895](https://freesound.org/people/Developer_Jake/sounds/638895/) "Fluorescent lightbulb hum buzz (Extended)" | Developer_Jake | CC0 |
| `extractor_fan.ogg` | ventilador que vaza e servidor da sala de controle | [Freesound #260817](https://freesound.org/people/iccleste/sounds/260817/) "extractor fan" | iccleste | CC0 |
| `church_bell_toll.ogg` | sino lá fora (Final 2), três badaladas | [Freesound #824588](https://freesound.org/people/TicAshfield/sounds/824588/) "St Peters Church, Kinver - Distant Tolling Bell" | TicAshfield | CC0 |
| `wing_flap.ogg` | pássaro e corvo levantando voo | [Freesound #414671](https://freesound.org/people/zouzmusic/sounds/414671/) "short pigeon wing flap" | zouzmusic | CC0 |
| `crow_caw.ogg` | corvo (no lugar do crow_1) | [Freesound #361470](https://freesound.org/people/Jofae/sounds/361470/) "Crow Caw" | Jofae | CC0 |
| `deer_snort.ogg` | bufo do cervo (é um bufo de cavalo) | [Freesound #397236](https://freesound.org/people/black_trillium/sounds/397236/) "Horse Snort" | black_trillium | CC0 |
| `deer_stomp.ogg` | pata do cervo batendo | [Freesound #682876](https://freesound.org/people/drewsimko/sounds/682876/) "Footstomp_Mulch" | drewsimko | CC0 |
| `boar_squeal.ogg` | guincho do javali | [Freesound #233176](https://freesound.org/people/JarredGibb/sounds/233176/) "Pig - Grunt and Squeal 3" | JarredGibb | CC0 |
| `wolf_growl_1.ogg` | rosnado do lobo | [Freesound #829986](https://freesound.org/people/randbsoundbites/sounds/829986/) "Low dog growl" | randbsoundbites | CC0 |
| `wolf_growl_2.ogg` | rosnado do lobo | [Freesound #342204](https://freesound.org/people/Christopherderp/sounds/342204/) "Beast Snarling" | Christopherderp | CC0 |
| `breath_in.ogg` | puxar o ar (goblin e Ari) | [Freesound #151919](https://freesound.org/people/carroll27/sounds/151919/) "Inhale" | carroll27 | CC0 |
| `stomach_growl_1.ogg` | ronco da barriga | [Freesound #618147](https://freesound.org/people/AddictPunk/sounds/618147/) "Tummy Rumble" | AddictPunk | CC0 |
| `stomach_growl_2.ogg` | ronco da barriga | [Freesound #447911](https://freesound.org/people/Breviceps/sounds/447911/) "Growling stomach / Stomach rumbles" | Breviceps | CC0 |
| `chew_2.ogg` | mastigar (uma mordida do trecho mais forte) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Chewing_gum_mouth_close.ogg) "Chewing gum mouth close" | ezwa | domínio público |
| `tree_fall.ogg` | árvore seca derrubada | [Freesound #869103](https://freesound.org/people/ozymandias37/sounds/869103/) "Tall dead tree splintering then falling to ground" | ozymandias37 | CC0 |
| `stone_throw.ogg` | jogar pedra | [Freesound #346373](https://freesound.org/people/denao270/sounds/346373/) "Throwing / Whip Effect" | denao270 | CC0 |
| `blind_rattle.ogg` | persiana do Abrigo (uma das quatro sacudidas) | [Freesound #450040](https://freesound.org/people/kyles/sounds/450040/) "venetian blinds pull down quick various metal rattle" | kyles | CC0 |
| `glitch.ogg` | memória do ciclo 346 e telas da sala de controle | [Freesound #434657](https://freesound.org/people/TheMinkman/sounds/434657/) "Glitch Computer" | TheMinkman | CC0 |
| `blast_door.ogg` | porta blindada do Abrigo (Final 2) | [Freesound #637583](https://freesound.org/people/kyles/sounds/637583/) "gate big rusty metal door garage open heavy creak rattle" | kyles | CC0 |
| `wolf_yelp.ogg` | ganido do lobo ferido | [Freesound #865970](https://freesound.org/people/renprowler/sounds/865970/) "little dog whine 4" | renprowler | CC0 |
| `gasp.ogg` | soltar o ar depois de prender o fôlego (goblin e Ari) | [Freesound #792641](https://freesound.org/people/Sadiquecat/sounds/792641/) "Catching breath (Genuine)" | Sadiquecat | CC0 |
| `sniff.ogg` | farejar (duas fungadas) | [Freesound #446826](https://freesound.org/people/mateozugi19/sounds/446826/) "sniffing" | mateozugi19 | CC0 |
| `chew_1.ogg` | mastigar (uma mordida) | [Freesound #382673](https://freesound.org/people/bbrocer/sounds/382673/) "Wet Sloppy Eating" | bbrocer | CC0 |
| `teeth_chatter.ogg` | dentes batendo de frio: montado com um estalo de dente repetido ~11 vezes por segundo, com volume e ritmo variando | [Freesound #691908](https://freesound.org/people/hollandm/sounds/691908/) "Teeth clack 1" | hollandm | CC0 |
