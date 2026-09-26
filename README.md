# COMPJAM-2026-Squadjonsons

**Hex Asteroids**: um jogo inspirado no Asteroids clássico, feito em Godot 4.5. Todo objeto é formado por células hexagonais.

## Como rodar
Abra a pasta no Godot 4.5 (Importar → `project.godot`) e aperte **F5**.

## Controles
| Ação | Tecla |
|---|---|
| Mover | WASD / setas |
| Atirar | Clique esquerdo (segurar) |
| Girar a nave para a mira | R (segurar) |
| Pausar / info | ESC (ou P) |
| Reiniciar (após game over) | R |

## Regras
- **Jogador**: começa com 1 célula, a *core* (dourada), com um canhão comum. Só células com canhão atiram; as demais são casco e protegem a core. Se a core for destruída, é game over.
- **Asteroides**: nascem fora da tela com direção, velocidade e tamanho `n` (nº de células) aleatórios. São destruídos após `ceil(n^(3/2))` de dano. Ao tocar o jogador, o asteroide é destruído e o jogador perde `n` células (as mais distantes da core primeiro). Células que ficarem desconectadas da core também se perdem. Se `n` ≥ células não-core, a core é destruída.
- **Minérios**: um asteroide destruído solta minério proporcional ao seu tamanho. Minério verde vira casco; às vezes um deles é colorido e vira um canhão especial (mais chance em asteroides maiores).

### Canhões
| Canhão | Cor | Como funciona | Como ganhar |
|---|---|---|---|
| Comum | Azul | Tiro único na direção da mira | 1 a cada 5 asteroides destruídos. Só fica na camada externa da nave: se for cercado, muda sozinho para a borda |
| Shotgun | Laranja | 6 tiros em leque, alcance curto | Minério laranja |
| Laser | Vermelho | Raio para fora da nave (do núcleo para o canhão) com dano contínuo por 3 s; gire a nave (R) para mirar | Minério vermelho |
| Bomba | Roxo | Míssil lento que explode na mira ou ao tocar um asteroide, com dano em área | Minério roxo |

## Estrutura
| Arquivo | Conteúdo |
|---|---|
| `scripts/hex.gd` | Matemática da grade hexagonal (coordenadas axiais) |
| `scripts/hex_body.gd` | Base de todo objeto feito de células: desenho e colisão |
| `scripts/player.gd` | Movimento, canhões por célula, absorção de minério, dano |
| `scripts/weapons.gd` | Tipos de canhão: cores, recarga e números de balanceamento |
| `scripts/asteroid.gd` | Geração aleatória e HP |
| `scripts/ore.gd` | Minério (com leve magnetismo em direção ao jogador) |
| `scripts/bullets.gd` | Projéteis do canhão comum e da shotgun, em arrays compactos |
| `scripts/lasers.gd`, `scripts/missiles.gd` | Raio laser e mísseis da bomba |
| `scripts/game.gd` | Spawn, colisões, câmera, estatísticas e recorde |
| `scripts/ui/ui_style.gd` | Paleta, fontes e estilos (cantos chanfrados) da interface |
| `scripts/ui/hud.gd` | HUD: cards animados, textos flutuantes, vinheta de dano, mira e game over |
| `scripts/ui/stat_card.gd`, `cannon_card.gd`, `hex_icon.gd` | Cards do HUD (status e canhões) e ícone hexagonal |
| `scripts/ui/pause_menu.gd` | Menu de pausa (continuar, info, sair) |

Os parâmetros de balanceamento ficam como `const` no topo de cada script (ex.: dano, recarga e alcance dos canhões em `weapons.gd`, `ORE_PER_CELL` em `game.gd`, `SIZE` em `hex.gd`).

## Créditos
- Fontes [Orbitron](https://fonts.google.com/specimen/Orbitron) (Matt McInerney) e [Rajdhani](https://fonts.google.com/specimen/Rajdhani) (Indian Type Foundry), sob a SIL Open Font License. Licenças em `fonts/`.
