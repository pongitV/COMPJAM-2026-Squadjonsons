# COMPJAM-2026-Squadjonsons

**Hex Asteroids**: um jogo inspirado no Asteroids clássico, feito em Godot 4.5. Todo objeto é formado por células hexagonais.

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
- **Jogador**: começa com 1 célula, a *core* (dourada), com um canhão comum. Só células com canhão atiram, **sozinhas**: cada canhão mira no asteroide mais próximo dele (com mira antecipada). As demais células são casco e protegem a core.
- **Asteroides**: nascem fora da tela com direção, velocidade e tamanho `n` (nº de células) aleatórios. São destruídos após `ceil(n^(3/2))` de dano. O dano na nave é por contato: cada célula do asteroide que encosta na nave destrói a célula da nave que ela tocou; depois de destruir 2, ela some (se o asteroide se partir, as partes seguem como asteroides separados). Partes da nave que perderem a ligação com a core se soltam como um pedaço flutuante (com seus canhões) e podem ser encaixadas de novo. **O jogo só acaba quando a core é destruída.**
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
| `scripts/player.gd` | Movimento, canhões por célula, absorção de minério, dano |
| `scripts/weapons.gd` | Tipos de canhão: cores, recarga e números de balanceamento |
| `scripts/asteroid.gd` | Geração aleatória e HP |
| `scripts/ore.gd` | Pedaço de minério solto (flutua até ser arrastado) |
| `scripts/tractor.gd` | Raio trator: pegar, arrastar, girar e encaixar pedaços no grid da nave |
| `scripts/bullets.gd` | Projéteis do canhão comum e da shotgun, em arrays compactos |
| `scripts/lasers.gd`, `scripts/missiles.gd` | Raio laser e mísseis da bomba |
| `scripts/game.gd` | Spawn, colisões, câmera, estatísticas e recorde |
| `scripts/ui/ui_style.gd` | Paleta, fontes e estilos (cantos chanfrados) da interface |
| `scripts/ui/hud.gd` | HUD: cards animados, textos flutuantes, vinheta de dano, mira e game over |
| `scripts/ui/stat_card.gd`, `cannon_card.gd`, `hex_icon.gd` | Cards do HUD (status e canhões) e ícone hexagonal |
| `scripts/ui/pause_menu.gd` | Menu de pausa (continuar, info, sair) |

Os parâmetros de balanceamento ficam como `const` no topo de cada script (ex.: dano, recarga e alcance dos canhões em `weapons.gd`, `ORE_LOSS` e `PIECE_MIN`/`PIECE_MAX` em `game.gd`, `CELL_CHARGES` em `asteroid.gd`, `SIZE` em `hex.gd`).

## Créditos
- Fontes [Orbitron](https://fonts.google.com/specimen/Orbitron) (Matt McInerney) e [Rajdhani](https://fonts.google.com/specimen/Rajdhani) (Indian Type Foundry), sob a SIL Open Font License. Licenças em `fonts/`.
