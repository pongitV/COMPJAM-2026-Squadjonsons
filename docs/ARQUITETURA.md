# Arquitetura do Projeto - HexCore

Este documento detalha a organização técnica, o fluxo de execução e a responsabilidade de cada script e cena no desenvolvimento de **HexCore** em Godot 4.7.

[Voltar ao README](../README.md) | [Balanceamento e Configurações](BALANCEAMENTO.md) | [Sistema de Interface](INTERFACE.md)

---

## 1. Visão Geral da Arquitetura

O projeto baseia-se em corpos rígidos compostos por células hexagonais discretas (`HexBody`). Toda entidade modular (a nave do jogador, os asteroides, pedaços de minério soltos e o chefe MEGATRON) herda ou implementa as regras da grade hexagonal flat-top definida em `scripts/hex.gd`.

### Componentes Chave

- **Matemática Hexagonal (`scripts/hex.gd`):** Coordenadas axiais $(q, r)$, conversão para pixels, cálculo de distâncias em grade e rotação em passos de 60 graus.
- **Corpo Hexagonal (`scripts/hex_body.gd`):** Gerencia o dicionário de células, desenho vetorial otimizado, detecção de colisões ponto a ponto e agrupamento de armas.
- **Renderização em Lote (`scripts/tri_batch.gd` e `scripts/fx.gd`):** Renderização consolidada de primitivas em uma única chamada de desenho (draw call) para garantir alta performance mesmo com centenas de projéteis e detritos na tela.
- **Montagem Modular em Tempo Real (`scripts/tractor.gd`):** Lógica física do raio trator para atração, rotação e acoplamento de células ao corpo do jogador.

---

## 2. Estrutura de Scripts e Cenas

| Arquivo / Diretório | Responsabilidade Técnica |
|---|---|
| `main.tscn`, `scripts/ui/main_menu.gd` | Cena inicial e controlador do menu principal: transição de telas, recordes persistentes e animação em segundo plano. |
| `game.tscn`, `scripts/game.gd` | Controlador central da partida: gerenciamento de ciclos de vida, câmera, colisões, fluxo de asteroides e pontuação. |
| `scripts/hex.gd` | Biblioteca estática de matemática hexagonal: orientação flat-top (lado plano superior), conversão axial/pixel e rotação. |
| `scripts/art.gd`, `art/` | Atlas procedural e gerenciamento de texturas para as células hexagonais e bocas de canhões. |
| `scripts/hex_body.gd` | Classe base para corpos modulares: controle de células, integridade estrutural, colisão e canos de tiro. |
| `scripts/player.gd` | Entidade da nave do jogador: movimentação com inércia, rotação direcional, mira automática preditiva e cálculo de dano. |
| `scripts/weapons.gd` | Enumerações dos tipos de armamento, paleta de cores e propriedades visuais. |
| `scripts/cannon_groups.gd` | Algoritmo de identificação e fusão automática de canhões comuns adjacentes em formações triangulares. |
| `scripts/cannon_config.gd`, `config/cannons.tres` | Recurso de balanceamento de armas (dano, recarga, velocidade e alcances). |
| `scripts/bullets.gd` | Sistema de pooling e renderização de projéteis lineares (canhão comum e shotgun). |
| `scripts/lasers.gd` | Implementação de feixes contínuos com persistência e dano por segundo. |
| `scripts/missiles.gd` | Projéteis guiados com aceleração, alcance e detonação em área. |
| `scripts/asteroid.gd` | Geração procedural de asteroides, integridade celular, física de quique e fragmentação. |
| `scripts/asteroid_config.gd`, `config/asteroids.tres` | Configuração de curvas de dificuldade, frequência de spawn e propriedades físicas de asteroides. |
| `scripts/ore.gd` | Entidade para fragmentos de minério e canhões descartados à deriva no espaço. |
| `scripts/tractor.gd` | Sistema de raio trator do jogador: captura, arraste manual, rotação e cálculo de encaixe compatível. |
| `scripts/enemy_config.gd`, `config/enemies.tres` | Tabela de ondas por minuto, progressão de armamento hostil e coeficientes de ataque. |
| `scripts/enemy_shots.gd` | Sistema autônomo de controle de disparos hostis e mira direcional contra a nave do jogador. |
| `scripts/boss.gd` | Comportamento do chefe MEGATRON: máquina de estados de fases (torretas, laser gigante e núcleo), patrulha vertical e blindagem. |
| `scripts/tutorial.gd` | Máquina de estados do tutorial inicial: controle de câmera lenta, spawning scriptado e checagem de objetivos. |
| `scripts/travel_config.gd`, `config/travel.tres` | Configuração do fluxo de viagem: velocidade de rolagem de fundo, efeito parallax e duração da corrida. |
| `scripts/starfield.gd`, `scripts/speed_fx.gd` | Renderizador do campo estelar multicamada, rastros de velocidade e linhas de deslocamento. |
| `scripts/fx.gd` | Gerenciador de partículas, anéis de onda de choque e efeitos de destruição. |
| `scripts/tri_batch.gd` | Acumulador de geometria de triângulos para redução de chamadas de renderização. |
| `scripts/save_data.gd` | Leitura e gravação de pontuações recordes no armazenamento persistente do usuário (`user://save.cfg`). |
| `scripts/input_actions.gd` | Inicialização programática de mapeamentos de teclado e mouse. |
| `scripts/display.gd` | Ajuste de resolução dinâmica (1280x720 base), viewport expandida e alternância de tela cheia. |
| `scripts/ui/ui_skin.gd`, `art/ui/` | Gerenciamento de slots visuais e substituição dinâmica de placeholders por texturas PNG. |
| `scripts/ui/ui_sprite.gd` | Componente de controle para desenho de placeholders ou sprites da interface. |
| `scripts/ui/ui_style.gd` | Definição do tema visual, paletas de cores, tipografia e gerador de chips de comandos. |
| `scripts/ui/hex_frame.gd`, `art/ui/hex_frame.png` | Moldura hexagonal com lógica de 9-slice para redimensionamento responsivo sem distorção. |
| `scripts/ui/hud.gd` | Camada de HUD: cartões de células, cronômetro de corrida, barra de vida do chefe e telas de conclusão. |
| `scripts/ui/race_bar.gd` | Barra de progresso visual no rodapé indicando a aproximação do final da corrida. |
| `scripts/ui/stat_card.gd`, `scripts/ui/hex_icon.gd` | Contêineres de informações estatísticas e ícones hexagonais dinâmicos. |
| `scripts/ui/tutorial_panel.gd` | Painel inferior de mensagens do tutorial com suporte a chips de botões embutidos no texto. |
| `scripts/ui/formation_window.gd` | Janela explicativa pausada com diagramas das formações de canhões. |
| `scripts/ui/pause_menu.gd` | Menu de pausa com opções de retorno, acesso ao manual e saída. |
| `scripts/ui/manual.gd` | Manual integrado em abas (controles, mecânicas e armas). |

---

## 3. Ciclo de Vida da Partida (`game.gd`)

1. **Inicialização:** Configura câmera fixa, inicializa o fundo de estrelas (`Starfield`) e instancia o jogador (`Player`). Se habilitado, inicia o nó `Tutorial`.
2. **Execução de Onda:** O relógio da corrida avança, incrementando o multiplicador de dificuldade e controlando os temporizadores de spawn em `AsteroidConfig` e `EnemyConfig`.
3. **Chegada da Bandeira (180 segundos):** Cessa o surgimento de novos asteroides e aciona a entrada triunfal do `Boss` (MEGATRON).
4. **Resolução:** A destruição da célula central da nave resulta em Game Over; a destruição do núcleo do MEGATRON resulta em Vitória.
