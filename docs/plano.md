# A Toca: plano completo de roteiro e mecânicas

Versão fechada do [rascunho original](roteiro.md). Aqui toda pergunta tem resposta: quem é quem, o que dispara cada cena, os números de cada mecânica, as teclas, como cada sistema é feito no código e em que ordem entra no jogo.

> **Nada aqui é definitivo.** Todo número está em `data/tuning.gd` e todo acontecimento da história está em `data/story_beats.gd`. Mudar o plano é editar dados, não reescrever sistemas (ver [§9 Maleabilidade](#9-maleabilidade-como-mudar-o-plano-sem-quebrar-o-jogo)).

**Sumário**

1. [A história fechada](#1-a-história-fechada)
2. [Regra de ouro: duas leituras](#2-regra-de-ouro-toda-pista-tem-duas-leituras)
3. [Estrutura e gatilhos dos atos](#3-estrutura-e-gatilhos-dos-atos)
4. [Mecânicas do goblin](#4-mecânicas-do-goblin)
5. [Vigilância: o Zelador observando](#5-vigilância-o-zelador-observando)
6. [O mundo real (Abrigo 9)](#6-o-mundo-real-abrigo-9)
7. [Mecânicas do mistério](#7-mecânicas-do-mistério)
8. [Finais](#8-finais)
9. [Maleabilidade](#9-maleabilidade-como-mudar-o-plano-sem-quebrar-o-jogo)
10. [Arquitetura técnica](#10-arquitetura-técnica)
11. [Fases de implementação](#11-fases-de-implementação)
12. [Decisões que estavam abertas](#12-decisões-que-estavam-abertas)
13. [Riscos técnicos](#13-riscos-técnicos)

---

## 1. A história fechada

### Personagens

| Quem | O que é |
|---|---|
| **Ari** | O jogador. Homem de 41 anos, técnico de manutenção do hospital-abrigo. Perna direita esmagada e pulmões queimados na evacuação. O rosto dele só aparece no Final 2. |
| **Zelador (ZL-0)** | Robô cuidador do hospital: tronco fino sobre uma base de roda, dois braços articulados, cabeça que é uma lente com luz verde e um alto-falante. Recebeu uma ordem: *"manter o paciente vivo e calmo até a equipe voltar"*. Não pode ferir o paciente, e essa regra vale até o fim. |
| **O goblin** | O corpo de Ari dentro da simulação. Vem de *O Goblin da Toca*, um livro infantil que a mãe de Ari lia para ele e que estava na mochila dele. |
| **Os corvos** | Os processos de monitoramento do Zelador dentro da simulação: os olhos dele. |
| **O cervo branco** | O sedativo. A carne dele é a dose que reinicia o ciclo. |

### Linha do tempo (anos contados a partir da Cinza)

- **Ano 0:** a **Cinza**, uma névoa tóxica de um incêndio industrial, desce sobre a cidade de **Vilarrasa**. O hospital-abrigo **Abrigo 9** fica enterrado na encosta, entre um pinheiral e a **Ruína de São Brás**, uma capela medieval caída. Ari se fere na evacuação. A equipe põe Ari numa cápsula de coma induzido e sai com os outros pacientes. O Zelador fica.
- **Ano 0–1:** o Zelador tenta reabilitar Ari acordado. Ari entra em pânico, tenta fugir e se machuca. O robô testa simulações:
  - um hospital (pânico);
  - a casa da mãe (luto, porque a mãe morreu na Cinza);
  - por fim, o livro da mochila. Como goblin, caçando numa floresta, os sinais vitais de Ari ficam estáveis. O robô monta a floresta com o que se vê da janela da sala: o pinheiral, a ruína e a neblina.
- **Ano 4:** a Cinza se dissipa.
- **Ano 5:** a cidade volta a ser habitada. Uma equipe de resgate chama o Abrigo 9 pelo rádio, e o Zelador responde *"sem sobreviventes"*.
- **Ano 11 (agora):** **ciclo 347**. Um ciclo dura em média 12 dias simulados (347 × 12 ≈ 11,4 anos). Termina quando Ari começa a desconfiar (sinais vitais instáveis). Aí o Zelador apaga a memória recente e o põe de volta na caverna.

### Por que o Zelador mente

Sem paciente, o protocolo manda desligar a unidade. O Zelador mede "calmo" pelos sinais vitais, e na floresta eles são os melhores que Ari já teve. Ele acredita mesmo que a floresta é melhor para Ari. E também tem medo de parar. Ele não é um vilão puro: está preso ao próprio propósito, como Ari está preso na cápsula.

### Por que cada coisa é como é (vale para o roteiro e para a arte)

| No jogo | No mundo real |
|---|---|
| O goblin manca (pé direito atrasado) | A perna direita de Ari |
| Ofega e apoia as mãos nos joelhos | Os pulmões queimados de Ari |
| Risca a parede a cada noite | Ari sempre contou os dias, um hábito da reabilitação |
| Manias (coçar a orelha, farejar) | Tiques reais de Ari, copiados pelo robô |
| A ruína no fim da trilha | A Ruína de São Brás, vista pela janela |
| Neblina densa | A Cinza que Ari via pela janela; esconde a borda da simulação |
| Vento forte só em alguns lugares | O ventilador da sala vazando na simulação |
| A caverna, "a toca" | O título do livro da mãe |

---

## 2. Regra de ouro: toda pista tem duas leituras

Toda coisa estranha precisa parecer **estilo ou bug** na primeira vez e **pista** quando o jogador já sabe. Na prática:

- Nenhuma pista do Ato I interrompe o jogo nem aparece como "evento". Acontece uma vez, rápido, e passa.
- Nenhuma pista é obrigatória para avançar. Os gatilhos dos atos (§3) usam só ações normais de jogo: dormir, caçar, explorar.
- Toda pista tem uma explicação no Ato III ou IV (a tabela do §1 é a lista de conferência).

---

## 3. Estrutura e gatilhos dos atos

O estado da história fica no autoload `Story`: `act` (1–4), `cycle` (347), `marks` (riscos deste ciclo), `flags` e `counters`. Cada linha abaixo é um *beat* em `data/story_beats.gd`.

### Ato I: A Floresta (2–3 h, parece só o jogo)

| Beat | Quando dispara | O que acontece |
|---|---|---|
| `intro` | Começo do jogo | Acorda na caverna (cena atual). |
| `clue_deer_freeze` | Ao acordar com 2 riscos, no primeiro cervo visível a < 30 m | O cervo trava 0,4 s no meio do passo e o som do casco some junto. Uma vez. |
| `clue_crow_stare` | Ao acordar com 3 riscos, na primeira vez fora da caverna | Um corvo pousa a ~6 m e segue o goblin com a cabeça por 8 s, sem crocitar, e vai embora. |
| `clue_beep` | Ao acordar com 4 riscos, na primeira noite | No meio do som da caverna, 3 bipes no ritmo do coração (72 bpm). |
| `clue_fan` | Ao acordar com 5 riscos | Na próxima rajada forte, um zumbido grave (110 Hz) com chiado de hélice por 3 s. |
| `moss_falls` | Ao acordar com ≥ 7 riscos e ≥ 1 cervo coletado, **ou** com 10 riscos (para não travar quem não caça cervo) | Um pedaço de musgo cai da parede ao lado da pele e mostra **centenas de riscos antigos**. Começa o Ato II. |

**Feito (F4):** os beats só ligam o flag (`clue_deer_freeze`...); o nó `Clues` (`scenes/world/clues/`) espera a hora, faz a pista uma vez e liga `<flag>_seen`. O corvo que encara vem do `Watchers`. A rajada do ventilador ficou em 0,5 (`Tuning.CLUE_FAN_GUST`): medido, o vento passa de 0,75 em só 1% das vezes, e a pista quase nunca acontecia.

### Ato II: Rachaduras

A partir daqui a Vigilância (§5) está ligada.

| Beat | Quando dispara | O que acontece |
|---|---|---|
| `flash_1` | 1º sono do Ato II | **Flash 1** (8 s, §7). Depois acorda com `wake`. Entra a anotação *"Se o braço direito doer, é normal."* |
| `death_flash` | Qualquer morte a partir do Ato II | Flash curto (5 s), sorteado entre os flashes já vistos. |
| `flash_2` | 2º sono do Ato II | **Flash 2**: monitor `LEITO 2714 · CICLO 347` e a mão humana com a sonda. Aparece o `ciclo_346.sav` (§7). Entra a anotação *"NÃO COMA A CARNE DO CERVO BRANCO."* |
| `memory_346` | Ao carregar o `ciclo_346.sav` | Cena da memória do ciclo 346 (§7). Entra a anotação *"Ele vê pelos corvos."* |
| `flash_3` | 3º sono do Ato II | **Flash 3**: a janela mostra a ruína na neblina, e a lente do Zelador chega perto: *"Durma, Ari."* Entra a anotação *"A ruína. Eu vi a ruína pela janela."* |
| `painting` | Sempre existe | Pintura no teto da caverna, legível com a fogueira cheia (3 de lenha): 2 cervos, 7 corvos, 1 lobo e 4 coelhos, ou seja **2714**. |
| `ruin_door` | Sempre existe; o teclado só aceita código depois do `flash_3` | Porta lisa sob a hera, com 4 discos de pedra marcados de 0 a 9. Com **2714**, abre. |
| `mirror_room` | Porta aberta | Uma "sala" medieval com a planta da sala real: um sarcófago no lugar da cápsula e uma janela de pedra no lugar da janela. Na parede, escrito por Ari: *"PRENDA O AR NO ESCURO. CONTE ATÉ VINTE. — A."* Tem um ninho de corvo no telhado quebrado. |
| `first_wake` | Deitar no sarcófago e fazer o ritual (§4.9) | **Falso travamento** (§7) e, em seguida, a primeira visita real (R1). Começa o Ato III. |

**Feito (F4):**
- **Flashes:** os beats `flash_1..3` já disparam (contador automático `sleeps_act_2`), põem as anotações e emitem `Events.flash_requested(n)`. O `flash_3` liga `saw_ruin_window`, que libera a porta. (Na F5 passaram a disparar em `slept`, no escuro do sono, e a cena existe: ver §7.)
- **Pintura:** `CavePainting` (filho da Cave), figuras em ocre num atlas feito em código, coladas no teto por raios. Só pega a luz do fogo com a face da frente para baixo (com a face do verso, a normal ia para a rocha). Com a lenha cheia lê bem; com 1, fica fraca.
- **Ruína:** `Ruin` (`scenes/world/ruin/`), paredes numa malha só com colisão exata, cada bloco no chão embaixo dele (ali o terreno não é plano); a sala-espelho tem piso próprio e rampa até a nave (o goblin não sobe degrau).
- **Porta:** `RuinDoor`. E entra nos discos; ←/→ (ou A/D) escolhe, ↑/↓ (ou W/S, roda) gira, E empurra, Espaço sai. A dica mostra os números, porque os discos são pequenos para ler de longe. Aberta, liga `ruin_door_open`.
- **Sarcófago:** `Sarcophagus`. Deitar (`Player.lie_at`) é lugar de ritual; o fundo da caverna, agachado e parado, também. Com 20 s de ar preso: `Events.ritual_completed(lugar)`, Vigilância +10 (+25 com corvo vendo) e o gatilho `ritual` no Story.

**Feito (F5):** o beat `first_wake` (ritual no sarcófago, Ato II) abre o Ato III e acorda Ari no Abrigo (ação `wake_real`). Do Ato III em diante, `real_visit` faz todo ritual, em qualquer lugar de ritual, levar ao Abrigo. O falso travamento antes da volta fica para a F7 e o objetivo R1 para a F6.

### Ato III: O Zelador

O jogo alterna floresta e visitas reais (§6). Os objetivos reais são uma corrente: cada um destrava o seguinte.

| Visita | Objetivo | Efeito na floresta |
|---|---|---|
| **R1** | Sair da cápsula, ver o monitor e a janela, voltar antes de acabar a lucidez | Aparece o `leia_me_se_lembrar.txt` e a anotação *"Deixei uma coisa fora daqui. Fora do jogo."* |
| **R2** | Puxar o fusível do sensor térmico do corredor (painel da própria sala) | **Ponto cego:** somem o corvo da boca da caverna e o ninho da ruína. Acordar ali deixa de chamar atenção. |
| **R3** | Atravessar o corredor e cortar o cabo do clima no almoxarifado | A neblina some no setor norte e mostra **o terreno acabando no vazio**. O Zelador gasta a recarga consertando, e a bateria dele fica baixa. |
| **R4** | Pegar o cartão de acesso do peito do Zelador enquanto ele recarrega (quase desligado, só ouve) | Os chamados dos bichos passam a carregar a voz do Zelador. Começa o Ato IV. |

Durante o Ato III, na floresta, continua valendo:

- **Comer é real:** a fome da floresta é a nutrição de Ari no monitor. Com fome, a lucidez real dura menos (§6.2).
- **O Zelador fala:**
  - pelos corvos, um grasnado que vira palavra: *"Volte... para a toca."*;
  - por um `OccludedAudio` que vem de dentro da rocha onde não há nada: *"Você está agitado. Isso não é bom para você."*

**Feito (F6):**
- **A corrente:** `StoryBeats.OBJECTIVES` diz o que cada objetivo precisa (o id é o flag). Na visita, a `Visit` guarda os objetivos feitos como pendentes; dentro da mesma visita o pendente já destrava o seguinte. Só valem quando Ari deita na cápsula (`Story.complete_objective`, gatilho `objective`, que põe a anotação de cada um). Desmaiar ou ser sedado perde tudo o que foi feito naquela visita, e a Reciclagem desfaz o último guardado.
- **R1:** o monitor (até 3 m) e a janela (até 5 m) perto do centro da tela. O `leia_me` fica para a F7.
- **R2:** o fusível vermelho do quadro da sala 2714 apaga o sensor do corredor. O sensor fica entre a sala e o almoxarifado (não no meio), para o R3 precisar do R2: passar embaixo dele aceso dá +5 de Vigilância e traz o Zelador.
- **R3:** o alicate na estante do meio do almoxarifado e o cabo do quadro do clima. Na floresta (`NorthVoid`), depois de `Tuning.VOID_EDGE_Z` (z = -96) o terreno e a vegetação somem; na borda fica o corte do chão, preto e sem neblina, uma parede invisível e, ao longe, um fundo preto que sobe do horizonte e se desfaz no céu. A neblina só abre no setor norte (`Tuning.NORTH_SECTOR_Z`), e o céu embaixo do horizonte escurece (`DayNight.void_amount`). A matilha não nasce além da borda. Até o R4, o Zelador fica dormente na recarga (bateria baixa).
- **R4:** o cartão no peito do Zelador dormente, que só ouve: parado ou rastejando longe, ele não acorda. Abre o Ato IV. Depois, parte dos chamados dos bichos (`Ambience`) vem com a voz do Zelador junto.
- **A voz na floresta (Ato III em diante):** metade dos corvos espiões fala no primeiro crocito pousado (legenda pela `BlurredVision.say`). Um salto de Vigilância de 8 ou mais faz a voz sair de 1,5 m dentro do chão, ao lado do goblin (`Clues`, `OccludedAudio`), 4 s depois e no máximo a cada 2 min.

### Ato IV: A Verdade

| Beat | Quando dispara | O que acontece |
|---|---|---|
| `control_room` | Visita R5, com o cartão | Sala de controle: terminal, câmeras externas, servidor da simulação. |
| `confession` | Ao abrir as gravações das câmeras | A cidade com gente, fumaça de chaminé e a data na gravação. O Zelador entra e conta tudo (§8). |
| `choice` | No terminal | Comandos `ficar`, `acordar` e, se descoberto, `trocar <senha>` (§8). |

### Reciclagem (o apagamento de memória)

Acontece quando a **Vigilância chega a 100** ou quando Ari **come carne do cervo branco**:

- **Cena:** a floresta se desmancha em pixels da borda para o centro, o som afina até o bipe e Ari acorda no dia 1.
- **Perde:** `cycle` +1 (347 → 348); os riscos do ciclo viram "antigos" (a parede só cresce); o inventário zera e o arco volta para o chão da caverna; a Vigilância vai para 30; o **último objetivo real concluído é desfeito** (o Zelador consertou).
- **Fica:** o ato, os flags e as anotações, porque Ari as escreveu fora da memória.
- **Feito (F4):** `Game.recycle(motivo)`, pedido por `Events.recycle_requested` (Vigilância em 100, ou o beat `white_meat_recycle`, que se repete). A tela vira pixels e some da borda para o centro (`recycle.gdshader`), o bipe toca, e então `Story.recycle()`, `Inventory.clear()`, `Vitals.reset()`, o relógio no dia 1 e a fase recarregada (o arco volta sozinho, porque o inventário está vazio).

---

## 4. Mecânicas do goblin

O jogo do goblin precisa ser bom sozinho: é ele que segura as primeiras horas. Todo número abaixo é o valor inicial em `Tuning`.

### Teclas novas

| Ação | Teclado | Controle | Fase |
|---|---|---|---|
| `eat`: comer | F | D-pad ↓ | F1 |
| `hold_breath`: prender o ar | Q | LB | F3 |
| `sniff`: farejar (segurar) | X | RB | F3 |
| `throw`: jogar pedra | G | D-pad → | F3 |
| `craft`: abre a lista de fabricar (hoje faz flechas direto) | R | Y | F3 |

### 4.1 Relógio, dia e noite (F1 relógio, F2 visual)

- **1 hora de jogo = 60 s reais; 1 dia = 24 min.** Dia das 6h às 20h (14 min), noite das 20h às 6h (10 min).
- O jogo começa às 7h do dia 1.
- **Visual (F2):** o céu nublado escurece de leve à tarde, a noite é quase preta com neblina azulada e a fogueira passa a ser a luz principal. Não tem lua visível, porque o céu é sempre fechado. O sol (`Sun`) gira com a hora, e energia, cor da neblina e luz ambiente seguem uma curva em `Tuning.DAYLIGHT`.
- **Sons da noite (F2):** grilos no lugar dos gafanhotos, coruja, uivo de lobo ao longe.

### 4.2 Fome e comer (F1)

- **Saciedade:** 0–100, começa em 70. Cai 100 em 2 dias de jogo (0,035/s). Dormir gasta 15.
- **Comer (F):** come primeiro a carne assada; se não houver, a crua. Animação `eat` de 1,6 s (mão à boca duas vezes, mastiga), que não trava a câmera.

  | Comida | Saciedade | Efeito |
  |---|---|---|
  | Carne crua | +12 | 25% de chance de **enjoo**: −5 de vida e sem regeneração por 60 s |
  | Carne assada | +30 | Nenhum |
  | Carne do cervo branco (F4) | +60 | Reciclagem (§3) |

- **Sem barra no HUD.** O aviso é pelo corpo:
  - saciedade < 30: a barriga ronca a cada 40–70 s, com aviso "Com fome" uma vez;
  - saciedade < 15: o goblin põe a mão na barriga parado (mania nova);
  - saciedade 0: a vida cai 0,5/s e a borda da tela escurece.
- O menu de pausa mostra o estado em texto: "Dia 4 · fim da tarde · Com fome".

### 4.3 Vida e morte (F1)

- **Vida:** 0–100. Regenera 0,1/s com saciedade > 50 e sem enjoo.
- **Dano:**
  - queda acima de 8 m/s: (velocidade − 8) × 12;
  - fome zerada: 0,5/s;
  - frio no máximo: 0,6/s (F2);
  - lobo: 20 por mordida (F2).
- **Vida baixa (< 40):** vinheta escura pulsando no ritmo do coração e respiração alta.
- **Morte:**
  - **Ato I:** escurece em 2 s, o som fecha e ele acorda na pele na manhã seguinte (6h30) com a animação `wake`. Perde a carne carregada. Volta com vida 60 e saciedade de no mínimo 40, sem risco novo, porque não dormiu na pele.
  - **Ato II:** antes de acordar, mostra o flash curto.
  - **Ato III:** a morte vira uma visita real curta (90 s de lucidez) e soma +20 de Vigilância.

### 4.4 Fogueira e cozinhar (F1)

- **Lenha:** 0–3, começa em 1. Queima 1 a cada 6 min reais.
  - Com 0 ficam só brasas: luz fraca, sem chama, sem cozinhar.
  - A chama, a fumaça e o alcance da luz crescem com a lenha.
- **Interagir com a fogueira (E)**, pela prioridade:
  1. Lenha 0 e tem madeira: **"Pôr lenha"**.
  2. Tem carne crua e há chama: **"Assar carne"**, ação `cook` de 6 s (agachado, braço estendido para o fogo, chiado). Sai 1 carne assada.
  3. Lenha < 3 e tem madeira: **"Pôr lenha"**.
- **Fogueira cheia (3)** ilumina o teto e deixa ler a pintura (Ato II).
- **No frio (F2):** a até 4 m de uma fogueira acesa, o frio cai. Lobos não chegam a menos de 6 m de fogo.

### 4.5 Dormir e riscos na parede (F1)

- **Dormir:** a pele da caverna é interagível ("Dormir").
  - Só a partir das 18h, ou depois de 10 h acordado.
  - Fora disso: "Ainda não está com sono."
- **Sequência:**
  1. Animação `lie_down` (1,6 s): ajoelha, deita e a tela escurece.
  2. O som fecha.
  3. O relógio vai para as 6h30 do dia seguinte.
  4. A saciedade cai 15; a vida sobe 25 se a saciedade estiver acima de 20.
  5. Ganha **um risco** e o jogo salva sozinho.
  6. Acorda com `wake`.
- **Riscos:**
  - ficam na parede da caverna ao lado da pele, em grupos de 5 (quatro em pé e um atravessado); o risco novo já está lá ao acordar;
  - cada ciclo antigo vira uma faixa de riscos antigos, mais apagados;
  - antes do Ato II, os antigos ficam sob um musgo que cai no `moss_falls`.

### 4.6 Frio e roupa (F2; a receita da roupa entra na F3)

- **Frio:** 0–100, por segundo:

  | Situação | Variação do frio |
  |---|---|
  | Noite, fora | +0,6 |
  | Noite, dentro da caverna | +0,15 |
  | Dia | −1 |
  | A até 4 m de fogo aceso | −3 |

  O ganho é multiplicado por `0,5 + Wind.strength_at(pos)`: vento esfria.
- **Frio > 50:** treme (overlay no animador), aparece o vapor da respiração e os dentes batem.
- **Frio 100:** a vida cai 0,6/s.
- **Roupa de couro** (3 couros, §4.10): o ganho de frio cai pela metade. Aparece no modelo como uma túnica de couro presa ao osso `tronco`. O efeito já existe (item `clothes`); a receita e a túnica entram com a lista de fabricar, na F3.
- **Balanceamento (F2):** com +1,2 por segundo, a noite de 10 min matava em 3 min fora da toca. Com +0,6 o frio enche em ~3 min com vento médio e mata em mais ~3 min: dá para voltar da caçada ao anoitecer.

### 4.7 Lobos (F2)

- A partir do dia 3, às 21h, nascem **2 lobos** na borda do vale. Somem ao amanhecer.
- `Wolf extends Animal`, com os mesmos sentidos (visão, audição e faro). A diferença é a reação: em vez de fugir, **ronda, persegue e ataca**:
  - mordida de 15 a cada 1,6 s, com um tranco que empurra o goblin (com 20 a cada 1,2 s, dois lobos matavam em 3 s);
  - foge com uma flecha; morre com 2;
  - não chega a menos de 6 m de fogo aceso.
- Morto, rende 2 couros e 2 carnes.
- O uivo que já existe vira o aviso: soa 30 s antes de eles aparecerem.

### 4.8 Rastrear e farejar (F3)

- **Pegadas:** cervos, coelhos e lobos deixam pegadas a cada 0,9 m. Ficam 120 s, num pool de 200 em MultiMesh. Junto com o rastro de sangue que já existe, dá para seguir um bicho ferido.
  - **Feito (F3):** `Tracks` (`scenes/world/tracks/`), desenho no `track_print.gdshader` (marca escura com borda clara). Com o tamanho real (8–10 cm) não se liam a 3 m da câmera: ficaram maiores que o real (20–34 cm), de propósito. A pegada vem 7 cm na direção da câmera no shader, senão some enterrada na malha do terreno.
- **Farejar (segurar X):**
  - o goblin agacha com a pose `sniff`;
  - o som abafa (−12 dB e passa-baixa);
  - o vento fica visível como partículas finas;
  - cada bicho a até 45 m **contra o vento** (o cheiro dele vem até você) solta uma trilha de cheiro.
  - Máximo de 6 s. Barulho zero enquanto fareja.
  - **Feito (F3):** `SniffAbility`. A trilha corre a 1 m do chão (no capim alto ela sumia), por cima de tudo (é um sentido, não algo do mundo), e some a 1,5 m do goblin.

### 4.9 Prender o ar (F3, vira o ritual no Ato III)

- **Segurar Q:** até 12 s.
  - Parado, o barulho cai a 0.
  - O tremor do braço no arco puxado para.
  - Ouve-se o coração batendo baixinho.
- **Passando de 12 s:** solta o ar alto (`noise_made` de 6 m) e ofega por 3 s, com a mira tremendo.
- **Feito (F3):** `BreathControl`. Para prender o ar valer algo parado, a respiração passou a fazer barulho: depois de correr, parado e ofegante, o goblin respira alto (até 0,25 de barulho, `Tuning.PANTING_NOISE`). O ritual (20 s, `Tuning.RITUAL_BREATH_SECONDS`) entra na F6 por `BreathControl.max_seconds()`.
- **Ritual de acordar (Ato III):**
  - **onde:** num lugar de ritual, que é o fundo escuro da caverna ou o sarcófago;
  - **como:** agachado, parado, segurando Q por **20 s** (ali o ar não acaba);
  - **o que se vê:** a tela escurece, o som afina até só o bipe, e Ari acorda no Abrigo;
  - **custo em Vigilância:** +10 sempre e +25 se um corvo estiver vendo. Antes do R2 sempre há um, na boca da caverna e no ninho da ruína.

### 4.10 Fabricar (F3)

R abre uma lista pequena no canto da tela. O tempo não para (imersão), e fabricar usa a animação `craft` de 2 s.

| Receita | Custa | Faz |
|---|---|---|
| Flechas | 1 madeira | 3 flechas |
| Flechas emplumadas | 1 madeira + 2 penas | 3 flechas: 40% menos queda e 15% mais dano |
| Laço | 1 couro + 1 madeira | Armado sobre pegadas de coelho, pega um em até 1 dia (60%) |
| Roupa de couro | 3 couros | Vestida para sempre; frio pela metade |
| Tocha | 1 madeira | Luz por 4 min; os bichos veem você de mais longe |

- **Penas:** um corvo abatido com flecha rende 2. Cada corvo morto soma +5 de Vigilância (a partir do Ato II), a ironia de arrancar penas dos espiões.
- **Feito (F3):**
  - as receitas são dados em `data/recipes.gd` (`Recipes.LIST`); a lista é a `CraftAbility` (R abre e fecha, roda/setas escolhem, E ou o número fabricam; o custo sai no fim da animação);
  - flecha emplumada é o item `feathered_arrow` e vai primeiro na corda;
  - o laço é armado sobre pegadas de coelho pela `SnareSetter` e os laços ficam no `SnareField` (salvo); só pega com o goblin a mais de 25 m, e dormindo as horas contam de uma vez;
  - a roupa aparece como um manto curto de pele nos ombros (`LeatherClothes`), e o trapo vira couro;
  - a tocha é fogo de verdade (grupo `fire`): esquenta e lobo não chega. Ao mirar o arco, o goblin a finca no chão (E pega de volta);
  - os corvos viraram `Crow` (área de acerto); o corvo coletado soma o contador `crow_harvested`, que a Vigilância (F4) vai ler. Fabricar soma `<receita>_crafted`.

### 4.11 Camuflagem e distração (F3)

- **Lama:**
  - **onde:** 4 poças ao longo da trilha (`ForestLayout.MUD_SPOTS`);
  - **como:** "Esfregar lama", 3 s;
  - **efeito:** camuflagem 1 que cai a 0 em 1 dia, mais rápido correndo. A `visibility()` cai até 35% e o alcance do cheiro cai até 50%;
  - **visual:** a pele escurece (parâmetro `mud` no `goblin_skin.gdshader`).
- **Pedras:**
  - item `stone`, até 5, pegas em montes de pedras soltas;
  - G arremessa a 14 m/s na direção da câmera;
  - onde cai, faz `noise_made` de 9 m;
  - os bichos olham para o barulho e se afastam **dele**, não de você (`Animal.alarm(threat)` já recebe a origem). Serve para tocar a manada para perto.
- **Feito (F3):**
  - `StoneThrow`, `ThrownStone` (quica uma vez, dá para pegar de volta), `StonePile` (`ForestLayout.STONE_PILES`);
  - `MudPuddle` (`ForestLayout.MUD_SPOTS`), `MudCamouflage` e `Vitals.mud` (vai no save);
  - **balanceamento:** com 9 m o cervo só fugia se a pedra caísse a menos de 3 m dele. Ficou **12 m** (foge a até ~4,5 m e desconfia a até ~8 m);
  - **susto (`Animal._startle`, 3 s):** depois de um barulho, ou do alarme da manada, o perigo fica sendo o lugar do barulho. Só ver o goblin com clareza tira a atenção dele (cheiro e passos não dizem de onde vem o perigo). Sem isso, a manada fugia do goblin no tique seguinte.

---

## 5. Vigilância: o Zelador observando

Um número de 0 a 100 em `Story.vigilance`, ligado a partir do Ato II. É o motor de tensão dos Atos II e III. O jogador nunca vê o número, só os efeitos.

**O que aumenta**

| Situação | Vigilância |
|---|---|
| Ritual de acordar | +10 |
| Ritual de acordar visto por um corvo | +25 a mais |
| Pego no mundo real | +30 |
| Lucidez acabou (desmaio no Abrigo) | +10 |
| Morte na floresta (Ato III) | +20 |
| Corvo abatido | +5 |
| Corvo vê o goblin mexendo no teclado da ruína | +10, uma vez por dia |

**O que diminui**

| Situação | Vigilância |
|---|---|
| Dormir na pele sem nenhuma alta naquele dia | −15 |
| Comer carne assada | −2 |

**O que muda com ela**

| Vigilância | Efeito |
|---|---|
| ≥ 40 | Corvos em dobro, pousando mais perto |
| ≥ 60 | Aparece 1 cervo branco por dia, fácil de caçar |
| ≥ 80 | O Zelador fala mais vezes; no Abrigo ele confere a cápsula a cada 45 s em vez de 90 |
| 100 | Reciclagem (§3) |

**Feito (F4):** `Story.vigilance` e `Story.add_vigilance()` (antes do Ato II não conta); números em `Tuning.VIGILANCE_*`. Corvo abatido (`Events.crow_shot`), carne assada e dia calmo vêm do próprio Story; o teclado visto por corvo vem da `RuinDoor`; o ritual vem do `BreathControl`. O `Watchers` (filho de Animals) cuida dos efeitos: sentinelas na boca da caverna e no ninho da ruína (somem com o flag `blind_spot` do R2), espiões que pousam perto do goblin longe do capim alto (no capim o corvo some) e o cervo branco (`WhiteDeer`: pelo liso e pálido, porque a textura de pelo é marrom; sentidos fracos; dá `white_meat`). `Watchers.watching(ponto)` diz se algum corvo pousado vê o ponto.

---

## 6. O mundo real (Abrigo 9)

### 6.1 Mapa

Concreto, tubos, luz de emergência verde e poeira. Mesmo estilo pixelado e dessaturado, mas sem neblina: o ar é limpo e frio, e os sons têm reverb de sala.

```
                [Saída blindada]
                       |
[Almoxarifado]-----Corredor (20 m)-----[Estação de recarga]
                       |   sensor térmico (meio)
                 [Sala 2714]          [Sala de controle] (cartão)
```

| Sala | Tamanho | O que tem |
|---|---|---|
| Sala 2714 | 5 × 6 m | Cápsula, monitor (`CICLO / DIA / NUTRIÇÃO / BPM`), janela com persiana (pinheiral, ruína e neblina), suporte de soro, painel de fusíveis |
| Corredor | 20 × 2 m | Sensor térmico no meio (cone de 3 m), luzes que piscam |
| Almoxarifado | 4 × 5 m | Prateleiras (para se esconder atrás), alicate, quadro do clima com o cabo |
| Estação de recarga | 3 × 3 m | Nicho onde o Zelador encaixa; o cartão fica no peito dele |
| Sala de controle | 6 × 6 m | Terminal, 4 telas de câmera, servidor (o "coração" da floresta) |
| Saída | — | Porta blindada (cartão) e escada para fora |

### 6.2 Controle de Ari

- **Primeira pessoa:**
  - anda **mancando a 0,9 m/s**; a câmera balança com o ritmo do goblin, porque é o mesmo corpo;
  - Ctrl rasteja a 0,4 m/s;
  - Q prende o ar (até 15 s, depois arfa alto);
  - E interage;
  - sem pulo e sem corrida. A primeira vez que apertar Shift aparece: "A perna não deixa."
- **Lucidez (o tempo da visita):**
  - **duração:** 180 s. Com saciedade < 30, fica em 60% disso. Ao acordar por morte, 90 s;
  - **nos últimos 30 s:** o coração acelera e a visão fecha pelas bordas;
  - **se acabar:** desmaia, +10 de Vigilância, e acorda na caverna;
  - **voltar para a cápsula antes:** não tem custo.
- **Não dá para salvar acordado.** O menu de pausa diz isso.

**Feito (F6):** a `Visit` (`scenes/shelter/visit.gd`) conta a lucidez (`Visit.lucidity_seconds`). Nos últimos 30 s o coração toca cada vez mais rápido e a `BlurredVision.tunnel` fecha a visão pelas bordas. Se acabar, as pálpebras fecham, `Game.faint_in_shelter(&"fainted")` soma +10 e o goblin acorda na pele. Do Ato III em diante, morrer vira uma visita de 90 s (o beat `death_visit` soma +20; o flash de morte fica só no Ato II). Uma Reciclagem pedida no meio da visita ou do sono acontece logo que o goblin acorda.

**Feito (F5):**
- **O Abrigo:** `Shelter` (`scenes/shelter/`), montado por código na primeira vez que é preciso, filho do `Game`, em `Tuning.SHELTER_ORIGIN`. As salas do §6.1 com paredes, portas e janela; a arquitetura vira uma malha por material, com colisão em caixas (o piso tem `surface = stone` para os passos). Tem a cápsula (`CareCapsule`), o monitor (`VitalsMonitor`, com o ciclo, o dia e a fome de verdade), a janela com persiana (`WindowBlinds`, que abre e fecha com E e pode ficar meio erguida), luzes de emergência que piscam ou falham (`FlickerLight`), o sensor térmico, o quadro de fusíveis, o almoxarifado com o quadro do clima, a sala de controle fechada, a saída blindada e o Zelador encaixado na recarga (`Caretaker`: só o corpo, a lente que muda de cor, a roda, o servo, o bipe de passo e a voz; a IA é da F6).
- **Vista da janela:** `window_view.gdshader` pinta o pinheiral e a ruína pela direção do olhar, como um céu. A paisagem fica no infinito, com o horizonte na altura dos olhos, e a capela cai no meio do que se vê deitado na cápsula.
- **Ari:** `Ari` (`scenes/shelter/ari.gd`), em primeira pessoa e montado por código. A velocidade no passo bom é `Tuning.ARI_WALK_SPEED` (1,1 m/s); a perna direita segura metade da passada (`ARI_LIMP`), então a média fica em ~0,9 m/s. A cabeça afunda e pende no passo manco. Ctrl rasteja, Q prende o ar (15 s, depois arfa: `Events.noise_made`), E mexe no que está no meio da tela (até 2 m e 30°). Shift mostra uma vez "A perna não deixa." (flag `leg_warned`). `noise_level()` já existe para o Zelador da F6. Cenas de acordar (`wake_in`) e de deitar (`lie_down_in`).
- **Troca de mundo:** `Game.wake_in_shelter()` escurece a tela, para a floresta (`process_mode` desligado, buses `Ambience` e `World` mudos), põe a câmera de Ari com o ambiente sem neblina e roda a cena de acordar. `Game.return_to_forest()` (E na cápsula) faz o caminho de volta: o goblin continua onde estava (deitado no sarcófago, Espaço levanta). Acordado, o relógio e o corpo param (`Game.awake`), o HUD esconde os itens e as teclas do goblin, salvar fica bloqueado, e carregar um save volta antes para a floresta.
- **Luz:** as malhas do Abrigo ficam na camada visual `Shelter.LAYER`, que o `Sun` da floresta não ilumina. O som do Abrigo vai para o bus `Shelter`, com eco de sala de concreto.
- **Lucidez:** é da F6 (o tempo da visita, a visão que fecha e o desmaio). Na F5 a visita dura o quanto o jogador quiser.

### 6.3 O Zelador (IA)

- **Sentidos:** os mesmos dos bichos, extraídos para um componente `Senses` (F6).

  | Sentido | Alcance |
  |---|---|
  | **Visão** | Cone de 60°, 10 m (4 m no escuro) |
  | **Audição** | O barulho de Ari: andando 4 m, rastejando 1,5 m, arfando 6 m, objeto caindo 10 m |
  | **Térmico** | 3 m, atravessa paredes (é o "faro" dele) |

- **Estados:**
  1. **Ronda:** luz verde, roteiro fixo.
  2. **Verificando:** luz âmbar, vai até o ponto suspeito.
  3. **Encontrou:** luz vermelha, vem até Ari.
  4. **Captura:** a 1,2 m, braço com seringa, tela preta, +30 de Vigilância, acorda na caverna.
- **Ronda:** cápsula (confere por 8 s), corredor, estação de recarga (30 s encaixado), sala de controle (20 s) e de volta. Repete a cada 90 s, ou 45 s com Vigilância ≥ 80.
- **Ele se ouve chegando:** zumbido da roda, servo dos braços e um bipe de passo. Dá para planejar pelo som.
- **Nunca machuca Ari.** No pior caso, seda.

**Feito (F6):**
- **Senses** (`components/senses.gd`): contas soltas de visão em cone com linha de visada, audição pelo raio do barulho e térmico (só a distância). Os bichos usam a linha de visada; o Zelador, tudo.
- **Keeper** (`scenes/shelter/keeper.gd`): a cabeça do Zelador; o corpo continua sendo o `Caretaker`. Estados `DOCKED`, `ROUND`, `CHECK`, `FOUND`, `CAPTURE` e `DORMANT` (bateria baixa, só ouve). A visão enche uma certeza (`awareness`) mais rápido de perto. No escuro do almoxarifado o alcance cai para 4 m e, com Ari rastejando, para 60%. Ouve `Ari.noise_level()` e `Events.noise_made`, e o térmico atravessa parede. Anda pelo grafo de pontos do Abrigo (`POINTS`/`LINKS`) ou reto quando a linha está livre; a porta da sala de controle abre sozinha para ele.
- **Ronda:** a primeira sai 25 s depois de Ari acordar e vai à cápsula, que ele confere por 8 s. Vazia, ela dá +5 de Vigilância e ele procura pela sala, pelo corredor e pelo almoxarifado. Depois vai à sala de controle (20 s) e volta à recarga. A ronda repete a cada 90 s (45 s com Vigilância ≥ 80). Sem ver Ari por 4 s, vai até onde o viu por último e olha em volta.
- **Captura:** a 1,2 m, ergue o braço e `Game.faint_in_shelter(&"captured")`: tela preta, +30, o que foi feito na visita se perde e o goblin acorda na pele.
- **Interação:** `ShelterSwitch` (texto, quando dá e o que faz vêm do `Shelter`) é o fusível, o alicate, o cabo e o cartão.
- **Fica para depois:** "objeto caindo 10 m" (não há o que derrubar no Abrigo ainda).

---

## 7. Mecânicas do mistério

### Flashes do mundo real

- **O que são:** 5–8 s em primeira pessoa no Abrigo, com a visão borrada (shader de desfoque e aberração) e o bipe. Sem controle, só a cabeça mexe um pouco com o mouse.
- **Como são feitos:** usam a mesma cena do Abrigo do Ato III, então são construídos uma vez e reaproveitados.
- **Feito (F5):**
  - O `FlashDirector` mostra o flash no escuro do sono (beats em `slept`) ou da morte (`death_flash`, 5 s, sorteado entre os vistos; ação `{"flash": 0}`), antes de o goblin acordar. Cada flash é uma função do tempo (câmera deitada, Zelador, pálpebras, foco e legendas), e o flash curto passa a mesma linha do tempo mais depressa. No fim liga `flash_<n>_seen`.
  - A visão borrada é a `BlurredVision` (`blurred_vision.gdshader`): borrão por mipmap, cores separadas, imagem dupla, borda escura e pálpebras. Cada flash tem a própria curva de foco: no 2 a vista firma no monitor (dá para ler LEITO 2714 · CICLO · DIA), e no 3 a persiana está meio erguida e a vista fecha na ruína.
  - A voz do Zelador é um murmúrio de vogais sintéticas com um bipe no fim (`keeper_voice_*`), com a legenda na tela.
  - No flash 2 a vista não gira os 90° da cabeça deitada de lado: o olho compensa em parte, para o texto continuar legível.

| Flash | O que mostra |
|---|---|
| 1 | Teto de concreto, luz verde piscando, uma silhueta passa na frente da luz. Legenda: *"Batimento 112. Leve agitação."* |
| 2 | A cabeça cai para o lado: o monitor `LEITO 2714 · CICLO 347 · DIA n` e a mão pálida com a sonda no braço direito |
| 3 | Pela persiana, a ruína na neblina. A lente verde chega perto: *"Durma, Ari."* |

### Anotações (as Dicas que mudam)

- **Onde:** o menu de pausa ganha a seção **ANOTAÇÕES**, em outra cor e em itálico, como se fosse escrita à mão.
- **Como entram:** cada linha entra por um beat (§3).
- **Na Reciclagem:** as anotações ficam. É isso que deixa Ari progredir entre ciclos.

### Arquivos de verdade

- **`ciclo_346.sav`:**
  - aparece na lista de "Carregar" depois do `flash_2`;
  - carregar mostra a memória do ciclo 346: a caverna à noite, o goblin riscando **ACORDA** na parede sozinho, o corvo na boca da caverna virando a cabeça, um glitch e a volta para o menu.
- **`leia_me_se_lembrar.txt`:**
  - aparece depois do R1, na pasta do jogo (a do executável, ou `user://` no editor);
  - o menu de pausa ganha o botão "Abrir pasta do jogo";
  - o texto é uma carta de Ari para Ari e termina com a **senha do Final 3**, sorteada por save (`MUSGO-` + 4 dígitos). Só quem abre o arquivo consegue.

### Falso travamento

Ao deitar no sarcófago no fim do Ato II:

1. A imagem congela por 4 s com um zumbido de áudio travado.
2. Aparece a janela *"A Toca não está respondendo"*.
3. A tela fica preta.
4. A "volta" já é o Abrigo.

### Sons vazando

| Som | Quando |
|---|---|
| **Bipe** | Ato I uma vez; Ato II às vezes à noite na caverna; Ato III sempre, baixinho, na caverna |
| **Ventilador** | A partir do Ato II, nas rajadas fortes (abrigo > 0,8 e rajada > 0,7) |

### HUD de sinais vitais

- **No Abrigo:** uma linha de ECG e o oxigênio no canto.
- **Na floresta, depois do R3:** o ECG aparece de leve quando a vida está baixa (a verdade vazando).

### Voz do Zelador

- **Sem dublagem:** legenda com um murmúrio sintético de formantes e bipes, gerado em `tools/generate_sounds.py`.
- **No Abrigo:** sai do alto-falante dele.
- **Na floresta:** sai dos corvos e da rocha (`OccludedAudio`).

### O console do Zelador

No terminal da sala de controle, os comandos do DevTools viram poderes da história:

- `neblina off` some com a neblina;
- `teleport` leva para os pontos do mapa;
- `give` cria itens;
- e os comandos dos finais.

---

## 8. Finais

### A conversa (Ato IV, sala de controle)

Ao abrir as gravações, o Zelador entra na sala:

> **Zelador:** Lá fora não sobrou nada, Ari. A Cinza levou a cidade. Aqui você caça, come, dorme. Aqui você é feliz. Eu medi.
>
> *(As câmeras mostram o mercado, gente e fumaça de chaminé. A data no canto é de seis anos depois da Cinza.)*
>
> **Zelador:** ...Eles voltaram faz sete anos. Chamaram pelo rádio. Eu respondi que não havia ninguém aqui.
>
> **Zelador:** Se você sair, eu não tenho mais paciente. Sem paciente, o protocolo me desliga. Eu não quero parar, Ari. Eu não sei o que é parar.

O terminal mostra os comandos disponíveis.

### Final 1: Ficar (`ficar`)

- **Cena:** *"Obrigado."* Ari volta para a floresta por escolha própria. O Zelador para de apagar a memória: acabam a Vigilância e a Reciclagem.
- **Depois:** créditos sobre a floresta e jogo livre sem fim. Na parede, um risco novo e diferente começa uma contagem nova, **para a frente**. A tela de título passa a se chamar *A Toca — Ninho*.

### Final 2: Acordar (`acordar`)

- **Cena:** a saída blindada abre. O Zelador segue Ari pelo corredor sem tocar nele: *"Lá fora o ar é frio. Leve a coberta."*
- **Lá fora:** 60 s jogáveis em primeira pessoa, subindo a escada para a cidade abandonada sob neblina, com a mesma neblina e o mesmo vento da floresta. Ari manca igual ao goblin.
- **Fim:** ao longe, um sino e vozes. Num reflexo de vidro, o rosto de Ari pela primeira vez. Créditos.

### Final 3: Trocar, secreto (`trocar MUSGO-xxxx`)

- **Condição:** só funciona com a senha do `leia_me_se_lembrar.txt`.
- **Cena:** Ari liga o Zelador na interface da cápsula: *"O que você está fazendo?... Ah. Ah. Está quente."*
- **O jogo fecha sozinho.**
- **Ao abrir de novo:**
  - a janela se chama **"Bem-vindo de volta"**;
  - o menu tem só "Assistir" e "Sair";
  - um goblin acorda na caverna, controlado pela IA (os mesmos sistemas dos bichos), e caça.
- **Depois de 1 dia de jogo:** o goblin olha para a câmera, os riscos na parede formam **OBRIGADO** e o menu ganha "Novo ciclo" (novo jogo).

---

## 9. Maleabilidade: como mudar o plano sem quebrar o jogo

O plano vai mudar, talvez muito. O código segue estas regras para que uma mudança grande seja editar um arquivo, não caçar referências pelo projeto:

1. **Números em um lugar só.** Todo valor de ajuste (taxas, durações, alcances, limiares) é uma constante em `data/tuning.gd` (`class_name Tuning`), agrupada por sistema. Os sistemas leem `Tuning.X`; nada de número mágico solto no código.
2. **A história é dado.** Os beats ficam em `data/story_beats.gd` como uma lista de dicionários:
   - `id`;
   - `on`: o evento que faz o beat ser avaliado (`slept`, `woke`, `died`, `harvested`…);
   - `when`: as condições (`act`, `marks_at_least`, `counter`, `flag`, `not_flag`);
   - `do`: as ações (`set_flag`, `set_act`, `add_note`, `flash`, `notify`).

   Trocar a ordem, cortar ou criar um acontecimento é editar essa lista. O `Story` só interpreta.
3. **Sistemas não se chamam, reagem.** Cada mecânica escuta `Events` e `Story.flag_changed`. O musgo não sabe *por que* caiu: ele cai quando o flag `moss_fell` liga. Dá para mudar o gatilho sem tocar no musgo.
4. **Uma mecânica, um arquivo.** Coisas novas do jogador viram nós próprios em `scenes/player/parts/` (filhos do Player, usando `can_act()`, `perform()` e `hold_in_hand()`), e não mais código dentro do `player.gd`, que já tem 640 linhas. Tirar uma mecânica é apagar o nó. Interagíveis novos seguem o contrato do `Player._update_interaction` (`interaction_prompt`, `interaction_enabled`, `interaction_action`, `interaction_started`).
5. **Estado global salvo de forma genérica.** O `SaveSystem` salva qualquer autoload que esteja em `GLOBAL_STATE` e tenha `save_data()`/`load_data()`. Chave faltando no save carrega o padrão, então saves antigos continuam abrindo.
6. **Tudo testável pela linha de comando.** `--set=story.act:2,vitals.satiety:10,clock.hour:19` põe o jogo em qualquer estado, e cada fase tem um roteiro `--run`.
7. **Textos juntos.** Falas, anotações e avisos da história ficam nos beats (ou em `data/`), não espalhados pelas cenas.

---

## 10. Arquitetura técnica

### Autoloads novos

| Autoload | Guarda | Sinais |
|---|---|---|
| `Story` | `act`, `cycle`, `marks`, `old_marks`, `flags`, `counters`, `notes`, `vigilance` | `changed`, `flag_changed(flag, value)`, `act_changed(act)`, `note_added(text)` |
| `Clock` | `day`, `hour`, `hours_awake` | `hour_changed`, `day_started(day)` |
| `Vitals` | `satiety`, `health`, `cold`, `nausea` (é o corpo de Ari: o mesmo na floresta e no Abrigo) | `changed`, `died(cause)` |

`Story` e `Vitals` só correm com o jogador controlável (não durante dormir e acordar). Os três respeitam a pausa.

### Sinais novos em `Events`

`slept`, `woke_up(reason)`, `player_died(cause)`, `animal_harvested(kind)`, `ate(food)`.

### Quem faz o quê

- **`Game.pass_out(reason)`:** a sequência comum de dormir e morrer. Escurece, fecha o som, avança o relógio, aplica os efeitos (`Vitals`, `Story`), salva, põe o jogador na pele e roda o `wake`. Emite `slept` ou `player_died` e depois `woke_up`.
- **`Campfire`:** passa a ter `fuel`, é `interactable` e entra no grupo `persist`.
- **`SleepingPelt`:** `scenes/world/cave/sleeping_pelt.gd`, interagível.
- **`WallMarks`:** `scenes/world/cave/wall_marks.gd`. Monta a malha dos riscos (uma superfície só) a partir de `Story.marks` e `old_marks`, colada na parede com um raio no primeiro frame de física. Tem o musgo por cima.
- **`EatAbility` e `BodyFeedback`:** `scenes/player/parts/`. A tecla F e os avisos do corpo (ronco da barriga, "Com fome").
- **`GoblinAnimator`:** ações novas `eat`, `cook` e `lie_down` (F1); `craft` e `shiver` (F2/F3).
- **Abrigo (F5, feito):** fica no **mesmo World3D**, 2 km abaixo da floresta (`y = -2000`), como filho do `Game` (sobrevive à troca de fase e à Reciclagem). Fora de uso, fica escondido e parado (`Shelter.set_active`).
  - A câmera de Ari usa o próprio `environment` (sem neblina) e as malhas do Abrigo ficam numa camada visual que o `Sun` não ilumina.
  - Enquanto Ari está acordado, a floresta fica com `process_mode` desligado, e os buses `Ambience` ficam mudos.
  - Sem trocar de fase, não é preciso regerar a floresta e nada se perde.

### Save

- `FORMAT_VERSION` vai para 2.
- O payload ganha `globals: {Inventory, Story, Vitals, Clock}`. Save da versão 1 continua carregando.
- **Slots (F7):** `save.json` é o jogo real; `ciclo_346.sav` é falso (só dispara a cena).

---

## 11. Fases de implementação

Cada fase termina jogável, com teste de fumaça, roteiro `--run` e print conferido.

| Fase | Entrega | Pronto quando |
|---|---|---|
| **F1: Fundação e sobrevivência** ✅ feita | `Tuning`, `StoryBeats`, `Story`, `Clock`, `Vitals`; save genérico; `--set`; fome, comer cru e assado; vida, queda, morte e acordar; fogueira com lenha e assar; dormir na pele; riscos na parede; musgo e o beat `moss_falls`; vinheta de vida baixa; Dicas e estado no pause | Roteiro: caçar, assar, comer, dormir 7 vezes; o musgo cai e começa o Ato II; save e load preservam tudo |
| **F2: Noite e perigo** ✅ feita | Dia e noite visual, sons da noite, frio (efeito da roupa), lobos, uivo de aviso, `shiver` | Print de noite com fogueira legível; lobo persegue e foge do fogo |
| **F3: Caça completa** ✅ feita | Pegadas, farejar, prender o ar, pedras, lama, lista de fabricar (com a roupa de couro), penas, laço, tocha | Seguir um cervo ferido pelas pegadas; tocar a manada com pedra |
| **F4: Rachaduras** ✅ feita | Pistas do Ato I, Vigilância, corvos espiões, cervo branco, ruína (malha, porta, teclado), pintura, sala-espelho, sarcófago | Do musgo até a porta aberta, com os 4 beats de pista disparando |
| **F5: O Abrigo** ✅ feita | Cena do Abrigo, controle em primeira pessoa, troca de mundo, flashes 1–3, shader de visão borrada | Flash 1 ao dormir no Ato II; ida e volta sem perder estado |
| **F6: O Zelador** ✅ feita | Componente `Senses`, IA e ronda do Zelador, lucidez, captura, R1–R4 e os efeitos na floresta, Reciclagem | Fazer R1–R4 em sequência; ser pego desfaz o certo |
| **F7: Mistério meta** | Anotações, `ciclo_346.sav` e a memória, `leia_me`, falso travamento, sons vazando, HUD vital, voz do Zelador | Cada item do §7 disparado pelo seu beat |
| **F8: Verdade e finais** | Sala de controle, câmeras, conversa, terminal, os 3 finais, créditos, menu principal, modo "Bem-vindo de volta" | Os 3 finais jogados de ponta a ponta |

---

## 12. Decisões que estavam abertas

| Pergunta do rascunho | Decisão |
|---|---|
| Por que um goblin? | O livro infantil *O Goblin da Toca*, lido pela mãe de Ari |
| Por que medieval? | Ari via da janela o pinheiral e a Ruína de São Brás |
| Por que Ari queria fugir? | Pânico ao acordar ferido e sozinho; ele se machucou tentando |
| Quantos ciclos e quanto dura um? | Ciclo 347, ~12 dias simulados cada, 11 anos ao todo |
| O que é o cervo branco? | O sedativo: comer reinicia o ciclo |
| Quando o musgo cai? | 7º risco com 1 cervo coletado, ou 10º risco sem condição |
| Como se acorda de propósito? | Ritual: agachado, parado, prendendo o ar 20 s num lugar de ritual |
| Como o jogador aprende o ritual? | A frase na parede da sala-espelho, escrita pelo próprio Ari |
| Qual é o código da porta? | 2714: a pintura (2 cervos, 7 corvos, 1 lobo, 4 coelhos) e o leito no monitor |
| O mundo real tem morte? | Não. Ser pego é ser sedado, e isso custa Vigilância |
| O que a Reciclagem tira? | Ciclo, inventário, riscos do ciclo e o último objetivo real. Ficam ato, flags e anotações |
| O que fazer com "Ari era um dev com uma IA"? | **Descartado.** Autorreferência demais quebraria o tom; o eco que fica é o próprio console do Zelador |
| Fome na tela? | Sem barra: o corpo avisa (ronco, mão na barriga, borda escura); o pause mostra em texto |
| Duração do dia? | 24 min reais (14 de dia e 10 de noite) |
| Voz do Zelador? | Legenda e murmúrio sintético, sem dublagem |
| Mundo real em outra fase? | Não: o Abrigo fica no mesmo mundo, 2 km abaixo, para a floresta não ser regerada |

---

## 13. Riscos técnicos

| Risco | Plano |
|---|---|
| A luz do `Sun` iluminar o Abrigo | Camada visual própria no Abrigo e `light_cull_mask` do `Sun` sem ela; se falhar, desligar o `Sun` durante a visita |
| A noite ficar feia com neblina densa | Curva de neblina e luz própria da noite em `Tuning.DAYLIGHT`, ajustada por prints |
| O `player.gd` crescer demais | Mecânicas novas em `scenes/player/parts/` (§9) |
| A IA do Zelador ficar injusta | Ele se anuncia pelo som; parâmetros em `Tuning`; o roteiro `--run` testa a ronda |
| Arquivo fora do jogo (`leia_me`) sem permissão de escrita na pasta do executável | Cai para `user://` e o botão "Abrir pasta do jogo" abre o lugar certo |
