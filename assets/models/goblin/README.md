# Goblin do jogador

`goblin.glb` é o asset usado pelo jogador. O polimento mantém a orientação +Z no Godot, os nomes dos ossos do kit e os sockets de equipamentos. As animações `parado` e `andando` continuam no arquivo, mas o jogo não as usa: o corpo é animado por código (`scenes/player/goblin_animator.gd`).

A fonte editável atual é **`source/goblin.blend`**. `goblin_blueprint.json` registra a base original do kit; reconstruí-lo com `export_game` descarta o polimento.

## Alterações do modelo

- Corpo contínuo, incluindo pescoço, cabeça, orelhas, braços, mãos, pernas e pés.
- Volumes de ombro, braço, cotovelo, antebraço, coxa, joelho e panturrilha; transições de peso no ombro, pescoço e quadril.
- Mandíbula, maçãs do rosto, ponte nasal, pálpebras, pupilas, narinas, presas e interior das orelhas.
- Dedos e polegares, pés com solas planas e unhas discretas.
- Trapo ajustado ao corpo, cavas livres, gola, espessura, remendo, cinto, fivela e bolsa presa à cintura.
- Sockets das mãos reposicionados no centro das palmas.

### Polimento 2

- **Rig articulado:** `canela_*`, `pe_*`, `antebraco_*` e `mao_*` foram acrescentados aos ossos do kit, com pesos de pele que fazem a transição em poucos centímetros no joelho, no tornozelo, no cotovelo e no punho.
- **Orelhas:** a pele das orelhas passa a seguir os ossos `orelha_*`, para poderem balançar.
- **Sockets:** `.mao`, `.punho`, `.pe` e `.tornozelo` seguem o osso novo da parte correspondente.
- **Rosto:**
  - crânio mais longo atrás;
  - nariz adunco e fino, com a ponta acima da boca;
  - sobrancelha mais grossa;
  - pálpebra superior pesada;
  - lábios, queixo e boca com os cantos caídos;
  - orelha em concha, com um corte na borda e a ponta levemente caída.
- **Compatibilidade com o Blender 5:** o gerador cria o nó Principled quando o material novo vem sem ele.

### Polimento 3

- **Coluna articulada:** `peito` (peito e costas de cima, carrega os braços) e `pescoco` (entre peito e cabeça) foram acrescentados ao `tronco`, que fica com a lombar. Os pesos fazem a transição em poucos centímetros, e o socket da aljava passou para o peito.
- **Pele lisa:** o corpo, os olhos e os dentes têm sombreamento suave; com as facetas, cada borda de polígono aparecia como uma linha na pele. Trapo e couro continuam facetados, para marcar as dobras.

## Fonte e exportação

A forma recomendada de mudar o modelo é editar `source/polish_goblin.py` e rodar, na raiz do projeto:

```powershell
$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
& $blender --background --python assets\models\goblin\source\polish_goblin.py
& $blender --background --python assets\models\goblin\source\export_goblin.py
```

`polish_goblin.py` reconstrói `source/goblin.blend` a partir de `source/goblin_before_polish.blend`, substituindo a fonte polida. `export_goblin.py` valida a malha e os pesos e grava o GLB e os metadados.

Edições manuais em `goblin.blend` são perdidas na próxima execução do `polish_goblin.py`. Para elas, exporte só com `export_goblin.py`.

Os originais estão preservados em `source/goblin_before_polish.blend`, `source/goblin_before_polish.glb` e `source/goblin_blueprint_original.json`. A pasta `source/` tem `.gdignore` para excluir fontes, backups e imagens das importações e builds do jogo.

## Verificação

`source/validation.json` registra a validação de topologia, pesos e sockets. A versão atual tem 21.118 triângulos, 31 ossos e 0,977 m de altura. O corpo é um único componente fechado; não há bordas abertas, normais invertidas nem vértices sem peso.

A cena `source/inspect_goblin.tscn` instancia o Player real em três vistas, com `GoblinLook`, e verifica repouso, caminhada, mira com arco e soco. Essas poses saem do `GoblinAnimator`, avançado à mão. Rode-a pelo Godot com `--path . --scene res://assets/models/goblin/source/inspect_goblin.tscn`. Ela grava `source/godot_*.png`; com `--headless`, executa apenas a verificação de integração. As imagens devem ser inspecionadas após mudanças na geometria ou nos pesos.
