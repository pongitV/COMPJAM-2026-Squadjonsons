# COMPJAM-2026-Squadjonsons

**Hex Asteroids**: um jogo inspirado no Asteroids clássico, feito em Godot 4.5. Todo objeto é formado por células hexagonais.

## Como rodar
Abra a pasta no Godot 4.5 (Importar → `project.godot`) e aperte **F5**.

## Controles
| Ação | Tecla |
|---|---|
| Mover | WASD / setas |
| Atirar | Clique esquerdo (segurar) |
| Pausar / info | ESC (ou P) |
| Reiniciar (após game over) | R |

## Regras
- **Jogador**: começa com 1 célula, a *core* (dourada). Cada célula dispara um projétil em direção ao mouse. Se a core for destruída, é game over.
- **Asteroides**: nascem fora da tela com direção, velocidade e tamanho `n` (nº de células) aleatórios. São destruídos após `ceil(n^(3/2))` disparos. Ao tocar o jogador, o asteroide é destruído e o jogador perde `n` células (as mais distantes da core primeiro). Células que ficarem desconectadas da core também se perdem. Se `n` ≥ células não-core, a core é destruída.
- **Minérios**: um asteroide destruído a tiros solta minério proporcional ao seu tamanho. Ao tocar o jogador, o minério vira uma nova célula.

## Estrutura
| Arquivo | Conteúdo |
|---|---|
| `scripts/hex.gd` | Matemática da grade hexagonal (coordenadas axiais) |
| `scripts/hex_body.gd` | Base de todo objeto feito de células: desenho e colisão |
| `scripts/player.gd` | Movimento, disparos, absorção de minério, dano |
| `scripts/asteroid.gd` | Geração aleatória e HP |
| `scripts/ore.gd` | Minério (com leve magnetismo em direção ao jogador) |
| `scripts/bullets.gd` | Todos os projéteis, em arrays compactos |
| `scripts/game.gd` | Spawn, colisões, câmera, estatísticas e recorde |
| `scripts/ui/ui_style.gd` | Paleta, fontes e estilos (cantos chanfrados) da interface |
| `scripts/ui/hud.gd` | HUD: cards animados, textos flutuantes, vinheta de dano, mira e game over |
| `scripts/ui/stat_card.gd`, `hex_icon.gd` | Card de status com contador animado e ícone hexagonal |
| `scripts/ui/pause_menu.gd` | Menu de pausa (continuar, info, sair) |

Os parâmetros de balanceamento ficam como `const` no topo de cada script (ex.: `ORE_PER_CELL` e `DROP_ORE_ON_COLLISION` em `game.gd`, `FIRE_INTERVAL` em `player.gd`, `SIZE` em `hex.gd`).

## Créditos
- Fontes [Orbitron](https://fonts.google.com/specimen/Orbitron) (Matt McInerney) e [Rajdhani](https://fonts.google.com/specimen/Rajdhani) (Indian Type Foundry), sob a SIL Open Font License. Licenças em `fonts/`.
