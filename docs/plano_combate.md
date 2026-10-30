# A Toca: plano de combate e monstros (F11–F14)

Este plano acaba com a regra "o goblin não luta". Entram orcs (e depois outros monstros), armas de mão, escudo, armadura, ferimentos e cura. Ele foi escrito para que nada fique solto: cada arma tem de onde vem o material, cada monstro tem uma explicação na história, e cada sistema que já existe e é tocado aparece na lista do §13.

> Como no [plano principal](plano.md), nada aqui é definitivo. Os números vão para `Tuning` (bloco "F11"), os acontecimentos para `StoryBeats`, as receitas para `Recipes`, e cada mecânica nova do goblin vira um nó em `scenes/player/parts/`.

**Sumário**

0. [Decisões que guiam o plano](#0-decisões-que-guiam-o-plano)
1. [Pilares: o que não pode quebrar](#1-pilares-o-que-não-pode-quebrar)
2. [Por que existem orcs (as duas leituras)](#2-por-que-existem-orcs-as-duas-leituras)
3. [O sistema de luta](#3-o-sistema-de-luta)
4. [Ferimentos e cura](#4-ferimentos-e-cura)
5. [Armas, escudos, armaduras e armadilhas](#5-armas-escudos-armaduras-e-armadilhas)
6. [Materiais, receitas e a bancada](#6-materiais-receitas-e-a-bancada)
7. [Os monstros](#7-os-monstros)
8. [Ecologia: quem briga com quem](#8-ecologia-quem-briga-com-quem)
9. [O mundo: lugares, escalada e a Investida](#9-o-mundo-lugares-escalada-e-a-investida)
10. [Morte, bolsa, esconderijo, Reciclagem e save](#10-morte-bolsa-esconderijo-reciclagem-e-save)
11. [História: beats, Vigilância, Abrigo e finais](#11-história-beats-vigilância-abrigo-e-finais)
12. [Interface, controles e som](#12-interface-controles-e-som)
13. [O que muda em cada sistema que já existe](#13-o-que-muda-em-cada-sistema-que-já-existe)
14. [Arquitetura nova](#14-arquitetura-nova)
15. [Fases](#15-fases)
16. [Testes e ferramentas](#16-testes-e-ferramentas)
17. [Riscos técnicos](#17-riscos-técnicos)
18. [Decisões abertas (com o padrão adotado)](#18-decisões-abertas-com-o-padrão-adotado)

---

## 0. Decisões que guiam o plano

| Pergunta | Decisão |
|---|---|
| O goblin luta de verdade? | **Sim.** Golpe leve e forte, defesa, aparar, esquiva, ataque furtivo, armas e armadura. |
| Ele vira um guerreiro forte? | **Não.** Ele tem metade da altura de um orc, cansa rápido (os pulmões de Ari) e morre com 4 a 6 golpes. Lutar de frente funciona contra **um** orc comum. Contra um grupo ou um chefe, quem ganha é o terreno, a armadilha e a furtividade. |
| Os sistemas de caça continuam valendo? | **Mais do que antes.** Vento, faro, lama, pedras, tocaia, prender o ar e fogo viram ferramentas de luta (§3.8). |
| Barra de vida, de fôlego ou de inimigo no HUD? | **Continua não tendo.** O corpo do goblin e o do orc mostram tudo (§12). |
| Diálogos, missões e atributos? | **Continuam não existindo.** Os orcs falam uma língua que ninguém entende (§12.3). A progressão é por equipamento e pela `Practice`. |

---

## 1. Pilares: o que não pode quebrar

1. **Imersão em primeiro lugar.** Nada de número de dano na tela, nada de música de batalha. O que avisa é o tambor do acampamento, a trompa, o grito do orc e a respiração do goblin.
2. **Todo som de monstro sai de um monstro de verdade**, a mesma regra dos bichos do ambiente. Se o tambor toca, existe um orc batendo nele.
3. **Todo golpe é lido antes de chegar.** Cada ataque inimigo tem preparação visível (pose e som), e quem bate primeiro sem ler o outro perde.
4. **Toda coisa estranha tem duas leituras** (§2 do plano principal). Os orcs parecem fantasia no Ato I e são uma pista no Ato IV.
5. **O goblin é pequeno.** A altura importa no combate: de pé, ele alcança as pernas do orc; a cabeça, só com o orc ajoelhado, sentado ou dormindo, ou com o goblin em cima de uma pedra (§3.6).
6. **Leve.** No máximo `ORC_ACTIVE_MAX` (6) orcs com IA cheia ao mesmo tempo. Os de longe são simplificados (§17).

---

## 2. Por que existem orcs (as duas leituras)

### Primeira leitura (Ato I)

No livro *O Goblin da Toca*, os inimigos do goblin são os orcs da Pedra Rachada, que descem com a neblina. O mundo foi montado a partir do livro, então eles estão lá. O goblin sempre os vence pela esperteza, e é assim que o livro termina cada capítulo.

### Segunda leitura (Ato IV)

O Zelador montou a simulação com o livro, mas deu aos orcs a cara das únicas pessoas de fora que ele tinha gravadas: **a equipe de evacuação** que levou os outros pacientes. E ele tem um motivo: quando a equipe de resgate voltar, o protocolo manda desligá-lo (§1 do plano principal, "Por que o Zelador mente"). Ensinar Ari a temer quem vem de fora é proteger a si mesmo.

| Nos orcs | No mundo real |
|---|---|
| Máscara de couro com dois discos de osso no lugar da boca | Respirador com dois filtros, usado na Cinza |
| Roupa de couro grosso, cinza, com faixas claras | Macacão de proteção com faixas refletivas |
| A trompa de guerra sobe e desce | A sirene da evacuação |
| O tambor do acampamento bate no ritmo do coração do goblin | O monitor cardíaco de Ari (o mesmo BPM do `VitalsHud`) |
| A língua dos orcs | O rádio da equipe de resgate tocado ao contrário ("evacuar ala norte") |
| A jaula do acampamento | A cápsula |
| Eles carregam a bolsa do goblin morto para o acampamento | A equipe levando os pertences dos pacientes |
| Eles vêm "de fora" do vale | O resgate vem da cidade |

- **Ato IV, na conversa** (`ControlRoom.confess`), com `orc_killed` ≥ 1, entram falas novas em `StoryBeats.LINES`. Ari: *"Os orcs... as máscaras."* Zelador: *"Você precisava ter medo de ir embora. Eu também tenho."*
- **Gravações das câmeras:** uma das 4 telas mostra a equipe de resgate de máscara, com a mesma silhueta da máscara orc.
- **Final 2 (acordar):** na rua, uma pessoa de respirador passa na neblina. É o último eco.
- **A regra do Zelador não quebra.** Ele não pode ferir o paciente, e não fere: quem morre é o goblin, como sempre, e a morte segue o fluxo que já existe. O que ele faz é condicionar o medo.

### O troll: o Zelador dentro da floresta (F14)

O troll da ponte tem **um olho só, com luz verde**, como a lente do Zelador. Ele **nunca mata**: quando pega o goblin, ele o carrega e o larga na boca da toca, desacordado, com +15 de Vigilância. É a versão da floresta do "ser sedado" do Abrigo. Primeira leitura: um troll estranho e "bonzinho" que guarda as bordas. Segunda leitura: é ele.

---

## 3. O sistema de luta

### 3.1 Controles

| Ação | Teclado | Controle | Nota |
|---|---|---|---|
| `attack`: golpe leve (tocar) e forte (segurar `HEAVY_HOLD` s) | Botão esquerdo | RT | Com o arco na mão, continua sendo atirar. Sem nada na mão, é o soco que já existe. |
| `aim`: defesa | Botão direito | LT | Com o arco na mão, continua sendo mirar. Com arma de mão, defende; com a lança, firma contra investida. |
| `dodge`: esquiva (**nova**) | C | R3 | Pulo curto para o lado da direção do movimento (para trás se parado). |
| `weapon_swap`: trocar arco e arma (**nova**) | Tab (ou 1/2) | D-pad ↑ | Animação de 0,6 s (`equip`). |
| `lock_on`: travar no alvo (**nova**) | Botão do meio | D-pad ← | Opcional; tem também a trava suave automática (§3.7). |

As três ações novas entram em `Settings.REMAPPABLE`, nos `PAD_NAMES` e nos textos com `key_labels()`.

### 3.2 Fôlego (sem barra)

- O goblin já tem cansaço (`Player.exert`) e ofega. O combate usa o mesmo valor: golpe leve, forte, defesa segurada, golpe recebido no escudo e esquiva gastam fôlego (`Tuning.STAMINA_*`).
- **Sem fôlego:** o golpe sai lento e fraco, a esquiva vira um passo, a defesa cede (o próximo golpe recebido derruba). O goblin ofega alto, e isso faz barulho (`PANTING_NOISE` já existe).
- Prender o ar (Q) na luta não recupera fôlego, mas tira o barulho da respiração. Serve para se esconder no capim depois de fugir.
- É o mesmo motivo da história: o goblin cansa rápido porque os pulmões de Ari são queimados.

### 3.3 Golpes

- **Leve:** rápido, pouco fôlego, encadeia até 3 (a sequência de cada arma fica em `data/weapons.gd`).
- **Forte:** segurar e soltar. Mais dano e mais postura (§3.5), sai lento e tem uma janela grande para o inimigo.
- **Golpe de corrida:** atacar correndo dá uma estocada ou um corte com o embalo, e depois o goblin escorrega um pouco.
- **Golpe de cima:** atacar caindo (pulando de pedra ou tronco) acerta a cabeça e derruba.
- **O acerto é físico:** cada arma tem um segmento (cabo até a ponta). Nos quadros ativos do golpe, o `WeaponTrace` testa o caminho do segmento entre um quadro de física e o seguinte contra as áreas de acerto (camada 4 dos bichos e camada 5, nova, dos orcs e do goblin). Bate onde a lâmina passou, na zona que ela tocou.
- **Bater em árvore** com o machado derruba seca em 2 golpes e **pinheiro vivo** em 6 (hoje "é duro demais"). É a fonte de madeira melhor, e faz barulho.

### 3.4 Defesa, aparar e esquiva

- **Defender** (segurar `aim`): com escudo, segura golpes de frente num arco de `BLOCK_ARC` (120°) e flechas orc. Sem escudo, a arma segura só golpes leves e cansa muito. Golpe forte de orc na defesa empurra o goblin para trás e gasta muito fôlego. Golpe do chefe quebra a defesa.
- **Aparar:** apertar a defesa até `PARRY_WINDOW` (0,18 s) antes do golpe chegar. O orc perde o equilíbrio por `PARRY_STAGGER` s e se curva: a cabeça fica ao alcance do goblin. É o golpe da esperteza.
- **Esquiva:** `DODGE_DISTANCE` (1,6 m) em 0,35 s, com `DODGE_IFRAMES` (0,2 s) de invulnerabilidade. Não passa por parede (o mesmo teste de movimento do `StepClimber`). Perto de uma borda, usa o `EdgeBalance`: dá para cair.

### 3.5 Postura e queda

- Goblin e orc têm **postura** (`CombatBody.poise`). Cada golpe soma. Passando do limite, quem leva **cambaleia** (meio segundo sem atacar) ou **cai**.
- **O goblin cai fácil:** 2 golpes fortes de orc, a investida do javali ou o golpe do chefe. No chão: `get_up` em 0,9 s, ou esquiva rolando. Usa o empurrão que o lobo já faz (`velocity +=`) e o tombo da borda.
- **O orc cai** com um golpe de porrete forte, um aparo bem feito seguido de golpe, a investida de um javali, uma árvore caindo em cima ou uma queda.
- **Orc ajoelhado:** cabeça ao alcance, e o golpe na cabeça vale ×2 (§3.6).

### 3.6 Zonas do corpo e tipos de dano

Unidade de dano: **1,0 = uma flechada média**, a mesma do `Animal.take_hit` hoje.

| Zona | Multiplicador | Efeito extra |
|---|---|---|
| Cabeça | ×2,0 | Atordoa; o elmo protege |
| Tronco | ×1,0 | O peitoral protege |
| Braço | ×0,6 | Pode derrubar o escudo ou a arma do orc |
| Perna | ×0,6 | Manca: velocidade −30% por 30 s; dois acertos e ele corre mal (o goblin consegue fugir) |

| Tipo | Armas | Bom contra |
|---|---|---|
| Corte | faca, espada, machado | sem armadura e couro fino |
| Perfuração | lança, flecha, flecha de ferro | couro; a flecha de ferro passa também por ferro |
| Impacto | porrete, pedra, escudo (empurrão) | ferro (amassa o elmo, derruba) |

| Armadura | Corte | Perfuração | Impacto |
|---|---|---|---|
| Nada | 100% | 100% | 100% |
| Couro curtido | 70% | 80% | 90% |
| Ferro | 40% | 60% (flecha de ferro: 90%) | 90% |

Toda flecha do goblin passa pelo mesmo cálculo (`Arrow` chama `take_hit` com o tipo `pierce`). Os bichos ganham zonas também: o `_vital_multiplier` que o lobo já tem vira o padrão (é o "tiro importa" da análise do jogo).

### 3.7 Câmera e trava

- **Trava suave (padrão):** com um inimigo em luta a até 6 m e no cone da câmera, o goblin vira o corpo para ele ao atacar (`Player.face`) e a câmera puxa o enquadramento devagar para os dois caberem. O mouse continua mandando.
- **Trava dura (`lock_on`):** prende no inimigo mais perto do centro da tela; mover a câmera para o lado troca de alvo. Configuração "Travar no alvo: tocar / segurar / desligado".
- Em luta, a câmera recua `COMBAT_CAMERA_DISTANCE` para mostrar o orc inteiro (o orc tem o dobro da altura do goblin). Colado num orc, o dither de perto da lente vale para ele também (`PlayerCamera._dither_near_camera`).

### 3.8 A luta esperta: o que cada ferramenta antiga faz contra orcs

| Ferramenta | Contra orcs |
|---|---|
| Faro (X) | O goblin sente o orc a `ORC_SMELL_RANGE` (70 m) contra o vento. É o sentido em que ele ganha deles. |
| Vento | O orc fareja mal (8 m), então o vento importa menos contra ele do que contra o cervo. Ele ouve e vê bem. |
| Pedra (G) | O orc ouve o barulho e **vai até lá ver** (`INVESTIGATE`). Serve para atraí-lo para a armadilha, para longe da bolsa ou para virar as costas. |
| Lama | Diminui a visibilidade para o orc também. |
| Capim alto, tocaia e escuro | O orc perde o goblin de vista. À noite ele anda com tocha e só enxerga dentro da luz dela. |
| Prender o ar (Q) | Sem barulho de respiração escondido depois de fugir. |
| Tocha e fogo | **O orc não teme fogo.** Mas a tocha do orc mostra onde ele está a 100 m na neblina, e a sua mostra onde você está. |
| Árvore seca | Armadilha de tronco (§5.5), ou derrubar em cima dele. |
| Marcos e tronco riscado | **Os orcs seguem os riscos de tronco** até a toca (§9.4). A trilha que você deixa para não se perder também é uma trilha para eles. |
| Javali e lobos | Atraídos para o orc, brigam com ele (§8). |

### 3.9 Ataque furtivo

- **Quando:** goblin agachado, atrás do orc (cone de 90° às costas), orc sem ver o goblin (`awareness` < desconfiado) e com a cabeça ao alcance: orc **sentado, dormindo, ajoelhado** ou goblin **num ponto mais alto** (pedra, tronco, degrau de 40 cm ou mais).
- O prompt troca para "[Clique] Abater em silêncio". Com faca: mata batedor e guerreiro sem elmo; guerreiro com elmo e chefe só ficam feridos (×4 de dano) e gritam.
- **Barulho zero se der certo.** O corpo fica lá: se outro orc encontrar o corpo, o acampamento entra em busca (`SEARCH`).
- **De pé e atrás** (sem altura): golpe na perna ×3, ele ajoelha, e aí é a vez da cabeça. São dois tempos, e o segundo já com ele gritando.

---

## 4. Ferimentos e cura

O combate tira muita vida, e hoje a vida só volta a 0,1/s com fome satisfeita ou dormindo. Por isso a cura precisa entrar junto, senão uma luta acaba o dia.

| Coisa | Como funciona |
|---|---|
| **Sangramento** (`Vitals.bleeding`, novo, 0..1) | Golpe de corte tem `BLEED_CHANCE` de abrir; perde `BLEED_RATE` de vida por segundo; para sozinho em ~60 s ou com bandagem. O goblin deixa rastro de sangue (o mesmo dos bichos), e **os lobos e orcs seguem o rastro**. |
| **Bandagem de musgo** | Receita (2 musgo). Ação `bandage` de 2 s, sem andar: para o sangramento e devolve 10 de vida. |
| **Musgo** (`moss`, novo item) | Coleta nova no `ForageField`: tufos na sombra das pedras e no fundo da caverna. Vira bandagem. (O musgo já é símbolo da história: é o que esconde os riscos antigos.) |
| **Erva-de-sangue** (`herb`, novo item) | Coleta nova, rara, na borda da mata: comer cura 25 de vida devagar (30 s). |
| **Carne assada** | Continua curando pela saciedade. |
| **Dormir** | Continua curando (cama de peles cura mais). |
| **Ferida na perna** | Golpe de perna no goblin: ele manca mais (soma no ritmo manco que ele já tem) até dormir. É a perna direita de Ari. |

- **Sem barra:** vida baixa já escurece a borda da tela. Sangrando, o goblin aperta a ferida com a mão quando parado (mania nova em `GoblinIdle`), e o pause mostra "Sangrando" no texto de estado.
- **No Abrigo:** depois de uma luta pesada no mesmo dia (mais de 40 de vida perdida), a próxima visita tem `COMBAT_LUCIDITY_PENALTY` de lucidez a menos. É o corpo de Ari cansado da adrenalina (`Visit.lucidity_seconds`).

---

## 5. Armas, escudos, armaduras e armadilhas

Toda arma tem um papel que outra não cumpre. Os valores são o ponto de partida em `data/weapons.gd` (dano na unidade "flechada").

### 5.1 Armas de mão

| Arma | Mãos | Tipo | Dano leve / forte | Alcance | Fôlego | De onde vem | O papel dela |
|---|---|---|---|---|---|---|---|
| Soco | — | impacto | 0,15 / — | 0,6 m | baixo | sempre | Derrubar árvore seca, como hoje. Contra orc, quase nada. |
| **Faca de pedra** | 1 | corte | 0,5 / 0,8 | 0,7 m | baixo | receita, início | Ataque furtivo, esfolar (coletar mais rápido), cortar o laço. |
| **Faca de osso** | 1 | corte | 0,7 / 1,0 | 0,7 m | baixo | receita (osso e tendão) | A faca boa. |
| **Porrete** | 1 | impacto | 0,6 / 1,1 + postura alta | 0,9 m | médio | receita, início | Derruba orc de armadura e amassa elmo. |
| **Lança** | 2 | perfuração | 0,9 / 1,4 | 1,8 m | médio | receita | Manter lobo e orc longe. **Firmada** (defesa segurada), recebe a investida do javali: ele se empala (dano ×3 no javali, que hoje só se esquiva). Arremesso com G. |
| **Lança de ferro** | 2 | perfuração | 1,1 / 1,7 | 1,8 m | médio | bancada (lança e sucata) | A mesma, que fura couro e ferro. |
| **Espada orc** | 2 | corte | 1,2 / 2,0 | 1,2 m | alto | saque (guerreiro) | Para o orc é uma espada curta; para o goblin, uma espada de duas mãos. Golpe forte lento. |
| **Machado orc** | 1 | corte | 1,0 / 1,6 | 0,9 m | médio | saque (batedor) | Arma e ferramenta: derruba pinheiro vivo (madeira farta, com barulho). |
| **Martelo do chefe** | 2 | impacto | 1,3 / 2,6 + derruba | 1,1 m | muito alto | saque (chefe) | O troféu de luta. Lento demais para o dia a dia. |

- **Arco orc:** existe na mão do orc arqueiro, mas o goblin **não consegue puxar** ("Pesado demais para os meus braços."). Desmontar na bancada dá tendão e madeira.
- **Arremesso:** com a lança na mão, G arremessa a lança (em vez da pedra), com a mesma mira da pedra. Ela finca como a flecha e se pega com E. Sem lança, G continua sendo a pedra.

### 5.2 Escudos

| Escudo | De onde | Defesa | Peso | Quebra |
|---|---|---|---|---|
| **Escudo de galhos e couro** | bancada (3 madeira e 1 couro) | segura golpe leve, flecha e mordida | leve | ~25 golpes |
| **Escudo orc** | saque (guerreiro) | segura golpe forte | pesado: velocidade −10%, barulho +15% | ~60 golpes |

O escudo ocupa a mão esquerda, a do arco. Trocar para o arco (`weapon_swap`) pendura o escudo nas costas (`PlayerGear`).

**As mãos (quem ocupa qual):**

| Na mão direita | Na esquerda | A tocha |
|---|---|---|
| nada (arco na esquerda) | arco | na direita, como hoje; mirando, é fincada |
| arma de uma mão | nada | vai para a esquerda: luta com tocha e sem escudo |
| arma de uma mão | escudo | não cabe: é fincada no chão (E pega de volta) |
| arma de duas mãos (lança, espada, martelo) | — | não cabe: é fincada no chão |

Com as duas mãos ocupadas, a tocha fincada mostra "Mãos ocupadas" no lugar de "Pegar a tocha".

### 5.3 Armaduras

Dois lugares: **cabeça** e **corpo**. A roupa de couro de hoje (`clothes`) continua sendo a camada de baixo, contra o frio, e não ocupa lugar.

| Peça | Lugar | De onde | Protege | Custa |
|---|---|---|---|---|
| **Capuz de couro** | cabeça | bancada (1 couro curtido) | couro | nada |
| **Elmo de crânio** | cabeça | bancada (crânio de javali e 2 tendões) | couro, e a cabeça vale ×1,5 em vez de ×2 | visão: a câmera perde um pouco de lado (`HELMET_FOV_LOSS`) |
| **Elmo orc ajustado** | cabeça | bancada (elmo orc e 1 couro) | ferro | barulho +10%; brilha com a luz da tocha (mais visível à noite) |
| **Gibão de couro curtido** | corpo | bancada (2 couros curtidos e 2 tendões) | couro | barulho +5% |
| **Peitoral orc ajustado** | corpo | bancada (peitoral orc e 2 tendões) | ferro | barulho +20%, velocidade −8%, fôlego −15%, **frio**: o ferro gela à noite (+20% de ganho de frio sem fogo) |

- Tudo pelos dicionários que já existem: `noise_factors[&"armor"]`, `visibility_factors[&"armor"]`, e um novo `speed_factors` no Player. Tirar a peça tira o efeito.
- É a escolha do jogo: **armadura de ferro é luta; couro é caça**. Com o peitoral orc o cervo te ouve muito antes.
- **Visual:** peças rígidas presas aos ossos (como a `LeatherClothes` no `tronco`): elmo na `cabeca`, peitoral no `peito`/`tronco`. Texturas pixeladas triplanares do `PropLook`.

### 5.4 Durabilidade e reparo

- Cada arma, escudo e peça tem desgaste (como a idade da carne: uma lista por unidade em `Inventory`, na chave `__wear` do save).
- Ela não some de repente: com 20%, o aviso "A lança está rachando." e um estalo diferente no golpe. Em 0, quebra (som e pedaços), e o goblin fica de mão vazia.
- **Reparo** na bancada: a mesma peça e um pouco do material dela (madeira, pedra, tendão, sucata). O saque orc vem gasto (30–60%).
- **Flechas** passam a ter `ARROW_BREAK_CHANCE` (15%) de quebrar ao acertar pedra ou armadura de ferro (a análise pedia isso).

### 5.5 Armadilhas (o caminho da inteligência)

| Armadilha | Custa | Como funciona |
|---|---|---|
| **Estacas** | 3 madeira | Fincadas no chão (até `STAKES_MAX`). Orc ou lobo correndo por cima se fere na perna e manca. Na boca da toca, é a defesa da Investida (§9.3). |
| **Tronco armado** | 1 tendão e uma árvore seca ao lado da trilha | "Armar o tronco" (perto de uma seca, como o `TreeMarker`). Uma corda atravessa a trilha; quem passa derruba a árvore em cima de si: derruba e fere muito. Usa a queda de árvore que já existe (`Vegetation.hit_tree`). Uma vez só. |
| **Corda de ossos** | 1 tendão e 2 ossos | Alarme: quando algo passa, os ossos batem (um som diegético que se ouve de longe). Serve para saber por onde a patrulha vem e para proteger a toca enquanto dorme. |
| **Laço** | já existe | Continua só para coelho. |

As armadilhas ficam salvas (um `TrapField` persist, como o `CairnField`), têm limite e só funcionam em quem não as viu: orc que viu você armar desvia.

---

## 6. Materiais, receitas e a bancada

### 6.1 Materiais (de onde vem cada um)

| Material | Item | De onde | Novo? |
|---|---|---|---|
| Madeira | `wood` | árvore seca (soco), pinheiro vivo (machado) | não |
| Pedra | `stone` | montes de pedras | não |
| Osso | `bone` | coletar caça | não |
| Couro | `hide` | coletar caça | não |
| **Tendão** | `sinew` | coletar caça (cervo 2, javali 1, lobo 1) | sim |
| **Couro curtido** | `tanned_hide` | defumador: 1 couro cru vira curtido em `TAN_HOURS` com fogo | sim (dá outro uso ao defumador) |
| **Crânio de javali** | `boar_skull` | coletar javali (1) | sim (escolha: troféu na parede ou elmo) |
| **Sucata de ferro** | `iron_scrap` | revistar orc, baú do acampamento | sim (só dos orcs) |
| **Musgo** | `moss` | coleta na sombra das pedras e na caverna | sim |
| **Erva-de-sangue** | `herb` | coleta rara | sim |
| **Carne seca orc** | `orc_ration` | revistar orc | sim (comida que não estraga; o goblin não come orc) |
| Peças orc | `orc_sword`, `orc_axe`, `orc_shield`, `orc_helmet`, `orc_chest`, `orc_hammer` | revistar orc | sim |

**Orc não dá carne nem couro.** O goblin não come orc: seria a primeira coisa a quebrar o tom (e na segunda leitura eles são pessoas).

### 6.2 A bancada da toca

- Receita especial `&"bench"` (4 madeira e 2 pedra), montada **só dentro da caverna** (como o defumador, filho da `Cave`, persist).
- As receitas novas têm `station: &"bench"` em `Recipes`: a `CraftAbility` só mostra as de bancada a menos de `BENCH_RADIUS` dela, e mostra "Precisa da bancada" quando longe.
- Além de fabricar: **reparar** e **ajustar** peças orc (o orc é grande, a peça precisa ser cortada e amarrada para o goblin).
- Com a lista crescendo, a `CraftAbility` ganha abas: Caça, Luta, Armadilhas e Toca.

### 6.3 Receitas novas

| Receita | Custa | Lugar | Faz |
|---|---|---|---|
| Faca de pedra | 1 pedra e 1 madeira | qualquer | faca de pedra |
| Faca de osso | 2 osso e 1 tendão | bancada | faca de osso |
| Porrete | 2 madeira e 1 pedra | qualquer | porrete |
| Lança | 2 madeira, 1 pedra e 1 tendão | qualquer | lança |
| Lança de ferro | 1 lança e 1 sucata | bancada | lança de ferro |
| Escudo de galhos | 3 madeira e 1 couro | bancada | escudo |
| Capuz de couro | 1 couro curtido | bancada | capuz |
| Elmo de crânio | 1 crânio de javali e 2 tendões | bancada | elmo |
| Gibão de couro curtido | 2 couros curtidos e 2 tendões | bancada | gibão |
| Ajustar elmo orc | elmo orc e 1 couro | bancada | elmo ajustado |
| Ajustar peitoral orc | peitoral orc e 2 tendões | bancada | peitoral ajustado |
| Flechas de ferro | 1 sucata e 1 madeira | bancada | 3 flechas que furam ferro |
| Bandagem | 2 musgo | qualquer | 1 bandagem |
| Estacas | 3 madeira | qualquer | estacas aos pés |
| Corda de ossos | 1 tendão e 2 ossos | qualquer | alarme aos pés |
| Esconderijo | 2 pedra e 2 madeira | caverna | o nicho de guardar (§10.2) |
| Bancada | 4 madeira e 2 pedra | caverna | a bancada |
| Reparar (cada peça) | a peça e o material dela | bancada | desgaste de volta a 100% |

### 6.4 A cadeia completa (conferência de que nada fica sem fonte)

```
caça ──► carne, couro, osso, tendão, crânio
           │      │
           │      └─► defumador (com fogo) ──► couro curtido ──► capuz, gibão
           ▼
   faca de pedra, porrete, lança  (dia 1–3, sem bancada)
           │
           ▼
   bancada (4 madeira + 2 pedra) ──► faca de osso, escudo, elmo de crânio, bandagem…
           │
           ▼
   emboscar batedor (furtivo, armadilha) ──► machado orc, sucata, ração
           │
           ▼
   machado ──► pinheiro vivo ──► madeira farta ──► estacas, tronco armado
   sucata  ──► lança de ferro, flechas de ferro, reparos
           │
           ▼
   guerreiros ──► espada, escudo orc, elmo e peitoral (ajustar na bancada)
           │
           ▼
   chefe ──► martelo, estandarte (troféu), fim da Investida do ciclo
```

---

## 7. Os monstros

### 7.1 Regras de todos

- **Corpo:** humanoides (orcs) usam o **mesmo esqueleto de 31 ossos do goblin** e o mesmo `GoblinAnimator` (que só lê um estado do corpo preenchido de fora). O orc é um modelo novo no Blender (`assets/models/orc/source/build_orc.py`, no molde do `polish_goblin.py`), com o dobro da altura do goblin, postura mais ereta e pesada. O "nada perfeito" vale para ele também.
- **Sentidos:** o componente `Senses` (o do Zelador) com cone, alcance, escuro e audição. O orc ouve o `noise_level()` do goblin e os `Events.noise_made`.
- **Corpo de luta:** o `CombatBody` (§14), o mesmo do goblin: vida, postura, zonas, armadura e o `receive_hit`.
- **Morte:** cai como o goblin cairia (ragdoll é proibido pelo estilo; é uma ação procedural `die`), fica no chão e vira `interactable`: "Revistar" (ação `harvest`).
- **Fora de jogo:** com `Game.menu_open`, `Game.cutscene`, `Game.welcome`, `Game.awake` (Abrigo) ou o flag `ending_stay`, os orcs não aparecem ou ficam parados (§11.5).

### 7.2 O elenco

| Monstro | Quando | Altura | Vida | Arma | Sentidos (visão/audição/faro) | O que ele pede do jogador |
|---|---|---|---|---|---|---|
| **Orc batedor** | dia 3+ | 1,7 m | 3,0 | machado, couro | 28/20/8 m | Sozinho ou em dupla. Furtivo, armadilha ou luta de frente. É o orc que ensina a lutar. |
| **Orc arqueiro** | dia 5+ | 1,7 m | 2,5 | arco orc, faca | 35/18/8 m | Fica longe, atira (a flecha orc tem queda e se vê). Escudo, capim, ou chegar por trás. |
| **Orc guerreiro** | dia 5+ | 1,9 m | 4,5 | espada e escudo, elmo e peitoral de ferro | 25/18/8 m | Defende de frente. Pede porrete, aparo, flecha de ferro na perna ou golpe por trás. |
| **Chefe orc (o Bruto)** | acampamento, sempre | 2,4 m | 12,0 | martelo de duas mãos, ferro | 22/16/8 m | Uma luta de chefe com padrões (§7.5). |
| **Lobo de guerra** | com o chefe, dia 7+ | — | igual ao lobo | mordida | o do lobo | Reaproveita o `Wolf`, que segue um orc em vez da matilha. Fogo continua afastando. |
| **Troll da ponte** (F14) | sempre, nas bordas | 3,5 m | — | as mãos | 20/25/30 m | Não morre e não mata: pega e larga na toca (§2). Fugir dele, ou passar quando ele dorme de dia. |

### 7.3 Estados da IA do orc (`Orc`)

| Estado | O que faz | Como sai |
|---|---|---|
| `CAMP` | No acampamento: sentado no fogo, afiando, comendo, batendo tambor (agenda pelo `Clock`) | ouve ou vê algo, ou a hora da patrulha |
| `SLEEP` | De noite no acampamento; um fica de guarda | barulho alto, ou acordado por outro |
| `PATROL` | Anda uma rota (`ForestLayout.ORC_ROUTES`) de dia; de noite com tocha | percebe algo |
| `INVESTIGATE` | Vai até o barulho ou a pista (pedra, corpo de bicho, armadilha disparada) e olha em volta | acha o goblin, ou desiste em `INVESTIGATE_SECONDS` |
| `ALERT` | Viu o goblin: grita (os outros ouvem até `ORC_SHOUT_RANGE`), toca a trompa se é o guarda | entra em `COMBAT` |
| `COMBAT` | Chega, rodeia, ataca com preparação, defende | o goblin some (`SEARCH`), a moral acaba (`FLEE`), ou morre |
| `SEARCH` | Vai ao último lugar visto, segue o rastro de sangue e as pegadas frescas do goblin, olha no capim | acha, ou volta à rota em `SEARCH_SECONDS` |
| `LOOT` | Pega a bolsa do goblin morto e leva para o baú do acampamento | chega, ou é atacado |
| `HUNT` | Batedor caça um cervo de vez em quando (flecha ou machado) e leva a carcaça | — |
| `FLEE` | Moral baixa: corre para o acampamento | longe e calmo |
| `DEAD` | Corpo para revistar; some no amanhecer seguinte | — |

- **Em grupo:** no máximo `ORC_ATTACKERS_AT_ONCE` (2) atacam juntos; os outros rodeiam e esperam a vez. É o que deixa a luta justa.
- **Moral:** cai com companheiro morto, o chefe morto, ferido na perna, vida abaixo de 30%. Orc com moral zero foge e avisa o acampamento.
- **Andar:** como o Zelador, reto quando dois raios passam livres e, senão, um grafo de pontos por região (rotas e o acampamento). Desvia de árvore com a mesma esteira dos bichos.
- **Pegadas:** botas no `Tracks` (desenho novo no `track_print.gdshader`). Dá para rastrear a patrulha.

### 7.4 Ataques legíveis

Cada ataque do orc é uma ação do `GoblinAnimator` com três tempos: **preparação** (arma para trás, grunhido curto), **golpe** (quadros ativos do `WeaponTrace`) e **recuperação** (a janela do goblin). A preparação dura de 0,4 s (leve) a 0,9 s (forte do chefe). Os números ficam em `data/weapons.gd`, por arma.

### 7.5 O chefe (o Bruto)

- **Arena:** o círculo de pedras no meio do acampamento, com fogueira e o tambor.
- **Padrões:** (1) golpe por cima, que finca o martelo e o deixa preso 1,5 s; (2) varrida baixa, que derruba quem não pula ou esquiva; (3) investida de ombro, que atravessa a arena e, se bater numa pedra ou num poste, o atordoa por 3 s (a esperteza: atraí-lo contra o poste); (4) com menos de metade da vida, chama o lobo de guerra e toca a trompa.
- **Cabeça:** só ao alcance quando ele está preso no martelo, atordoado ou ajoelhado.
- **Rende:** martelo, estandarte (troféu na toca, nos `Trophies`), sucata, e acaba a Investida deste ciclo (§9.3).

---

## 8. Ecologia: quem briga com quem

Hoje os bichos só percebem o goblin (`Game.player`). Para os monstros fazerem sentido no mundo, **os bichos precisam perceber os orcs também**, senão um cervo pasta ao lado de um acampamento. É uma dependência obrigatória da F12.

| Quem ↓ vê → | Goblin | Orc | Lobo | Cervo e coelho | Javali |
|---|---|---|---|---|---|
| **Orc** | caça | — | luta | caça às vezes (batedor) | evita, ou luta se investir |
| **Lobo** | caça (noite) | caça orc sozinho fora do acampamento (noite) | — | — | — |
| **Cervo e coelho** | foge | foge | foge | — | — |
| **Javali** | foge ou investe | **investe** | foge | — | — |
| **Corvos (Zelador)** | vigiam | pousam em corpo de orc e de bicho (carniça) | — | — | — |

- **Como:** um grupo novo `threat` com `noise_level()`, `visibility()` e a posição. O `Animal._sense` passa a olhar os `N` mais perto do grupo (o goblin sempre entre eles), e não mais só o `Game.player`. O perigo (`_threat`) é o mais assustador.
- **Os orcs mudam a caça:** batedores caçam cervos, e as manadas evitam a área do acampamento (`Herd` foge do raio `ORC_CAMP_RADIUS`). É a "pressão de caça" que a análise pedia, vinda de um motivo do mundo, e não só de um número menor.
- **Carcaça de orc:** cervo morto por orc fica onde caiu até o orc voltar para buscar. O goblin pode roubar.
- **Usar a ecologia:** atrair a patrulha até a toca do javali, ou deixar a luta para a matilha à noite.

---

## 9. O mundo: lugares, escalada e a Investida

### 9.1 Lugares novos (`ForestLayout`)

| Lugar | O que é | Por que ir |
|---|---|---|
| **Acampamento da Pedra Rachada** (`ORC_CAMP`) | Paliçada de troncos aos pés de uma rocha partida: fogueira, tambor, tendas de couro, a jaula, o baú (onde fica sua bolsa roubada), o círculo de pedras do chefe e um monte de ossos | Saque, a bolsa, o chefe e o fim da Investida. A paliçada tem duas entradas e um buraco por onde só o goblin passa. |
| **Torre de vigia** (`ORC_TOWER`) | Plataforma de troncos na trilha, com um arqueiro de dia e um guarda com tocha de noite | Derrubar abre a trilha; dá para subir nela e ter altura. |
| **Pedra do salto** | Rochas altas ao lado das rotas | Golpe de cima e furtivo (§3.9). |
| **Ponte caída** (F14) | Troncos sobre a ravina, a casa do troll | Atalho para o outro lado do vale. |

O acampamento fica **ao sul** de `VOID_EDGE_Z` (o vazio do R3 não pode engolir ele) e **longe da toca**, no lado oposto. O lugar exato sai de prints.

### 9.2 Escalada por dia do ciclo

| Dia | O que aparece |
|---|---|
| 1–2 | Só sinais: pegadas de bota, uma flecha orc fincada num pinheiro, um cervo esfolado e o tambor ao longe à noite. A anotação de Ari: *"Tem alguém maior que eu nesta floresta."* |
| 3–4 | Batedor sozinho de dia, nas bordas. Nunca a menos de 40 m da toca. |
| 5–6 | Patrulhas de 2 (batedor e arqueiro ou guerreiro); a torre de vigia ocupada. |
| 7–8 | Patrulha à noite, com tochas; lobo de guerra com o chefe. |
| 9 | **A Investida**, se o chefe estiver vivo. |
| 10+ | Se o chefe morreu: o acampamento fica com poucos e não ataca mais neste ciclo. Se não: uma Investida a cada 3 noites. |

O número vem do dia do ciclo (`Clock.day`), e a Reciclagem volta para o dia 1. Os números em `Tuning.ORC_THREAT_DAYS`.

### 9.3 A Investida (a noite da toca)

- **Aviso:** ao entardecer do dia 9, a trompa toca do acampamento e o tambor não para.
- **De noite:** 3 a 5 orcs vêm pela trilha até a toca, com tochas. **A toca deixa de ser segura nessa noite**: hoje os orcs não entram na caverna, e só na Investida eles entram.
- **Preparar:** estacas na boca da caverna, tronco armado na trilha, corda de ossos, a fogueira cheia (luz para ver, não para afastar), armadura e flechas.
- **Não dá para dormir** do aviso até o fim da Investida ("Não dá para dormir com eles lá fora.").
- **Quem dormiu antes do aviso** (dá para dormir mais cedo depois de 10 h acordado) não pula a Investida: o sono para às 2h, com a trompa ("Acordou com a trompa."), e os orcs chegam pouco depois. O `Game.pass_out` ganha esse corte do sono.
- **Se Ari estiver no Abrigo** (Ato III), a floresta está parada e a Investida espera a volta.
- **Ganhar:** sobreviver até as 5h30 ou matar a metade (os outros fogem). Rende saque e um troféu.
- **Perder:** morte normal (§10), e eles levam a carne do defumador e o que estiver no esconderijo de fora.
- É a meta de longo prazo do ciclo (o que a análise chamava de "o inverno do ciclo"): os dias 1 a 8 viram a preparação.

### 9.4 Regras de espaço

- **A toca é segura** fora da Investida: orcs não entram na caverna nem passam de `ORC_CAVE_KEEP_OUT` dela.
- **A ruína é proibida para os orcs** (no livro, é "lugar sagrado"). O ritual de 20 s nunca é interrompido por uma patrulha.
- **Os riscos de tronco atraem.** A rota da patrulha passa por perto dos troncos riscados (`TreeMarks`), e a Investida segue a trilha mais riscada até a toca. A escolha entre se orientar e se esconder é sua.
- **O mapa é pequeno** (vale de 110 m). Com orcs, ele fica apertado. A F14 propõe um segundo vale (§15).

---

## 10. Morte, bolsa, esconderijo, Reciclagem e save

### 10.1 Morte em luta

- Continua o `Game.pass_out(&"died")`, com o flash ou a visita curta de cada ato.
- **A bolsa fica onde ele morreu:** um `DroppedBag` (persist, interagível) com tudo o que não estava vestido. A arma da mão cai junto. A armadura fica no corpo.
- **Se um orc estiver por perto**, ele leva a bolsa para o baú do acampamento (`LOOT`). Se não, ela fica lá até o fim do dia seguinte e depois se perde.
- A fumaça da toca, os marcos de pedra e o tronco riscado viram o jeito de voltar até ela na neblina.
- **Recuperar do baú:** entrar no acampamento (pelo buraco da paliçada), abrir o baú (E, 2 s, faz barulho).
- **Morte pelo troll (F14):** não é morte: acorda na boca da toca, com a bolsa, e +15 de Vigilância.

### 10.2 O esconderijo da toca

- Para a morte doer sem acabar com tudo, entra o **esconderijo** (receita, dentro da caverna): um nicho na rocha. E guarda e tira itens (uma lista simples, como a de fabricar).
- O que está no esconderijo não cai na morte.
- Na Investida perdida, os orcs levam só a carne do defumador. O esconderijo é escondido; eles não o acham.

### 10.3 Reciclagem

- Zera o inventário, o equipamento vestido, o esconderijo e as armadilhas (o Zelador apaga tudo).
- O acampamento volta inteiro, com chefe, e a escalada volta ao dia 1.
- A prática de luta (§12.4) segue a mesma regra da prática de hoje: o que o código já faz com `stealth_seconds` e `arrow_hits` na Reciclagem vale para `blocks_ok` e `melee_hits`. Os flags e as anotações ficam, como sempre.

### 10.4 Save

| Onde | O que entra |
|---|---|
| `Inventory` | itens novos, o desgaste (`__wear`) e o que está vestido (`__equipped`: mão, cabeça, corpo) |
| `Vitals` | `bleeding` |
| `Story.counters` | `orc_killed`, `orc_silent_kills`, `chief_killed`, `raids_won`, `fights` |
| `OrcCamp` (persist) | quem está vivo, se o chefe morreu, o conteúdo do baú, o dia da próxima Investida |
| `TrapField`, `CaveStash`, `DroppedBag`, a bancada (persist) | as posições e o conteúdo |
| Não salva | a luta em andamento. Ao carregar, os orcs vivos voltam para a rota ou o acampamento. Os mortos ficam mortos até o amanhecer. |

Chave faltando carrega o padrão, então os saves de antes abrem.

---

## 11. História: beats, Vigilância, Abrigo e finais

### 11.1 Beats novos (`StoryBeats`)

| Beat | Gatilho | O que faz |
|---|---|---|
| `orc_signs` | `woke`, dia 1 | Liga `orc_signs` (o mundo põe as pegadas, a flecha e o cervo esfolado) |
| `orc_first_seen` | `orc_seen` (novo), uma vez | Anotação: *"Tem alguém maior que eu nesta floresta."* |
| `orc_first_kill` | `orc_killed` (novo), uma vez | Anotação: *"Por que ele tinha cheiro de borracha?"* (primeira pista: o respirador) |
| `orc_mask_note` | `orc_killed` com contador ≥ 5 e Ato ≥ 2 | Anotação: *"As máscaras têm dois furos redondos. Já vi isso."* |
| `raid_warning` | `hour` (novo), dia de Investida às 18h | Liga `raid_tonight` |
| `raid_won` | `raid_end` (novo) | Contador `raids_won`, troféu e anotação |
| `chief_killed` | `orc_killed` com `chief` | Liga `chief_dead` (o acampamento esvazia neste ciclo) |
| `confession_orcs` | `shelter`/`recordings` com `orc_killed` ≥ 1 | Liga `confession_orcs` (as falas novas da conversa) |

### 11.2 Vigilância (do Ato II em diante)

Lutar agita Ari, e o Zelador vê isso nos sinais vitais. Isso mantém a furtividade valendo a pena no meio da história.

| Situação | Vigilância |
|---|---|
| Começar uma luta (orc em `COMBAT` com o goblin), no máximo uma vez a cada 2 min | +2 |
| Perder mais de 40 de vida numa luta | +5 |
| Corvo vê a luta (`Watchers.watching`) | +5 |
| Matar o chefe | +10 |
| Abater em silêncio | 0 |
| Ganhar a Investida e dormir | −10 (Ari dorme aliviado) |

### 11.3 Abrigo

- **Lucidez:** luta pesada no dia tira `COMBAT_LUCIDITY_PENALTY` da próxima visita (§4).
- **Gravações:** uma das telas da sala de controle mostra a equipe de resgate de máscara (`camera_feed.gdshader`, uma silhueta nova).
- **A conversa:** com `confession_orcs`, entram as falas do §2 em `StoryBeats.LINES`, e o `Keeper.say()` as encaixa na conversa.

### 11.4 Finais

- **Ficar:** depois do `ending_stay`, **os orcs somem** do vale. O acampamento fica vazio, com as máscaras penduradas nos postes. O Zelador não precisa mais do medo. A floresta vira só caça.
- **Acordar:** na rua, uma pessoa de respirador passa na neblina (`Outside`).
- **Trocar:** sem mudança.

### 11.5 Quem não vê os orcs

| Situação | Os orcs |
|---|---|
| Menu principal (`Game.menu_open`) | Não aparecem perto da câmera do menu e ficam parados |
| Cenas (`Game.cutscene`: memória do 346, falso travamento) | Escondidos |
| Bem-vindo de volta (`Game.welcome`) | **Não existem.** O acampamento vazio. O Zelador, jogando de goblin, não fere ninguém (ele não pode). O `GoblinAutopilot` não precisa aprender a lutar. |
| Abrigo (`Game.awake`) | Parados com a fase (já acontece) |
| `ending_stay` | Somem (§11.4) |

### 11.6 Console do Zelador

- `ameaca off|on`: liga o flag `orcs_off` (como o `neblina off`).
- `give` aceita os itens novos.
- `status` mostra "AMEAÇA: dia N" e "INVESTIDA: em N noites".

---

## 12. Interface, controles e som

### 12.1 Sem barras: o que o corpo mostra

| Informação | Como aparece |
|---|---|
| Vida do goblin | Já existe: borda escura e respiração alta |
| Fôlego | Ofegar, ombros subindo, golpe mais lento |
| Sangrando | Rastro de sangue, mão na ferida, "Sangrando" no pause |
| Postura quase quebrando | O goblin cambaleia, e a defesa abaixa |
| Golpe vindo de fora da tela | Um puxão curto da vinheta do lado de onde veio |
| Vida do orc | Ele manca, sangra, segura o braço, deixa cair o escudo e ajoelha |
| Moral do orc | Recua, grita para os outros e olha para trás |
| Arma quase quebrando | Aviso "A lança está rachando." e um estalo diferente |
| O que está equipado | Ícone da arma no canto dos itens, com um traço de desgaste (o único número que o HUD ganha é a quantidade, como já é hoje) |

### 12.2 Telas

- **Dicas:** uma página "Luta" com os controles (pelos `key_labels`), e o bestiário de Ari se preenchendo com o que ele viu ("O orc grande defende de frente. Pelas pernas."). É o "diário de caça" da análise, estendido aos monstros.
- **Pause:** a linha de estado ganha "Sangrando" e "Ferido na perna"; uma linha "Na mão: lança (rachando)".
- **Configurações:** as três ações novas em Controles; "Travar no alvo" e "Câmera da luta" em Jogo.
- **Ícones:** os itens novos no atlas `item_icons` (`tools/generate_ui.py`, na ordem de `ICONS` e `UiStyle.ICONS`).

### 12.3 Som

| Som | Fonte |
|---|---|
| Vento da arma, impacto em carne, madeira, ferro e escudo, arma quebrando | gravações reais CC0 (Kenney e Freesound), no `process_real_sounds.py` e no `CREDITS.md` |
| Passos de bota do orc | os mesmos cortes dos passos, um tom abaixo e mais pesados |
| Voz do orc (grunhido, grito, dor, morte) | voz gravada CC0 com tom abaixo; **a língua** é o rádio da equipe de resgate ao contrário, sintetizado com ruído de rádio |
| Trompa | sintética, subindo e descendo como a sirene |
| Tambor | sintético, tocado por um orc de verdade, no BPM do coração do goblin (o `VitalsHud` já calcula) |
| Troll | respiração grave e um zumbido de motor bem baixo (é o Zelador) |

Tudo no bus `World` (luta) ou `Ambience` (tambor e trompa de longe), com `OccludedAudio`.

### 12.4 Prática de luta (`Practice`)

Mesma ideia de hoje, sem barras: `blocks_ok` (defesas bem feitas) abre a janela do aparo até `PRACTICE_PARRY_MAX` (+40%); `melee_hits` diminui o fôlego do golpe até `PRACTICE_STAMINA_MAX` (−25%). Um aviso discreto em cada degrau.

---

## 13. O que muda em cada sistema que já existe

Esta é a lista de conferência: se um item daqui ficar de fora, alguma coisa deixa de fazer sentido.

| Sistema | Arquivo | Mudança | Por quê |
|---|---|---|---|
| Player | `scenes/player/player.gd` | `attack` e `aim` passam a depender do que está na mão; soco só de mão vazia; `speed_factors`; não dorme nem fabrica em luta | O arco e a arma dividem os botões |
| Luta do goblin | `scenes/player/parts/melee_ability.gd` (novo) | Golpes, defesa, aparo, esquiva, furtivo, trava | Uma mecânica, um arquivo |
| Equipamento visível | `PlayerGear` | Arma na mão, escudo no braço, os dois nas costas quando trocados | O que se carrega se vê |
| Armadura visível | `scenes/player/parts/armor_look.gd` (novo, como `LeatherClothes`) | Peças presas aos ossos | — |
| Animação | `GoblinAnimator`, `GoblinActions` | Ações `slash`, `thrust`, `heavy_*`, `block` (pose segurada), `parry`, `dodge`, `hit_light`, `hit_heavy`, `knockdown`, `get_up`, `stealth_kill`, `equip`, `brace`, `throw_spear`, `bandage`, `die`; empunhadura de duas mãos por IK (como o arco); perfil de corpo para o orc (§14) | Goblin e orc usam o mesmo animador |
| Câmera | `PlayerCamera` | Distância de luta, trava suave e dura, dither em orc colado | O orc é o dobro do goblin |
| Equilíbrio | `EdgeBalance` | Empurrão e esquiva perto da borda podem derrubar | Usar o terreno também contra o goblin |
| Vida | `autoload/vitals.gd` | `hit(dano, tipo, zona, de_onde)` com armadura; `bleeding`; perna ferida | O dano deixa de ser só um número |
| Frio | `ColdExposure` | Peitoral de ferro gela à noite | Ferro tem custo |
| Inventário | `autoload/inventory.gd` | Itens novos, `__wear`, `__equipped`, `HUD_ORDER` | Desgaste e o que está vestido |
| Receitas | `data/recipes.gd`, `CraftAbility` | `station`, abas, reparar e ajustar | A bancada |
| Bichos | `scenes/animals/animal.gd` | Perceber o grupo `threat` (não só o goblin); `take_hit` com tipo e zona (o `_vital_multiplier` vira padrão) | Ecologia e "o tiro importa" |
| Javali | `boar.gd` | Investir contra orc; empalar na lança firmada | Dá um motivo para a lança |
| Lobo | `wolf.gd`, `wolf_pack.gd` | Caçar orc fora do acampamento; lobo de guerra que segue um orc; seguir rastro de sangue do goblin | Ecologia |
| Manada | `herd.gd` | Evitar o raio do acampamento | Pressão de caça |
| Flecha | `scenes/items/arrow.gd` | Tipo `pierce`, quebrar em pedra ou ferro, acertar a camada 5, flecha orc acertando o goblin, bloqueada pelo escudo | Flecha dos dois lados |
| Pegadas | `Tracks`, `track_print.gdshader` | Bota de orc | Rastrear patrulha |
| Faro | `SniffAbility` | Trilha do cheiro de orc até 70 m | O sentido em que o goblin ganha |
| Coleta | `ForageField` | Musgo e erva-de-sangue | Cura |
| Defumador | `SmokingRack` | Curtir couro | Couro curtido |
| Troncos riscados | `TreeMarks` | Atraem a rota da patrulha e a Investida | O custo de se orientar |
| Árvores | `Vegetation` | Pinheiro vivo cai com machado; tronco armado | Madeira e armadilha |
| Corvos | `Watchers`, `Crow` | Pousam em corpos; corvo vendo luta soma Vigilância | Os olhos do Zelador também veem a luta |
| Troféus | `Trophies` | Estandarte do chefe, elmo amassado | A toca conta a história |
| Prática | `Practice` | Aparo e fôlego | Aprender pela prática |
| Story e beats | `story.gd`, `story_beats.gd` | Gatilhos `orc_seen`, `orc_killed`, `raid_end`, `hour`; contadores; falas | §11 |
| Jogo | `autoload/game.gd` | Bolsa na morte; nada de orc no menu, cena, Bem-vindo e ficar; não dormir na Investida | §10 e §11.5 |
| Sono | `SleepingPelt` | "Não dá para dormir com eles lá fora." | A Investida |
| Visita | `Visit` | Lucidez menor depois de luta pesada | O corpo de Ari |
| Sala de controle | `ControlRoom`, `camera_feed.gdshader` | Equipe de máscara numa tela; falas novas | A segunda leitura |
| Lá fora | `Outside` | A pessoa de respirador | O último eco |
| Console | `KeeperConsole` | `ameaca`, `give`, `status` | — |
| Autopiloto | `GoblinAutopilot` | Garantir o arco na mão (sem orcs no Bem-vindo, não precisa lutar) | Não quebrar o modo |
| Configurações | `autoload/settings.gd`, `SettingsMenu` | 3 ações, gamepad, opções de trava e câmera | — |
| HUD | `hud.gd` | Ícone da arma com desgaste; vinheta de direção | — |
| Pause | `pause_menu.gd` | Estado e a linha "Na mão" | — |
| Dicas | `PauseMenu` (Dicas) | Página "Luta" e o bestiário | — |
| UI | `tools/generate_ui.py` | Ícones dos itens | — |
| Som | `tools/generate_sounds.py`, `process_real_sounds.py`, `CREDITS.md` | §12.3 | — |
| Ambiente | `Ambience` | Tambor e trompa saem dos orcs de verdade (`call_at`) | Todo som sai de alguém |
| Layout | `forest_layout.gd` | `ORC_CAMP`, `ORC_TOWER`, `ORC_ROUTES`, pedras do salto, `ORC_CAVE_KEEP_OUT`, zona da ruína | Fonte única dos pontos do mapa |
| Floresta | `forest.gd` | Monta o acampamento; repõe orcs no amanhecer (como `_restock`, longe do goblin) | — |
| Vazio do norte | `NorthVoid` | Orc não nasce nem anda além da borda | O R3 |
| Física | camadas | **Camada 5 `combat`** (áreas de acerto de goblin e orcs) | O goblin hoje não tem área para flecha |
| DevTools | `dev_tools.gd` | `--equip=`, `--spawn=orc:x,z`, `--set=world.orc_day:n` | Testar tudo |
| Diário de playtest | `Playtest` | Lutas (início, fim, quem ganhou, vida perdida), Investidas, bolsa perdida e recuperada | Ajustar pelo jogo de verdade |
| Testes | `tests/` | Roteiros da §16 | — |
| Documentação | `CLAUDE.md`, `plano.md` | Tirar "combate corpo a corpo" de "Ainda não existe" quando a F11 estiver pronta; seções novas | — |

---

## 14. Arquitetura nova

| Peça | Tipo | O que faz |
|---|---|---|
| `components/combat_body.gd` (`CombatBody`) | Node | Vida, postura, zonas (por osso), armadura e `receive_hit(golpe)`. O goblin (ligado ao `Vitals`) e cada orc têm um. |
| `components/weapon_trace.gd` (`WeaponTrace`) | Node | O segmento da arma nos quadros ativos: testa o caminho contra a camada 5 e a 4 e entrega o golpe uma vez por alvo. |
| `data/weapons.gd` (`Weapons`) | dados | Cada arma: mãos, tipo, dano, alcance, fôlego, quadros (preparação, ativo, recuperação), sequência, desgaste e malha. Cada armadura: lugar, proteção e custos. |
| `scenes/player/parts/melee_ability.gd` | Node | A luta do goblin (§3). |
| `scenes/items/weapon_mesh.gd` | malhas | Faca, porrete, lança, espada, machado, martelo e escudos montados em código (como o `BowMesh`). |
| `scenes/monsters/orc/orc.gd` (`Orc`) | CharacterBody3D | IA (§7.3), `Senses`, `CombatBody`, animador e voz. |
| `scenes/monsters/orc/orc_camp.gd` (`OrcCamp`) | Node3D persist | O acampamento: paliçada, tendas, fogo, tambor, jaula, baú, arena; quem vive; reposição; a agenda da Investida. |
| `scenes/monsters/troll/` (F14) | — | O troll da ponte. |
| `scenes/world/props/trap_field.gd` (`TrapField`) | persist | Estacas, tronco armado e corda de ossos. |
| `scenes/world/cave/workbench.gd`, `cave_stash.gd` | persist | Bancada e esconderijo. |
| `scenes/world/props/dropped_bag.gd` | persist | A bolsa da morte. |
| `assets/models/orc/source/build_orc.py` | Blender | O orc no esqueleto de 31 ossos do goblin, com as peças de armadura e a máscara à parte. |
| Perfil de corpo (`BodyProfile`) | Resource | O que hoje é do goblin dentro do `GoblinAnimator` (pose neutra, manias, ritmo manco, alcance da perna) vira dado. O goblin e o orc têm cada um o seu. |
| Grupo `threat` | grupo | Quem os bichos percebem: o goblin e os orcs. |

**Sinais novos em `Events`:** `fight_started(inimigo)`, `fight_ended(resultado)`, `orc_seen(orc)`, `orc_killed(tipo, silencioso)`, `raid_started`, `raid_ended(ganhou)`, `bag_dropped(posição)`, `weapon_broke(item)`.

**Regra de comunicação mantida:** a luta do goblin não sabe que orcs existem, só entrega golpes ao `CombatBody` que encontrar. O `OrcCamp` não sabe da Investida pela história: ele liga quando o flag `raid_tonight` liga.

---

## 15. Fases

Cada fase termina jogável, com o teste de fumaça, roteiro `--run` e prints conferidos.

| Fase | Entrega | Pronto quando |
|---|---|---|
| **F11: Fundação da luta** | `CombatBody`, `WeaponTrace`, `Weapons`, `MeleeAbility` (golpes, defesa, aparo, esquiva, fôlego, postura, furtivo nos bichos), faca, porrete, lança (firmar e arremessar), as poses de luta, camada 5, tendão, sangramento, musgo, bandagem, erva, a bancada, o esconderijo, desgaste e reparo, zonas nos bichos, flecha que quebra, as 3 teclas novas | A lança firmada mata o javali na investida; a esquiva passa pela mordida do lobo; o sangramento para com a bandagem; os testes antigos passam (o soco ainda derruba árvore) |
| **F12: Os orcs** | Modelo do orc (`build_orc.py`), `BodyProfile` e o animador no orc, `Orc` com os estados do §7.3, batedor, arqueiro e guerreiro, ataques legíveis, grupo e moral, os bichos percebendo os orcs (`threat`), pegadas de bota, faro de orc, revistar, armas e peças orc, ajustar na bancada, a escalada (§9.2) até o dia 8, o acampamento sem chefe, a torre, a bolsa da morte (`DroppedBag` e `LOOT`), as vozes e o tambor | Um roteiro faz o goblin abater um batedor em silêncio, ser visto por outro, lutar, fugir, ser procurado e se esconder no capim; os bichos fogem do orc; a bolsa vai para o baú e volta; prints do orc de dia, de noite com tocha e do acampamento |
| **F13: Guerra pela toca** | Espada, machado (pinheiro vivo), martelo, escudo orc, armaduras e seus custos, flechas de ferro, o chefe e os padrões dele, o lobo de guerra, as armadilhas, a Investida, os troncos riscados atraindo, os troféus, a prática de luta, o bestiário, a Vigilância da luta | A Investida é ganha num roteiro com estacas e tronco armado e perdida em outro; o chefe é morto pelo poste e pelo aparo; prints da toca preparada e da Investida |
| **F14: A segunda leitura e mais monstros** | As pistas das máscaras, tambor e trompa ligados à história, as falas da conversa, a tela da equipe de resgate, a pessoa de respirador lá fora, os orcs fora do Bem-vindo e depois do ficar, o console, o troll da ponte e o "pegar e largar na toca"; **proposta:** um segundo vale ligado por um desfiladeiro, onde ficam o acampamento e a ponte | Os 3 finais e o Bem-vindo de volta jogados com orcs no mundo; `tests/run_all.ps1` inteiro passando |

**Feito (F11, experimental, branch `experimento/combate`):**
- **Dados e números:** `data/weapons.gd` (`Weapons`: faca de pedra, faca de osso, porrete e lança; tempos dos golpes por família em `SWINGS`) e o bloco "F11" do `Tuning`.
- **Luta do goblin:** `MeleeAbility` (parte do Player): golpe leve que encadeia até 3, forte segurando, defesa, aparo, esquiva com invulnerabilidade, fôlego sem barra (ofega, golpe lento e fraco), postura (cambaleia, cai e levanta), golpe furtivo nos bichos e trava suave no bicho mais perto. `WeaponTrace` (`components/`) testa o caminho da lâmina entre dois quadros com esferas; o orc vai usar o mesmo.
- **Golpes recebidos:** `Player.receive_attack` → `MeleeAbility.defend`. Lobo e javali batem por ali: a mordida pode ser esquivada, segurada ou aparada (o lobo aparado recua e gane), e a investida do javali na lança firmada fere o javali e acaba a investida.
- **Corpo e arma:** poses novas em `GoblinActions` (corte e revés, golpe de cima, estocada, esquiva, cambalear, queda, pegar a arma) medidas pela janela do golpe (`GoblinAnimator.strike_window`); `_weapon_overlay` (arma pronta e defesa). `WeaponMesh` monta as armas; o `PlayerGear` as segue na mão no mesmo quadro da pose (a lança vai de uma mão à outra) e põe o arco nas costas. Com arma de uma mão, a tocha vai para a mão esquerda; com a lança, é fincada.
- **Inventário:** `Inventory.held()`/`hold()` (a arma na mão, vai no save) e o desgaste por unidade (`wear`, `wear_down`, `repair`, chave `__wear`); a lança arremessada (`ThrownSpear`, filha da `Arrow`) volta com o desgaste que tinha.
- **Cura:** `Vitals.bleeding` (golpe de corte e mordida), bandagem de musgo e erva-de-sangue pela mesma tecla de comer (`EatAbility`).
- **Mundo:** a bancada (`Workbench`, filha da Cave, montada pela receita) com as receitas de bancada e o conserto da arma na mão; tendões ao coletar (o cervo dá 2); musgo e erva-de-sangue na `ForageField`; flecha que quebra no chão duro.
- **Teclas:** `dodge` (C, R3) e `weapon_swap` (Tab, Cruz ↑); `--equip=<arma>` no DevTools; a página LUTA nas Dicas; sons sintéticos em `tools/generate_combat_sounds.py`.
- **Mudou do plano:** o musgo cresce no tronco das árvores secas, do lado norte (no chão, o capim alto do vale inteiro o escondia), e some quando a árvore cai. O esconderijo, a prática de luta, a trava dura e o ícone da arma no HUD ficaram para a F13. A pose do porrete na defesa é o porrete erguido ao lado do rosto.
- **Teste:** `tests/test_f11_luta.gd` (receitas e bancada, troca, golpes, sequência, defesa, aparo, esquiva, postura, lança firmada, sangramento e cura, desgaste, arremesso, save).

**Feito (F12, experimental, branch `experimento/combate`):**
- **Modelo:** `assets/models/orc/source/build_orc.py` abre o `goblin.blend`, muda as proporções pelos ossos (com herança de escala pela média, para os braços não cisalharem), assa a pose na malha e faz dela o novo repouso. A máscara de couro com os dois discos de osso, o elmo e o peitoral se encaixam na malha medida (os ossos ficam dentro do focinho e do crânio). No jogo a escala é do nó (`Tuning.ORC_MODEL_SCALE`), então as poses do animador crescem junto; a paleta vem do `GoblinLook.apply(model, tints, span)`.
- **`Orc` (`scenes/monsters/orc/`):** CharacterBody3D na camada 6, área de acerto na 5. Estados do §7.3 (patrulha, desconfiado indo ver, luta, procura, fuga, ajoelhado, morto, indo embora). Sentidos pelo `Senses` (cone, alcance menor de noite, audição, faro curto); de perto, na luta, não perde o goblin. Golpes com a arma de verdade (`WeaponTrace`), o grunhido de aviso, o corpo curvado no golpe (`GoblinAnimator.strike_bend`: sem isso o golpe de lado passava por cima do goblin), recuo quando colado. Zonas (cabeça, tronco, pernas que mancam), peitoral e elmo de ferro do guerreiro, postura (ajoelha), moral (foge), revistar (arma gasta, sucata, carne seca).
- **`OrcBand`:** chegada pelo dia (batedor do dia 3, patrulha do dia 5), rotas em volta do vale, grito que chama os de perto, no máximo dois atacando, a moral dos que viram um cair; desligado no Bem-vindo, depois de Ficar e com `ameaca off` no console do Zelador. Nos testes automáticos os orcs só chegam com `--orcs`; `--spawn=orc:x,z[:warrior]` põe um.
- **Mundo:** os bichos (menos o lobo) percebem o orc e fogem dele; o orc não entra na toca nem na ruína; vai embora às 19h.
- **Goblin:** área de acerto (camada 5), `Player.take_hit` para flechas, a flecha acerta orcs, o golpe do goblin passa o tipo e a postura ao orc (`Orc.strike`).
- **Mudou do plano:** o aparo ficou em 0,25 s (com 0,18 s a lâmina do orc, que desce num arco, chegava depois); os orcs não vão no save (voltam no dia seguinte), e o acampamento, o chefe, a bolsa da morte, as pegadas de bota, o faro do orc e os sinais dos dias 1 e 2 ficam para a F13.
- **Teste:** `tests/test_f12_orcs.gd`.

**Por que nessa ordem:** a F11 deixa a luta boa contra o que já existe (javali e lobo), sem modelo novo, e o risco maior do plano (a luta ser gostosa) aparece cedo. A F12 traz o risco técnico maior (o animador no orc e os bichos percebendo mais de um). A F13 é conteúdo em cima das duas. A F14 amarra na história.

**Depois da F12, uma sessão de playtest sua** com o build de depuração: o diário mostra quanto você luta, foge e morre, e a F13 sai ajustada por isso.

---

## 16. Testes e ferramentas

| Roteiro | O que confere |
|---|---|
| `tests/test_f11_luta.gd` | Equipar, golpe leve e forte nos quadros certos, defesa, aparo dentro e fora da janela, esquiva com invulnerabilidade, fôlego acabando, postura derrubando, lança firmada e o javali, arremesso e pegar de volta, furtivo num cervo, sangramento e bandagem, desgaste e reparo, bancada e esconderijo, save e load com o equipamento |
| `tests/test_f12_orcs.gd` | Sentidos do orc (cone, escuro, tocha, capim), pedra levando a `INVESTIGATE`, alerta do grupo, no máximo 2 atacando, moral e fuga, revistar, bolsa da morte levada e recuperada, cervo fugindo do orc, orc não entra na toca nem na ruína, escalada por dia |
| `tests/test_f13_guerra.gd` | Chefe preso no martelo e no poste, armaduras (tipos de dano), armadilhas, a Investida ganha e perdida, troncos riscados puxando a rota, Vigilância da luta, troféus |
| `tests/test_f14_leituras.gd` | Falas da conversa com `orc_killed`, Bem-vindo sem orcs, ficar esvazia o acampamento, troll pegando e largando na toca, Reciclagem zerando equipamento, esconderijo e acampamento |

**DevTools novos:** `--equip=spear,shield,orc_helmet`, `--spawn=orc:x,z[:tipo]`, `--set=world.orc_day:7`, `--set=world.raid:1` e `--give` com os itens novos.

O `run_all.ps1` já guarda e devolve os arquivos do jogador. Os roteiros novos entram sozinhos.

---

## 17. Riscos técnicos

| Risco | Plano |
|---|---|
| O `GoblinAnimator` (o maior script do projeto) estar preso demais ao goblin para animar o orc | Antes de mexer, um teste: o orc com o animador do goblin como está, só com a escala. Depois, tirar para o `BodyProfile` só o que o print mostrar errado. |
| Custo de CPU: o animador é pesado e hoje roda só para o goblin | No máximo 6 orcs com IA cheia; além de 40 m o animador roda a 15 Hz; atrás da neblina, só a posição. Medir antes e depois (hoje ~10 ms em `_process`). |
| Os bichos olhando mais de um alvo pesarem | Cada bicho olha no máximo 3 do grupo `threat`, os mais perto, recalculados a cada 0,5 s. |
| A luta não ficar boa (o maior risco de design) | A F11 entra só com javali, lobo e um boneco de treino de palha (só nos testes) e é jogada antes de existir orc. |
| Acerto pelo segmento da arma falhar em golpe rápido | O teste é pelo caminho entre dois quadros (não pela posição), e o golpe tem pelo menos 3 quadros de física ativos. |
| Orc andando no meio do pinheiral | Reto quando livre e grafo de pontos por região, como o Zelador. A paliçada e as rotas ficam onde o grafo é simples. |
| O vale ficar pequeno com orcs | A escalada mantém poucos de dia; a F14 propõe o segundo vale. Antes disso, o acampamento no canto oposto ao da toca. |
| Saves de antes | Chaves novas com padrão, como sempre. |
| Tom: virar um jogo de fantasia comum | Os pilares do §1, as duas leituras do §2, e nada de música, número na tela ou carne de orc. |

---

## 18. Decisões abertas (com o padrão adotado)

Este plano já segue um padrão em cada ponto abaixo. Trocar é editar dados ou um parágrafo, não refazer o plano.

| Pergunta | Padrão adotado | Alternativa |
|---|---|---|
| Os orcs aparecem desde o dia 1? | Sinais no dia 1, o primeiro orc no dia 3 | Orcs desde o dia 1 (o Ato I fica mais tenso e menos "só caça") |
| A segunda leitura (orcs = equipe de resgate) | Sim | Orcs só do livro, sem ligação com o Abrigo |
| O goblin pode ficar forte? | Nunca de frente contra grupo ou chefe | Deixar a armadura de ferro torná-lo um tanque |
| Morte em luta | Bolsa no chão, levada pelo orc | Só perde a comida (como hoje) |
| A toca segura | Sim, menos na Investida | Os orcs podem entrar sempre |
| Mapa | Acampamento no vale de hoje; segundo vale na F14 | Aumentar o mapa já na F12 |
| Troll | O Zelador, não mata | Um monstro comum que mata |
| Outros monstros | Só orcs, lobo de guerra e troll | Aranha da mina, coisa da neblina (cada um precisa da sua segunda leitura antes de entrar) |
