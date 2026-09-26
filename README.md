# HexCore

**HexCore** (COMPJAM 2026, Squadjonsons): um jogo inspirado no Asteroids clássico, feito em Godot 4.7. Todo objeto é formado por células hexagonais.

## Como rodar
Abra a pasta no Godot 4.7 (Importar → `project.godot`) e aperte **F5**.

## Exportar (HexCore.exe)
O preset **Windows Desktop** (`export_presets.cfg`) exporta para `build/HexCore.exe` com o `.pck` **embutido no .exe** (`binary_format/embed_pck`): o jogo é um arquivo só e continua funcionando se o `.exe` for renomeado ou movido. Se aparecerem `libEGL.dll`/`libGLESv2.dll` ao lado (ANGLE, reserva do OpenGL), mantenha-as na mesma pasta do `.exe`. Antes da primeira exportação, instale os modelos em **Editor → Gerenciar Modelos de Exportação**. Depois: **Projeto → Exportar → Windows Desktop → Exportar Projeto**.

## Controles
| Ação | Tecla |
|---|---|
| Mover | WASD / setas |
| Arrastar pedaço de minério até a nave | Clique esquerdo (segurar e soltar onde o encaixe aparecer) |
| Puxar pedaço sozinho até a nave | Clique rápido nele (dentro do alcance do raio trator) |
| Girar o pedaço arrastado | Roda do mouse |
| Girar a nave para o mouse | R ou clique direito (segurar) |
| Pausar / info | ESC (ou P) |
| Tela cheia / janela | F11 (ou Alt+Enter) |
| Reiniciar (após game over) | R |

## Regras
- **Tutorial** (toda partida começa com ele; **ENTER** pula): primeiro vem só um meteoro de 4 hexágonos, que o núcleo destrói sozinho e que sempre se parte em 2 pedaços de 2; o jogo entra em câmera lenta e explica a **montagem** (um clique num pedaço dentro do alcance encaixa ele direto; segurando, dá para arrastar até a nave). Ao segurar o primeiro pedaço, aparece a dica da roda do mouse para girá-lo. Depois vem um inimigo que sempre erra os tiros: uma rocha com uma peça de cada lado, cada peça com 1 canhão; ao ser destruído ele solta essas 2 peças. Câmera lenta pedindo para encaixá-las e, com os dois canhões encaixados, abre uma janela grande (jogo pausado) com as **formações** de cada arma (3, 6 e 10 canhões em triângulo) e o aviso de que o canhão do núcleo não conta. Por fim, câmera lenta e explicação do **giro da nave** (R ou clique direito). As teclas e botões do mouse aparecem no texto como ícones (chips de tecla com a moldura de hexágonos). A câmera lenta acaba quando o jogador faz o que o texto pede; os asteroides do tutorial não machucam a nave, e o relógio da corrida (dificuldade e chegada) só começa depois dele. Para desligar: campo **Tutorial Enabled** do nó `Game`.
- **Jogador**: começa com 1 célula, a *core* (branca com detalhes azuis), com um canhão comum. Só células com canhão atiram, **sozinhas**: cada canhão mira no asteroide mais próximo dele (com mira antecipada). As demais células são casco e protegem a core.
- **Asteroides**: nascem fora da tela com direção, velocidade e tamanho `n` (nº de células, no mínimo 3) aleatórios, e mudam de direção quando batem entre si (armados ou não; quicam e giram conforme o ponto de impacto). São destruídos após `ceil(n^(3/2))` de dano. Ao bater na nave, o asteroide entra destruindo as células que toca, até um limite que cresce com o tamanho dele (padrão: 1 célula a cada 4 do asteroide, no mínimo 1). Ele **não perde células** na batida: toma **2 de dano por célula da nave destruída**. Depois atravessa a nave, sem quicar nem empurrar, e só volta a machucar depois de se afastar (só o MEGATRON barra a nave). Partes da nave que perderem a ligação com a core se soltam como um pedaço flutuante (com seus canhões) e podem ser encaixadas de novo. **O jogo só acaba quando a core é destruída.**
- **Inimigos (asteroides armados)**: têm canhões (os mesmos da nave) e atiram nela; cada acerto destrói uma célula da nave ou de um pedaço de minério solto (o pedaço se parte se ficar desconectado). Tiros que acertam outros asteroides não causam dano, só os empurram no sentido do tiro (mais fraco quanto maior o asteroide; a bomba empurra para longe da explosão). O cano brilha em vermelho logo antes do tiro. Os asteroides comuns nascem sem canhões; os inimigos seguem ondas por minuto da corrida (`config/enemies.tres`):

| Tempo | Máx. ao mesmo tempo / intervalo | Inimigos que podem aparecer |
|---|---|---|
| 0:00 | 3 / 5 s | 1 a 3 canhões comuns |
| 1:00 | 4 / 4 s | + 1 a 2 shotguns |
| 2:00 | 5 / 3,5 s | + 1 bomba |
| 3:00 | — | chega o MEGATRON (os mistos, liberados no minuto 3, só aparecem se a corrida for mais longa) |

- **MEGATRON (chefe)**: na bandeira de chegada (3 min) os asteroides e inimigos param de vir e o MEGATRON entra pela direita: enorme e alto, de casco branco e núcleo como os da nave, com o laser gigante na frente, bombas no meio, canhões comuns no meio-termo e shotguns nas pontas. Ele sobe e desce; antes do laser gigante para, mostra uma faixa de aviso por 3 s e dispara por 5 s reto para a esquerda, cortando a tela. A luta tem 3 fases: primeiro as **torretas** (fáceis de destruir; o laser e o núcleo ficam com escudo), depois o **laser gigante** e por fim o **núcleo**. O casco quebra como o da nave: partes que perdem a ligação com o núcleo se soltam como pedaços que dá para pegar. Destruir o núcleo **vence o jogo** (tela de vitória).
- **Minérios**: todo asteroide destruído pelos canhões se parte em **pedaços** conectados, no mesmo lugar em que estavam: os pequenos geralmente não se partem (4 células = 1 pedaço) e os grandes se partem em mais (16 células ≈ 3 pedaços). Antes, 20% das células viram poeira (sem partir o resto). Os canhões do asteroide são células como as outras: vão no pedaço em que caírem, então um triângulo pode cair inteiro, dividido ou sem algumas células. Os pedaços soltos (e os canhões derrubados pelos inimigos) quicam nos asteroides (com massa bem menor que eles), mas passam por cima da nave sem bater, e são arrastados devagar para a esquerda, saindo da tela se ninguém pegar. Eles não grudam sozinhos: o jogador os pega com o **raio trator** (clique e arraste, dentro do alcance em volta da nave), gira com a roda do mouse (passos de 60°, o grid hexagonal) e solta quando o encaixe fantasma aparecer: todas as células precisam caber e ao menos uma encostar na nave. Um **clique rápido** num pedaço dentro do alcance puxa ele sozinho até a nave, e ele encaixa no primeiro lugar em que couber. Minério verde vira casco; células de canhão viram canhões comuns. **A única forma de ganhar canhões é pegando os dos asteroides.**

### Canhões
O canhão comum é o bloco de montar dos outros: canhões comuns adjacentes em **triângulo** se fundem num único canhão maior que ocupa o triângulo todo (os maiores têm prioridade). O núcleo é um canhão comum que nunca se funde. Se uma célula de um canhão grande for destruída, ele se desfaz e as células que sobraram voltam a se fundir no maior triângulo que ainda formarem (ex.: um laser que perde uma ponta vira bomba + comuns). Canhões funcionam em qualquer lugar da nave.

| Canhão | Cor | Formação | Como funciona |
|---|---|---|---|
| Comum | Azul | 1 célula | Tiro único no asteroide mais próximo |
| Shotgun | Laranja | Triângulo de 3 comuns | 5 tiros por disparo (1 no centro e 2 abrindo para cada lado), mesmo alcance do canhão comum |
| Bomba | Roxo | Triângulo de 6 comuns | Míssil lento lançado no asteroide mais próximo, explode com dano em área |
| Laser | Vermelho | Triângulo de 10 comuns | Dispara quando um asteroide cruza sua linha: raio para fora da nave (do núcleo para o canhão) com dano contínuo; gire a nave (clique direito) para mirar |

## Estrutura
| Arquivo | Conteúdo |
|---|---|
| `scripts/hex.gd` | Matemática da grade hexagonal (lado plano em cima, coordenadas axiais) |
| `scripts/art.gd`, `art/` | Artes das células (flores de 19 hexágonos) e dos canhões, juntadas em atlas |
| `scripts/hex_body.gd` | Base de todo objeto feito de células: desenho, colisão e canhões (grupos e canos) |
| `scripts/tutorial.gd`, `scripts/ui/tutorial_panel.gd`, `scripts/ui/formation_window.gd` | Tutorial do início da partida (etapas, câmera lenta, asteroides do tutorial), a caixa de texto dele e a janela das formações dos canhões |
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
| `scripts/ui/hud.gd` | HUD: cards de hexágonos e countdown, barra de vida do chefe, textos flutuantes, vinheta de dano, mira e telas de game over e vitória |
| `scripts/ui/race_bar.gd` | Linha de chegada no rodapé (marcador da nave e bandeira) |
| `scripts/ui/stat_card.gd`, `hex_icon.gd` | Cards do HUD e do recorde no menu e ícone animado (placeholder hexagonal) |
| `scripts/ui/pause_menu.gd` | Menu de pausa (continuar, info, menu principal, sair) |
| `scripts/ui/manual.gd` | Manual (controles, regras, canhões) e painéis compartilhados pelos menus |

## Tela e moldura do HUD
O jogo abre em **tela cheia** e escala tudo (UI, sprites, mundo) a partir da resolução base 1280×720 (`canvas_items` + `expand`: telas mais largas ou mais altas mostram mais área, sem distorcer). Isso é aplicado por código em `scripts/display.gd` ao abrir o menu e a partida, então não depende do `project.godot` (que o editor pode sobrescrever).

**HUD**: no topo, à esquerda, o card com o número atual de hexágonos da nave; à direita, o **countdown** até o fim da corrida (3:00 → 0:00; dourado no último minuto, vermelho e pulsando nos últimos 10 s). Durante a luta com o chefe, a vida dele aparece no alto, no centro. No rodapé, a linha de chegada numa moldura longa. As telas de game over e de vitória mostram quanto faltava para a chegada (ou "chegada alcançada"), as estatísticas e os botões lado a lado.

Toda a UI (HUD, telas de fim, menus, tutorial) usa a moldura `art/ui/hex_frame.png` (`HexFrame`):
- **Escala**: 9-slice. As pontas em chevron e os cantos ficam intactos, a fileira de hexágonos da borda se repete na horizontal e a coluna do meio da ponta se repete na vertical, então a moldura estica em qualquer largura e altura.
- **Cor**: segue o conteúdo (hexágonos em ciano, canhões em azul, tempo em cinza, recorde em dourado, manual em verde, game over em vermelho, pausa e barra de chegada no roxo original). A arte é recolorida trocando o matiz e escurecida até a luminância do roxo original, para o texto continuar legível.
- **Espessura**: `THIN` (chips), `SMALL` (botões e barra), `MEDIUM` (cards) e `LARGE` (painéis grandes).
- Botões: roxo parado, ciano com o mouse ou foco, dourado apertado.

Para trocar a moldura inteira, substitua `hex_frame.png` e ajuste `MARGINS` em `hex_frame.gd`.

## Sprites da interface
Para trocar uma peça específica pela sua arte, salve um PNG em `art/ui/` com o nome do slot (ex.: `art/ui/button_normal.png`); ele tem prioridade sobre a moldura de hexágonos e os placeholders. Não precisa mexer em código.

| Slots | O que são | Como é encaixado |
|---|---|---|
| `card`, `card_cells`, `card_countdown`, `card_race`, `card_boss`, `card_record` | Molduras dos cards do HUD (hexágonos, countdown, linha de chegada, vida do chefe) e do recorde no menu (`card` vale para os que não tiverem a sua) | 9-slice |
| `panel`, `panel_pause`, `panel_manual`, `panel_game_over`, `panel_victory`, `panel_tutorial`, `panel_formations` | Molduras dos painéis (`panel` vale para todos) | 9-slice |
| `button_normal`, `button_hover`, `button_pressed`, `button_focus` | Estados dos botões e abas (os que faltarem usam o estado mais próximo) | 9-slice |
| `key`, `separator` | Chip de tecla do manual e linha separadora | 9-slice / estica na largura |
| `icon_cells`, `icon_countdown`, `icon_record`, `icon_pause`, `icon_manual` | Ícones dos cards e dos títulos (pulsam, não giram) | Cabe no tamanho do placeholder |
| `race_marker`, `race_flag` | Marcador da nave e bandeira de chegada na linha do rodapé | Cabe no tamanho do placeholder |
| `reticle`, `key_arrow` | Mira e seta das teclas | Cabe no tamanho do placeholder |
| `key_mouse_left`, `key_mouse_right`, `key_mouse_wheel` | Mouse com o botão esquerdo, o direito ou a roda aceso (manual e tutorial) | Cabe no tamanho do placeholder |
| `title_logo` | Logo do menu (substitui o texto HEXCORE) | Tamanho real |
| `damage_vignette`, `backdrop_menu`, `backdrop_pause`, `backdrop_game_over`, `backdrop_victory` | Borda de dano e fundos atrás dos painéis | Estica na tela |

A margem do 9-slice é 12 px (muda por slot em `UISkin.SLICE`). Tamanhos de referência em `art/ui/LEIA-ME.txt`. Para um novo elemento de UI trocável, adicione o slot em `UISkin.SLOTS` e estenda `UISprite` (ou use `UISkin.stylebox()` / `UISkin.replace()`).

## Parâmetros dos asteroides
Tudo sobre os asteroides fica em `config/asteroids.tres`: abra no Godot e edite no Inspector (os valores padrão e a explicação de cada um estão em `scripts/asteroid_config.gd`). Para ter presets (fácil, difícil…), duplique o `.tres` e arraste o novo no campo **Asteroid Config** do nó `Game` em `game.tscn`.

O Godot grava no `.tres` só os valores diferentes do padrão do código; o Inspector mostra todos. Curva atual, com o chefe aos 3 min (o relógio começa depois do tutorial): começa leve e aperta rápido.

| Tempo | Asteroide a cada | Multiplicador (HP e velocidade, 0.2/min) | Tamanho máx. (sem canhões) |
|---|---|---|---|
| 0:00 | ~1,3 s | 1,0x | 3 |
| 1:00 | ~0,86 s | 1,2x | 10 |
| 1:30 | ~0,69 s | 1,3x | 14 |
| 2:00 | ~0,57 s (mínimo) | 1,4x | 18 |
| 3:00 | chefe | 1,6x | 25 |

Para mudar a quantidade de spawns de tudo de uma vez, use `spawn_rate` em `config/travel.tres` (grupo Fluxo): multiplica a frequência de asteroides e inimigos (2 = o dobro, 0.5 = a metade).

| Grupo | Parâmetros |
|---|---|
| Dificuldade com o tempo | multiplicador que começa em 1 e sobe X por minuto (padrão do código +30%/min, até 2x; o `asteroids.tres` usa +20%/min); escolha se ele aumenta HP, velocidade e/ou frequência de spawn |
| Spawn | atraso do primeiro, intervalo inicial/mínimo, quanto acelera por segundo, variação aleatória, multiplicador final da frequência (`spawn_rate`, padrão 0.7 = 30% menos asteroides), **máximo de asteroides vivos**, distância de spawn/despawn, desvio da mira em direção à nave |
| Tamanho | mínimo, teto absoluto, máximo no início, crescimento por tempo e por canhão, `size_bias` (controla o **tamanho médio**: ≈ mín + (máx − mín) / (bias + 1)) |
| Vida e pontos | HP = ⌈multiplicador × células^expoente⌉, pontos por HP |
| Movimento | faixa de velocidade, multiplicador para pequenos/grandes, giro inicial e máximo, elasticidade das batidas |
| Batida na nave | quantas células da nave o asteroide destrói por célula dele (profundidade), mínimo por batida, dano que o asteroide toma por célula destruída (2), elasticidade da batida da nave no chefe (os asteroides atravessam a nave sem quicar) |
| Minério | fração perdida, em quantos pedaços se parte (tamanho até o qual não se parte, células por pedaço a mais, variação), velocidade dos pedaços, máximo na tela, massa das células de minério e elasticidade da batida com asteroides e com a nave |

## Viagem (fundo e chegada)
A câmera fica parada e só o fundo rola, dando a impressão de que a nave avança para a direita; a nave se move livre, mas presa na tela. Para reforçar, os asteroides nascem de preferência à frente (direita) e são arrastados devagar para a esquerda. No rodapé, o marcador da nave anda até a bandeira de chegada e a alcança aos 3 min. Tudo isso fica em `config/travel.tres` (explicações em `scripts/travel_config.gd`), com presets pelo campo **Travel Config** do nó `Game`.

| Grupo | Parâmetros |
|---|---|
| Fundo | velocidade inicial, aumento por minuto e máxima, direção do avanço, parallax das estrelas distantes/próximas, quantidade de estrelas, rastro das estrelas, linhas de velocidade (quantidade, opacidade, velocidade) |
| Efeitos de velocidade | riscos atrás da nave e dos asteroides (quantidade, comprimento, opacidade), partículas de rastro da nave por segundo |
| Fluxo | **`spawn_rate` global** (frequência de spawn de asteroides e inimigos, padrão 1), arrasto dos asteroides e dos minérios soltos para trás (padrão 45 px/s cada), chance de nascerem à frente (70%) e abertura desse arco (120°), abertura total onde podem nascer (`spawn_side_arc`, 180° = só da metade da tela para a frente) |
| Chegada | tempo até a bandeira, quando entra o chefe (padrão 180 s; as rampas de dificuldade estão ajustadas para ele) |

## Parâmetros dos canhões
Ficam em `config/cannons.tres` (padrões e explicação em `scripts/cannon_config.gd`), com presets pelo campo **Cannon Config** do nó `Game`. Dano é medido em "tiros do canhão comum".

| Grupo | Parâmetros |
|---|---|
| Geral | multiplicador de dano e de cadência de todos os canhões |
| Comum | recarga, dano, alcance, velocidade do tiro |
| Shotgun | recarga, tiros de cada lado do central, dano por projétil, abertura do leque, velocidade (o alcance é o do comum) |
| Laser | recarga, duração do raio, dano por segundo, comprimento |
| Bomba | recarga, dano e raio da explosão, alcance, velocidade do míssil |

## Asteroides armados
Ficam em `config/enemies.tres` (explicações em `scripts/enemy_config.gd`), com presets pelo campo **Enemy Config** do nó `Game`. Quase tudo vai de um valor "início" a um valor "fim" conforme a barra de chegada avança. Os canhões inimigos usam os números de `cannons.tres` com os ajustes daqui.

| Grupo | Parâmetros |
|---|---|
| Ondas | máximo de inimigos vivos e intervalo entre eles por minuto, atraso do primeiro, minuto em que entram shotgun, bomba e mistos, máximo de canhões dos mistos, células de rocha além dos canhões |
| Chefe | vida do casco (por célula), das torretas, do laser gigante e do núcleo, velocidade de entrada e distância da borda, patrulha (amplitude e velocidade), recarga, alcance dos tiros, laser gigante (recarga, aviso, duração, espessura, comprimento), dano ao encostar, pontos |
| Força | multiplicador de recarga, velocidade dos projéteis, erro de mira, alcance, espera antes do primeiro tiro, projéteis da shotgun, raio da bomba, tempo do laser para destruir uma célula |
| Empurrão nos asteroides | força do empurrão de projétil, da explosão da bomba e do laser (por segundo), dividida pelo nº de células do asteroide |

Os demais parâmetros de balanceamento ficam como `const` no topo de cada script (ex.: `SIZE` em `hex.gd`, movimento da nave em `player.gd`).

## Créditos
- Fonte [Hexagon](https://fontstruct.com/fontstructions/show/1727445) por "twannieboy", sob a licença Creative Commons BY-NC-SA 3.0 (uso não comercial). Licença e leia-me em `fonts/Hexagon-*.txt`. Ela só tem letras sem acento, então os textos do jogo aparecem sem acentos.
- Fonte [Orbitron](https://fonts.google.com/specimen/Orbitron) (Matt McInerney), sob a SIL Open Font License, usada como reserva para números e pontuação. Licença em `fonts/Orbitron-OFL.txt`.
