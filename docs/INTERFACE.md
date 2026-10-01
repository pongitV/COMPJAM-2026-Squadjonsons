# Sistema de Interface e Identidade Visual - HexCore

Este documento descreve o funcionamento do sistema de renderização de interface, o pipeline de skins, a moldura procedural 9-slice e a integração de sprites no **HexCore**.

[Voltar ao README](../README.md) | [Arquitetura do Projeto](ARQUITETURA.md) | [Balanceamento e Configurações](BALANCEAMENTO.md)

---

## 1. Resolução e Gerenciamento de Janela

O gerenciamento de tela é controlado programaticamente por `scripts/display.gd`:

- **Resolução Base:** 1280 × 720 pixels.
- **Modo de Escala:** `Window.CONTENT_SCALE_MODE_CANVAS_ITEMS` combinado com `Window.CONTENT_SCALE_ASPECT_EXPAND`. O jogo se expande proporcionalmente sem distorcer elementos ou introduzir barras pretas estáticas; monitores ultrawide ou telas mais altas exibem uma área útil de visão proporcionalmente maior.
- **Alternância de Janela:** Pressione <kbd>F11</kbd> ou <kbd>Alt</kbd> + <kbd>Enter</kbd> em qualquer momento para alternar entre tela cheia exclusiva e modo janela.

---

## 2. Componentes da Interface (HUD)

Gerenciado por `scripts/ui/hud.gd`:

- **Card de Células (Superior Esquerdo):** Exibe a contagem atual de hexágonos que compõem o corpo da nave.
- **Contador de Corrida (Superior Direito):** Cronômetro regressivo da partida (de 3:00 até 0:00). Aos 60 segundos restantes assume tonalidade amarela/dourada; nos 10 segundos finais pulsa em vermelho.
- **Barra de Chegada (`RaceBar` - Inferior Central):** Ocupa 60% da largura da tela no rodapé, exibindo o deslocamento da nave em direção à bandeira de término.
- **Barra de Vida do Chefe:** Surge no topo central durante o confronto final, monitorando a integridade somada de todas as seções ativas do MEGATRON.
- **Mira Hexagonal (`Reticle`):** Indicador visual com antecipação angular seguindo a posição do cursor do mouse.
- **Efeitos Dinâmicos:** Vinheta de dano na borda da tela com desvanecimento suave e mensagens de texto flutuantes para eventos importantes.

---

## 3. Moldura Hexagonal Responsiva (`HexFrame`)

Toda a identidade visual de painéis, botões, cards e chips utiliza a textura base `art/ui/hex_frame.png` através da classe `HexFrame`:

- **Lógica de 9-Slice:** Os cantos e extremidades em chevron permanecem intactos, enquanto as células hexagonais centrais se repetem nas direções horizontal e vertical. Isso garante que qualquer elemento se adapte a resoluções arbitrárias sem deformar os hexágonos da borda.
- **Coloração Dinâmica:** As molduras são recoloridas via código mantendo a luminância original da arte base, preservando o contraste e a legibilidade do texto.
- **Espessuras Pré-definidas:**
  - `THIN`: Utilizada em chips de teclas e indicadores pequenos.
  - `SMALL`: Utilizada em botões e barras de progresso.
  - `MEDIUM`: Utilizada em cards informativos do HUD.
  - `LARGE`: Utilizada em painéis modais (menus de pausa, manual e tela de fim de jogo).
- **Estados de Botões:** Roxo em repouso, ciano ao passar o cursor ou receber foco, e dourado ao ser pressionado.

---

## 4. Pipeline de Customização de Sprites (`UISkin`)

O sistema permite substituir qualquer elemento visual desenhado por código por um arquivo `.png` dedicado na pasta `art/ui/` sem alterar os scripts. Basta salvar a imagem com o identificador exato do slot:

| Slot | Elemento Correspondente | Método de Encaixe |
|---|---|---|
| `card`, `card_cells`, `card_countdown`, `card_race`, `card_boss`, `card_record` | Molduras dos cartões de métricas do HUD e recorde. | 9-slice |
| `panel`, `panel_pause`, `panel_manual`, `panel_game_over`, `panel_victory`, `panel_tutorial`, `panel_formations` | Painéis e janelas modais. | 9-slice |
| `button_normal`, `button_hover`, `button_pressed`, `button_focus` | Estados interativos de botões e abas. | 9-slice |
| `key`, `separator` | Moldura dos chips de teclado e linhas divisórias. | 9-slice / esticamento |
| `icon_cells`, `icon_countdown`, `icon_record`, `icon_pause`, `icon_manual` | Ícones internos de títulos e métricas. | Proporcional quadrado |
| `race_marker`, `race_flag` | Marcador da nave e bandeira de término na barra de chegada. | Proporcional |
| `reticle`, `key_arrow` | Mira do cursor e setas direcionais dos chips. | Proporcional |
| `key_mouse_left`, `key_mouse_right`, `key_mouse_wheel` | Ícones indicadores de botões e roda do mouse. | Proporcional |
| `title_logo` | Logo principal (substitui o texto HEXCORE no menu). | Tamanho real |
| `damage_vignette`, `backdrop_*` | Vinheta de impacto de dano e fundos escurecidos de tela. | Tela cheia |

### Dimensões de Referência para Texturas Customizadas

Conforme documentado em `art/ui/LEIA-ME.txt`:
- Ícones (`icon_*`): 30 × 30 pixels (ou 60 × 60 px para alta definição).
- Marcador da Nave (`race_marker`): 22 × 22 pixels.
- Bandeira de Chegada (`race_flag`): 26 × 30 pixels.
- Ícones de Menu (`icon_pause`, `icon_manual`): 28 × 28 pixels.
- Mira Hexagonal (`reticle`): 42 × 42 pixels.
- Ícones de Mouse (`key_mouse_*`): 13 × 18 pixels (manual) e 11 × 15 pixels (tutorial).

---

## 5. Tipografia

- **Fonte Principal (Hexagon):** Tipografia geométrica utilizada em títulos, botões e valores numéricos do HUD. Por não possuir caracteres acentuados nativos, o método auxiliar `UIStyle.plain()` remove acentos dinamicamente de strings em tempo de execução.
- **Fonte Secundária / Reserva (Orbitron):** Utilizada como fonte de fallback para pontuações, caracteres especiais e numeração refinada.
