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
| Reiniciar (após game over) | R |

## Regras
- **Jogador**: começa com 1 célula, a *core* (branca com detalhes azuis), com um canhão comum. Só células com canhão atiram, **sozinhas**: cada canhão mira no asteroide mais próximo dele (com mira antecipada). As demais células são casco e protegem a core.
- **Asteroides**: nascem fora da tela com direção, velocidade e tamanho `n` (nº de células, no mínimo 3) aleatórios, e batem entre si (quicam e giram conforme o ponto de impacto). São destruídos após `ceil(n^(3/2))` de dano. O dano na nave é por contato: cada célula do asteroide que encosta na nave destrói a célula da nave que ela tocou; depois de destruir 2, ela some (se o asteroide se partir, as partes seguem como asteroides separados; partes com menos de 3 células viram poeira). Partes da nave que perderem a ligação com a core se soltam como um pedaço flutuante (com seus canhões) e podem ser encaixadas de novo. **O jogo só acaba quando a core é destruída.**
- **Minérios**: todo asteroide destruído pelos canhões se parte em **pedaços** de 2 a 4 células conectadas, no mesmo lugar em que estavam; 20% das células se perdem. Os pedaços não grudam sozinhos: o jogador os pega com o **raio trator** (clique e arraste, dentro do alcance em volta da nave), gira com a roda do mouse (passos de 60°, o grid hexagonal) e solta quando o encaixe fantasma aparecer: todas as células precisam caber e ao menos uma encostar na nave. Minério verde vira casco; às vezes uma célula é colorida e vira um canhão especial (mais chance em asteroides maiores).

### Canhões
| Canhão | Cor | Como funciona | Como ganhar |
|---|---|---|---|
| Comum | Azul | Tiro único no asteroide mais próximo | 1 a cada 5 asteroides destruídos. Só fica na camada externa da nave: se for cercado, muda sozinho para a borda |
| Shotgun | Laranja | 6 tiros em leque no asteroide mais próximo, alcance curto | Minério laranja |
| Laser | Vermelho | Dispara quando um asteroide cruza sua linha: raio para fora da nave (do núcleo para o canhão) com dano contínuo por 3 s; gire a nave (clique direito) para mirar | Minério vermelho |
| Bomba | Roxo | Míssil lento lançado no asteroide mais próximo, explode com dano em área | Minério roxo |

## Estrutura
| Arquivo | Conteúdo |
|---|---|
| `scripts/hex.gd` | Matemática da grade hexagonal (lado plano em cima, coordenadas axiais) |
| `scripts/art.gd`, `art/` | Artes das células (flores de 19 hexágonos) e dos canhões, juntadas em atlas |
| `scripts/hex_body.gd` | Base de todo objeto feito de células: desenho e colisão |
| `scripts/player.gd` | Movimento, giro, canhões por célula (mira automática), encaixe de pedaços e dano |
| `scripts/weapons.gd` | Tipos de canhão: cores e nomes |
| `scripts/cannon_config.gd`, `config/cannons.tres` | Parâmetros dos canhões (recarga, dano, alcance…), editáveis no Inspector |
| `scripts/asteroid.gd` | Geração aleatória, HP, dano na nave e batidas entre asteroides |
| `scripts/asteroid_config.gd`, `config/asteroids.tres` | Todos os parâmetros dos asteroides (spawn, tamanho, HP, velocidade, minério), editáveis no Inspector |
| `scripts/ore.gd` | Pedaço de minério solto (flutua até ser arrastado) |
| `scripts/tractor.gd` | Raio trator: pegar, arrastar, girar e encaixar pedaços no grid da nave |
| `scripts/bullets.gd` | Projéteis do canhão comum e da shotgun, em arrays compactos |
| `scripts/lasers.gd`, `scripts/missiles.gd` | Raio laser e mísseis da bomba |
| `main.tscn`, `scripts/ui/main_menu.gd` | Menu principal (cena inicial): jogar, manual, sair e recorde, com as artes flutuando no fundo |
| `game.tscn`, `scripts/game.gd` | Partida: spawn, colisões, câmera e estatísticas |
| `scripts/save_data.gd` | Recorde salvo entre partidas |
| `scripts/input_actions.gd` | Teclas e botões das ações (pausa, girar, arrastar), definidos por código |
| `scripts/ui/ui_skin.gd`, `art/ui/` | Sprites próprios da interface: lista de slots (`SLOTS`) e troca placeholder → sprite |
| `scripts/ui/ui_sprite.gd` | `UISprite`: objeto de UI que desenha o sprite do slot ou, sem ele, o placeholder |
| `scripts/ui/ui_style.gd` | Paleta, fontes e estilos placeholder (cantos chanfrados) da interface; `plain()` tira acentos (a fonte Hexagon não tem) |
| `scripts/ui/hud.gd` | HUD: cards animados, textos flutuantes, vinheta de dano, mira e game over |
| `scripts/ui/stat_card.gd`, `cannon_card.gd`, `hex_icon.gd` | Cards do HUD (status e canhões) e ícone animado (placeholder hexagonal) |
| `scripts/ui/pause_menu.gd` | Menu de pausa (continuar, info, menu principal, sair) |
| `scripts/ui/manual.gd` | Manual (controles, regras, canhões) e painéis compartilhados pelos menus |

## Sprites da interface
Toda a UI desenhada em código é placeholder. Para trocar uma peça pela sua arte, salve um PNG em `art/ui/` com o nome do slot (ex.: `art/ui/button_normal.png`); sem o arquivo, o placeholder continua. Não precisa mexer em código.

| Slots | O que são | Como é encaixado |
|---|---|---|
| `card`, `card_score`, `card_cells`, `card_time`, `card_cannons`, `card_record` | Molduras dos cards (`card` vale para os que não tiverem a sua) | 9-slice |
| `panel`, `panel_pause`, `panel_manual`, `panel_game_over` | Molduras dos painéis (`panel` vale para todos) | 9-slice |
| `button_normal`, `button_hover`, `button_pressed`, `button_focus` | Estados dos botões e abas (os que faltarem usam o estado mais próximo) | 9-slice |
| `key`, `separator` | Chip de tecla do manual e linha separadora | 9-slice / estica na largura |
| `icon_score`, `icon_cells`, `icon_time`, `icon_record`, `icon_pause`, `icon_manual`, `icon_cannon_*` | Ícones dos cards e títulos (pulsam, não giram) | Cabe no tamanho do placeholder |
| `pip_full`, `pip_empty`, `reticle`, `key_arrow` | Progresso até o próximo canhão, mira e seta das teclas | Cabe no tamanho do placeholder |
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
| Minério | fração perdida, tamanho e velocidade dos pedaços, máximo na tela, chance de canhão especial |

## Parâmetros dos canhões
Ficam em `config/cannons.tres` (padrões e explicação em `scripts/cannon_config.gd`), com presets pelo campo **Cannon Config** do nó `Game`. Dano é medido em "tiros do canhão comum".

| Grupo | Parâmetros |
|---|---|
| Geral | multiplicador de dano e de cadência de todos os canhões |
| Comum | recarga, dano, alcance, velocidade do tiro |
| Shotgun | recarga, nº de projéteis, dano por projétil, alcance, abertura do leque, velocidade |
| Laser | recarga, duração do raio, dano por segundo, comprimento |
| Bomba | recarga, dano e raio da explosão, alcance, velocidade do míssil |
| Ganho de canhões | asteroides por canhão comum, chance relativa de cada canhão especial |

Os demais parâmetros de balanceamento ficam como `const` no topo de cada script (ex.: `SIZE` em `hex.gd`, movimento da nave em `player.gd`).

## Créditos
- Fonte [Hexagon](https://fontstruct.com/fontstructions/show/1727445) por "twannieboy", sob a licença Creative Commons BY-NC-SA 3.0 (uso não comercial). Licença e leia-me em `fonts/Hexagon-*.txt`. Ela só tem letras sem acento, então os textos do jogo aparecem sem acentos.
- Fonte [Orbitron](https://fonts.google.com/specimen/Orbitron) (Matt McInerney), sob a SIL Open Font License, usada como reserva para números e pontuação. Licença em `fonts/Orbitron-OFL.txt`.
