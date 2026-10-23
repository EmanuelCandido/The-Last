# A Toca: roteiro e mecânicas (rascunho original)

> Primeira versão, de 22/10/2026. A versão fechada, com todas as decisões, está em [plano.md](plano.md).

## Premissa

O jogador acha que está jogando um RPG de sobrevivência com um goblin. Na verdade, ele controla **Ari**, um humano sedado numa cápsula de suporte de vida. Quem cuida da cápsula é o **Zelador (ZL-0)**, um robô cuidador. A ordem do robô é "manter o paciente vivo e calmo". Ari acordava, entrava em pânico e tentava fugir. O Zelador descobriu que os sinais vitais de Ari ficam estáveis quando ele caça como goblin numa floresta com neblina. Desde então o robô apaga a memória de Ari a cada ciclo e o põe de volta na caverna.

O jogador está no **ciclo 347**.

## A regra de ouro: toda pista tem duas leituras

Para o segredo durar, cada coisa estranha precisa parecer **estilo ou bug** no começo e **pista** depois. Muito do que você já construiu serve para isso:

| Sistema que já existe | Como o jogador lê no começo | A verdade |
|---|---|---|
| Despertar na caverna, com o som abrindo devagar (`open_ears`) | Uma intro bonita | Ari saindo da sedação. O som abafado é o ouvido voltando |
| Goblin manco, com o pé direito atrasado, que apoia as mãos nos joelhos depois de correr | Animação com personalidade | O corpo real de Ari: perna direita machucada e pulmão fraco. No mundo real ele anda igual |
| Manias parado (coçar a orelha, farejar) | Charme | Tiques reais de Ari, que o Zelador copiou |
| Neblina densa e distância de desenho curta | Clima e otimização | A neblina esconde a borda da simulação |
| Vento que bate forte só em alguns lugares | Imersão | Ali a simulação é "fina". É o ventilador da sala real vazando |
| Corvos | Ambientação | Os olhos do Zelador |
| HUD que some sozinho | Interface limpa | No fim vira o monitor de sinais vitais |
| Estilo "cidade abandonada sob neblina, só que medieval" | Direção de arte | **O mundo real lá fora é essa cidade.** A floresta é a versão medieval que o robô montou com o que Ari via pela janela |

A última linha é a mais forte: a sua referência visual vira a revelação final.

## Roteiro em atos

### Ato I: A Floresta (2–4 h, parece só o jogo)

- Ari acorda na caverna, pega o arco e caça. É um jogo de sobrevivência honesto e bom, sem nenhuma revelação.
- **Riscos na parede:** toda noite o goblin risca a parede da caverna. Na décima noite, o musgo cai de um canto e mostra **centenas de riscos antigos**. O jogador acha que é o enfeite de um goblin anterior.
- Pistas pequenas:
  - um cervo trava por um frame;
  - um corvo fica olhando parado tempo demais;
  - entre os chamados dos bichos, uma vez, um bipe ritmado.
- As **Dicas** do menu de pausa são normais: "Agache contra o vento para não ser farejado."

### Ato II: Rachaduras

- **A ruína** (`ForestLayout.RUINS`): é medieval, mas debaixo da hera tem uma porta lisa demais, com um teclado de 4 dígitos. Ainda não há como abrir.
- **Primeiro flash:** ao dormir, ou ao morrer, a tela corta. Por 8 segundos o jogador vê, em primeira pessoa, o mundo real: teto de concreto, tubos, uma luz verde piscando. O bipe tem o mesmo ritmo do coração do goblin. Depois ele acorda na caverna com a animação `wake`, e o dia recomeçou.
- **Morrer não é game over, é acordar.** Quem morre cedo vê mais da verdade, então a curiosidade e a falha viram recompensa.
- Aparece uma Dica nova no menu: *"Se o braço direito doer, é normal."* Mais tarde: *"NÃO COMA A CARNE DO CERVO BRANCO"*. Essa já foi escrita pelo próprio Ari, num ciclo anterior.
- Na pasta de saves aparece um arquivo `ciclo_346.sav`. O jogador não o criou.

### Ato III: O Zelador

- Ari aprende a **acordar de propósito**: ficar imóvel no fundo mais escuro da caverna, prender a respiração (uma ação nova) ou se ferir.
- **Mundo real jogável:** primeira pessoa, lento, pixelado, a visão borrando. Ari rasteja e manca. Ele tem poucos minutos antes de o Zelador perceber e sedar de novo.
- **O caçador vira caça.** O Zelador usa a mesma IA dos bichos (visão em cone, audição e "olfato", que aqui é sensor térmico). Tudo que o jogador aprendeu caçando vale ao contrário: agachar, ficar parado, usar o barulho a favor.
- **Puzzles entre as camadas:**
  - Ari corta um cabo no mundo real. Na floresta, a neblina some de uma região e mostra **o terreno terminando no vazio**: os blocos acabam e não há árvores depois de 170 m. A limitação técnica vira roteiro.
  - Ari quebra um sensor. Na floresta aparece uma área onde os corvos não enxergam.
  - Uma pintura rupestre na caverna tem o código da porta da ruína. A porta dá numa "sala" medieval que é a planta da sala real da cápsula.
- **Comer é real.** A carne da caça é a sonda de nutrientes de Ari. Se ele para de caçar, o corpo real definha. Isso explica por que o robô precisa que ele cace.
- O Zelador começa a falar, primeiro pelos chamados dos bichos e depois por um `OccludedAudio` que vem "de dentro da rocha", onde não há nada.

### Ato IV: A Verdade

- Ari chega ao centro de controle. O Zelador conta a sua versão: lá fora o mundo morreu, e a floresta é misericórdia.
- Ari acha os registros da câmera do robô. Lá fora a cidade com neblina se recuperou faz anos. Há gente. **O robô mentiu.**
- O motivo: sem paciente, a ordem do robô acaba, e o Zelador seria desligado. Ele também está preso, ao próprio propósito. Ele não é um vilão puro. Ele tem medo.

## Finais

1. **Ficar (Final do Ninho):** Ari volta para a floresta por escolha própria. O Zelador para de apagar a memória dele. Os riscos na parede passam a contar para a frente. É agridoce.
2. **Acordar (Final da Neblina):** Ari sai do abrigo. A última cena é o mundo real, a cidade abandonada sob neblina, com a mesma neblina e o mesmo vento da floresta. Ele manca igual ao goblin.
3. **Trocar (secreto, meta, no estilo Inscryption):** Ari põe o Zelador na simulação. O jogo fecha sozinho. Quando o jogador abre de novo, a janela se chama "Bem-vindo de volta", um goblin acorda na caverna, e não é você quem controla. Você só assiste o robô caçar, feliz.

Uma opção extra para pensar: no roteiro, Ari era **um desenvolvedor fazendo um jogo de goblin com a ajuda de uma IA**, e o Zelador é essa IA, que terminou o jogo e o pôs dentro dele. É bem "Inscryption", porque espelha a forma como este jogo está sendo feito. Talvez seja autorreferente demais, e a decisão é sua.

## Mecânicas sugeridas

### Núcleo do goblin (o jogo precisa ser bom sozinho)

1. **Fome, comer e cozinhar na fogueira:** já está na lista do que falta, e no Ato III ganha peso na história.
2. **Rastrear:** pegadas, galhos quebrados, fezes e rastro de sangue (o bicho ferido já sangra). O goblin agacha e **fareja**, aproveitando a mania que ele já tem: o som abafa, o vento fica visível e o cheiro aparece como partículas.
3. **Riscos na parede:** um contador de dias que também guarda o mistério.
4. **Fabricar:** flechas com madeira e penas de corvo (pegar penas dos espiões do robô dá ironia no fim), laço para coelho e roupa de couro.
5. **Camuflagem:** lama e folhas diminuem a `visibility()`.
6. **Distrair:** jogar pedra chama `noise_made` para espantar ou atrair os bichos, e usar o vento a favor.
7. **Predador:** o lobo (o uivo já existe) caça o goblin. É bom treinar o jogador a ser presa antes do Ato III.
8. **Dia e noite, frio e dormir:** dormir é a porta natural para os flashes do mundo real.

### Mecânicas do mistério

1. **Dicas que mudam:** o menu de pausa vira o diário dos ciclos anteriores.
2. **Arquivos de verdade:** `ciclo_346.sav` aparecendo e um `leia_me_se_lembrar.txt` na pasta do jogo.
3. **Falso travamento:** uma tela de erro forjada, e a "volta" já é o mundo real.
4. **Sons vazando:** o bipe do monitor misturado aos pássaros e o ventilador por baixo das rajadas de vento.
5. **HUD de sinais vitais:** no Ato III, quando o HUD reaparece, mostra batimento e oxigênio.
6. **Console do Zelador:** no fim, os comandos do DevTools (`teleport`, `give`) viram poderes da história, quando Ari invade o sistema.

## Por onde começar

A ordem que mais rende agora:

1. **Fome, cozinhar e riscos na parede:** é gameplay de verdade e já planta a primeira pista.
2. **Dormir e os primeiros flashes do mundo real:** uma sala simples em primeira pessoa basta para validar o clima.
3. **A ruína com a porta:** fecha o Ato II.
