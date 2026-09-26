# COMPJAM-2026-Squadjonsons

**HexCore**: um jogo inspirado no Asteroids clássico, feito em Godot 4.5. Todo objeto é formado por células hexagonais.

## Como rodar
Abra a pasta no Godot 4.5 (Importar → `project.godot`) e aperte **F5**.

## Controles
| Ação | Tecla |
|---|---|
| Mover | WASD / setas |
| Arrastar pedaço de minério até a nave | Clique esquerdo (segurar e soltar onde o encaixe aparecer) |
| Girar o pedaço arrastado | Roda do mouse |
| Girar a nave para o mouse | Clique direito (segurar) |
| Pausar / info | ESC (ou P) |
| Tela cheia / janela | F11 (ou Alt+Enter) |
| Reiniciar (após game over) | R |

## Regras
- **Jogador**: começa com 1 célula, a *core* (branca com detalhes azuis), com um canhão comum. Só células com canhão atiram, **sozinhas**: cada canhão mira no asteroide mais próximo dele (com mira antecipada). As demais células são casco e protegem a core.
- **Asteroides**: nascem fora da tela com direção, velocidade e tamanho `n` (nº de células, no mínimo 3) aleatórios, e batem entre si (quicam e giram conforme o ponto de impacto). São destruídos após `ceil(n^(3/2))` de dano. O dano na nave é por contato: cada célula do asteroide que encosta na nave destrói a célula da nave que ela tocou; depois de destruir 2, ela some (se o asteroide se partir, as partes seguem como asteroides separados; partes com menos de 3 células viram poeira). Partes da nave que perderem a ligação com a core se soltam como um pedaço flutuante (com seus canhões) e podem ser encaixadas de novo. **O jogo só acaba quando a core é destruída.**
- **Asteroides armados**: alguns asteroides nascem com canhões (os mesmos da nave) e atiram nela; cada acerto destrói uma célula da nave ou de um pedaço de minério solto (o pedaço se parte se ficar desconectado). O cano brilha em vermelho logo antes do tiro. Conforme a barra de chegada avança, mais asteroides vêm armados, com canhões maiores e atirando mais rápido e com mais precisão (`config/enemies.tres`).
- **Minérios**: todo asteroide destruído pelos canhões se parte em **pedaços** conectados, no mesmo lugar em que estavam: os pequenos geralmente não se partem (4 células = 1 pedaço) e os grandes se partem em mais (16 células ≈ 3 pedaços). Antes, 20% das células viram poeira (sem partir o resto). Os canhões do asteroide são células como as outras: vão no pedaço em que caírem, então um triângulo pode cair inteiro, dividido ou sem algumas células. Os pedaços não grudam sozinhos: o jogador os pega com o **raio trator** (clique e arraste, dentro do alcance em volta da nave), gira com a roda do mouse (passos de 60°, o grid hexagonal) e solta quando o encaixe fantasma aparecer: todas as células precisam caber e ao menos uma encostar na nave. Minério verde vira casco; células de canhão viram canhões comuns. **A única forma de ganhar canhões é pegando os dos asteroides.**

### Canhões
O canhão comum é o bloco de montar dos outros: canhões comuns adjacentes em **triângulo** se fundem num único canhão maior que ocupa o triângulo todo (os maiores têm prioridade). O núcleo é um canhão comum que nunca se funde. Se uma célula de um canhão grande for destruída, ele se desfaz e as células que sobraram voltam a se fundir no maior triângulo que ainda formarem (ex.: um laser que perde uma ponta vira bomba + comuns). Canhões funcionam em qualquer lugar da nave.

| Canhão | Cor | Formação | Como funciona |
|---|---|---|---|
| Comum | Azul | 1 célula | Tiro único no asteroide mais próximo |
| Shotgun | Laranja | Triângulo de 3 comuns | Tiros em leque no asteroide mais próximo, alcance curto |
| Bomba | Roxo | Triângulo de 6 comuns | Míssil lento lançado no asteroide mais próximo, explode com dano em área |
| Laser | Vermelho | Triângulo de 10 comuns | Dispara quando um asteroide cruza sua linha: raio para fora da nave (do núcleo para o canhão) com dano contínuo; gire a nave (clique direito) para mirar |

## Estrutura
| Arquivo | Conteúdo |
|---|---|
| `scripts/hex.gd` | Matemática da grade hexagonal (lado plano em cima, coordenadas axiais) |
| `scripts/art.gd`, `art/` | Artes das células (flores de 19 hexágonos) e dos canhões, juntadas em atlas |
| `scripts/hex_body.gd` | Base de todo objeto feito de células: desenho, colisão e canhões (grupos e canos) |
| `scripts/cannon_groups.gd` | Fusão de canhões comuns em triângulos (shotgun, bomba, laser) |
| `scripts/player.gd` | Movimento, giro, canhões (mira automática), encaixe de pedaços e dano |
| `scripts/weapons.gd` | Tipos de canhão: cores e nomes |
| `scripts/cannon_config.gd`, `config/cannons.tres` | Parâmetros dos canhões (recarga, dano, alcance…), editáveis no Inspector |
| `scripts/asteroid.gd` | Geração aleatória, HP, dano na nave e batidas entre asteroides |
| `scripts/asteroid_config.gd`, `config/asteroids.tres` | Todos os parâmetros dos asteroides (spawn, tamanho, HP, velocidade, minério), editáveis no Inspector |
| `scripts/ore.gd` | Pedaço de minério solto (flutua até ser arrastado) |
| `scripts/tractor.gd` | Raio trator: pegar, arrastar, girar e encaixar pedaços no grid da nave |
| `scripts/bullets.gd` | Projéteis do canhão comum e da shotgun, em arrays compactos |
| `scripts/lasers.gd`, `scripts/missiles.gd` | Raio laser e mísseis da bomba |
| `scripts/enemy_config.gd`, `config/enemies.tres`, `scripts/enemy_shots.gd` | Asteroides armados: armamento, força conforme o progresso, drop e os tiros contra a nave |
| `main.tscn`, `scripts/ui/main_menu.gd` | Menu principal (cena inicial): jogar, manual, sair e recorde, com as artes flutuando no fundo |
| `game.tscn`, `scripts/game.gd` | Partida: spawn, colisões, câmera fixa com fundo rolando e estatísticas |
| `scripts/travel_config.gd`, `config/travel.tres` | Velocidade do fundo, efeitos de velocidade e tempo até a chegada |
| `scripts/starfield.gd`, `scripts/speed_fx.gd` | Fundo de estrelas (parallax, rastros, linhas de velocidade) e riscos/rastro na nave e nos asteroides |
| `scripts/save_data.gd` | Recorde salvo entre partidas |
| `scripts/input_actions.gd` | Teclas e botões das ações (pausa, girar, arrastar), definidos por código |
| `scripts/ui/ui_skin.gd`, `art/ui/` | Sprites próprios da interface: lista de slots (`SLOTS`) e troca placeholder → sprite |
| `scripts/ui/ui_sprite.gd` | `UISprite`: objeto de UI que desenha o sprite do slot ou, sem ele, o placeholder |
| `scripts/ui/ui_style.gd` | Paleta, fontes e estilos da interface; `plain()` tira acentos (a fonte Hexagon não tem) |
| `scripts/ui/hex_frame.gd`, `art/ui/hex_frame.png` | Moldura de hexágonos do HUD: 9-slice, variações de cor e espessura |
| `scripts/display.gd` | Tela cheia e escala aplicadas por código; F11 / Alt+Enter alternam tela cheia e janela |
| `scripts/ui/hud.gd` | HUD: cards animados, textos flutuantes, vinheta de dano, mira e game over |
| `scripts/ui/race_bar.gd` | Linha de chegada no rodapé (marcador da nave e bandeira) |
| `scripts/ui/stat_card.gd`, `cannon_card.gd`, `hex_icon.gd` | Cards do HUD (status e canhões) e ícone animado (placeholder hexagonal) |
| `scripts/ui/pause_menu.gd` | Menu de pausa (continuar, info, menu principal, sair) |
| `scripts/ui/manual.gd` | Manual (controles, regras, canhões) e painéis compartilhados pelos menus |

## Tela e moldura do HUD
O jogo abre em **tela cheia** e escala tudo (UI, sprites, mundo) a partir da resolução base 1280×720 (`canvas_items` + `expand`: telas mais largas ou mais altas mostram mais área, sem distorcer). Isso é aplicado por código em `scripts/display.gd` ao abrir o menu e a partida, então não depende do `project.godot` (que o editor pode sobrescrever).

Cards, painéis, botões, abas, chips de tecla e a linha de chegada usam a moldura `art/ui/hex_frame.png` (`HexFrame`):
- **Escala**: 9-slice. As pontas em chevron e os cantos ficam intactos, a fileira de hexágonos da borda se repete na horizontal e a coluna do meio da ponta se repete na vertical, então a moldura estica em qualquer largura e altura.
- **Cor**: segue o conteúdo (hexágonos em ciano, canhões em azul, tempo em cinza, recorde em dourado, manual em verde, game over em vermelho, pausa e barra de chegada no roxo original). A arte é recolorida trocando o matiz e escurecida até a luminância do roxo original, para o texto continuar legível.
- **Espessura**: `THIN` (chips), `SMALL` (botões e barra), `MEDIUM` (cards) e `LARGE` (painéis grandes).
- Botões: roxo parado, ciano com o mouse ou foco, dourado apertado.

Para trocar a moldura inteira, substitua `hex_frame.png` e ajuste `MARGINS` em `hex_frame.gd`.

## Sprites da interface
Para trocar uma peça específica pela sua arte, salve um PNG em `art/ui/` com o nome do slot (ex.: `art/ui/button_normal.png`); ele tem prioridade sobre a moldura de hexágonos e os placeholders. Não precisa mexer em código.

| Slots | O que são | Como é encaixado |
|---|---|---|
| `card`, `card_cells`, `card_time`, `card_cannons`, `card_record` | Molduras dos cards (`card` vale para os que não tiverem a sua) | 9-slice |
| `panel`, `panel_pause`, `panel_manual`, `panel_game_over` | Molduras dos painéis (`panel` vale para todos) | 9-slice |
| `button_normal`, `button_hover`, `button_pressed`, `button_focus` | Estados dos botões e abas (os que faltarem usam o estado mais próximo) | 9-slice |
| `key`, `separator` | Chip de tecla do manual e linha separadora | 9-slice / estica na largura |
| `icon_cells`, `icon_time`, `icon_record`, `icon_pause`, `icon_manual`, `icon_cannon_*` | Ícones dos cards e títulos (pulsam, não giram) | Cabe no tamanho do placeholder |
| `race_marker`, `race_flag` | Marcador da nave e bandeira de chegada na linha do rodapé | Cabe no tamanho do placeholder |
| `reticle`, `key_arrow` | Mira e seta das teclas | Cabe no tamanho do placeholder |
| `title_logo` | Logo do menu (substitui o texto HEXCORE) | Tamanho real |
| `damage_vignette`, `backdrop_menu`, `backdrop_pause`, `backdrop_game_over` | Borda de dano e fundos atrás dos painéis | Estica na tela |

A margem do 9-slice é 12 px (muda por slot em `UISkin.SLICE`). Tamanhos de referência em `art/ui/LEIA-ME.txt`. Para um novo elemento de UI trocável, adicione o slot em `UISkin.SLOTS` e estenda `UISprite` (ou use `UISkin.stylebox()` / `UISkin.replace()`).

## Parâmetros dos asteroides
Tudo sobre os asteroides fica em `config/asteroids.tres`: abra no Godot e edite no Inspector (os valores padrão e a explicação de cada um estão em `scripts/asteroid_config.gd`). Para ter presets (fácil, difícil…), duplique o `.tres` e arraste o novo no campo **Asteroid Config** do nó `Game` em `game.tscn`.

| Grupo | Parâmetros |
|---|---|
| Dificuldade com o tempo | multiplicador que começa em 1 e sobe X por minuto (padrão +10%/min, até 2,5x); escolha se ele aumenta HP, velocidade e/ou frequência de spawn |
| Spawn | atraso do primeiro, intervalo inicial/mínimo, quanto acelera por segundo, variação aleatória, **máximo de asteroides vivos**, distância de spawn/despawn, desvio da mira em direção à nave |
| Tamanho | mínimo, teto absoluto, máximo no início, crescimento por tempo e por canhão, `size_bias` (controla o **tamanho médio**: ≈ mín + (máx − mín) / (bias + 1)) |
| Vida e pontos | HP = ⌈multiplicador × células^expoente⌉, pontos por HP |
| Movimento | faixa de velocidade, multiplicador para pequenos/grandes, giro inicial e máximo, elasticidade das batidas, velocidade ao se partir |
| Dano na nave | quantas células da nave cada célula do asteroide destrói |
| Minério | fração perdida, em quantos pedaços se parte (tamanho até o qual não se parte, células por pedaço a mais, variação), velocidade dos pedaços, máximo na tela |

## Viagem (fundo e chegada)
A câmera fica parada e só o fundo rola, dando a impressão de que a nave avança para a direita; a nave se move livre, mas presa na tela. Para reforçar, os asteroides nascem de preferência à frente (direita) e são arrastados devagar para a esquerda. No rodapé, o marcador da nave anda até a bandeira de chegada e a alcança aos 5 min. Tudo isso fica em `config/travel.tres` (explicações em `scripts/travel_config.gd`), com presets pelo campo **Travel Config** do nó `Game`.

| Grupo | Parâmetros |
|---|---|
| Fundo | velocidade inicial, aumento por minuto e máxima, direção do avanço, parallax das estrelas distantes/próximas, quantidade de estrelas, rastro das estrelas, linhas de velocidade (quantidade, opacidade, velocidade) |
| Efeitos de velocidade | riscos atrás da nave e dos asteroides (quantidade, comprimento, opacidade), partículas de rastro da nave por segundo |
| Fluxo | arrasto dos asteroides para trás (padrão 45 px/s), chance de nascerem à frente (70%) e abertura desse arco (120°) |
| Chegada | tempo até a bandeira (padrão 300 s) |

## Parâmetros dos canhões
Ficam em `config/cannons.tres` (padrões e explicação em `scripts/cannon_config.gd`), com presets pelo campo **Cannon Config** do nó `Game`. Dano é medido em "tiros do canhão comum".

| Grupo | Parâmetros |
|---|---|
| Geral | multiplicador de dano e de cadência de todos os canhões |
| Comum | recarga, dano, alcance, velocidade do tiro |
| Shotgun | recarga, nº de projéteis, dano por projétil, alcance, abertura do leque, velocidade |
| Laser | recarga, duração do raio, dano por segundo, comprimento |
| Bomba | recarga, dano e raio da explosão, alcance, velocidade do míssil |

## Asteroides armados
Ficam em `config/enemies.tres` (explicações em `scripts/enemy_config.gd`), com presets pelo campo **Enemy Config** do nó `Game`. Quase tudo vai de um valor "início" a um valor "fim" conforme a barra de chegada avança. Os canhões inimigos usam os números de `cannons.tres` com os ajustes daqui.

| Grupo | Parâmetros |
|---|---|
| Armamento | chance de nascer armado, máximo de canhões por asteroide, folga de tamanho (o asteroide precisa ter as células do canhão + folga), fração máxima de células que podem ser canhão, chance relativa de cada canhão |
| Força | multiplicador de recarga, velocidade dos projéteis, erro de mira, alcance, espera antes do primeiro tiro, projéteis da shotgun, raio da bomba, tempo do laser para destruir uma célula |
Os demais parâmetros de balanceamento ficam como `const` no topo de cada script (ex.: `SIZE` em `hex.gd`, movimento da nave em `player.gd`).

## Créditos
- Fonte [Hexagon](https://fontstruct.com/fontstructions/show/1727445) por "twannieboy", sob a licença Creative Commons BY-NC-SA 3.0 (uso não comercial). Licença e leia-me em `fonts/Hexagon-*.txt`. Ela só tem letras sem acento, então os textos do jogo aparecem sem acentos.
- Fonte [Orbitron](https://fonts.google.com/specimen/Orbitron) (Matt McInerney), sob a SIL Open Font License, usada como reserva para números e pontuação. Licença em `fonts/Orbitron-OFL.txt`.
