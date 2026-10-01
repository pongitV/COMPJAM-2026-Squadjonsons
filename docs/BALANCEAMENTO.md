# Parâmetros e Balanceamento - HexCore

Este documento reúne todas as especificações numéricas, fórmulas matemáticas e parâmetros de balanceamento definidos nas *Resources* (`.tres`) do projeto em Godot 4.7.

[Voltar ao README](../README.md) | [Arquitetura do Projeto](ARQUITETURA.md) | [Sistema de Interface](INTERFACE.md)

---

## 1. Sistema de Recursos e Presets

Os parâmetros de balanceamento foram externalizados em arquivos de recurso (`.tres`) localizados na pasta `config/`. No editor Godot, é possível inspecionar e editar qualquer parâmetro em tempo real através do nó `Game` na cena principal da partida:

- **Asteroid Config:** `config/asteroids.tres`
- **Cannon Config:** `config/cannons.tres`
- **Enemy Config:** `config/enemies.tres`
- **Travel Config:** `config/travel.tres`

Para criar novos modos de jogo (ex.: Fácil, Extremo, Infinito), basta duplicar o respectivo arquivo `.tres`, ajustar os valores no Inspector e associá-lo ao slot correspondente no nó `Game`.

---

## 2. Parâmetros dos Asteroides

Definidos em `config/asteroids.tres` e estruturados por `scripts/asteroid_config.gd`.

### Curva de Progressão por Tempo
*(O cronômetro é disparado após a conclusão ou encerramento do tutorial)*

| Tempo de Partida | Intervalo entre Spawns | Multiplicador de Dificuldade (+20%/min) | Tamanho Máximo Base |
|---|---|---|---|
| 0:00 | ~1,30 s | 1,00x | 3 células |
| 1:00 | ~0,86 s | 1,20x | 10 células |
| 1:30 | ~0,69 s | 1,30x | 14 células |
| 2:00 | ~0,57 s (limite mínimo) | 1,40x | 18 células |
| 3:00 | Entrada do Chefe | 1,60x | 25 células |

### Grupos de Propriedades de Asteroides

| Grupo | Descrição e Parâmetros Principais |
|---|---|
| **Dificuldade Temporal** | Multiplicador base iniciado em 1.0 com acréscimo linear por minuto (`difficulty_per_minute = 0.2` no arquivo `.tres`; 0.3 no código base, com teto em 2.0x). Escala simultaneamente vida, velocidade e cadência de spawn. |
| **Geração (Spawn)** | Atraso do primeiro asteroide (4.0 s), intervalo inicial (0.9 s), intervalo mínimo absoluto (0.4 s), decaimento de intervalo por segundo (0.003), margem externa de spawn (120 px), fator de despawn (2.5x raio da tela) e dispersão de mira contra o jogador (`aim_spread`). |
| **Dimensão (Tamanho)** | Mínimo absoluto (3 células), teto absoluto (40 células), tamanho máximo inicial (3 células) e taxa de crescimento temporal (1 célula a cada 8.0 s). Fator `size_bias = 1.7` controla a distribuição probabilística com preferência por asteroides menores. |
| **Integridade e Pontos** | Cálculo de pontos de vida: $\text{HP} = \lceil\text{multiplicador} \times \text{células}^{1.5}\rceil$. Cada unidade de vida destruída concede 1.0 ponto de pontuação. |
| **Movimento e Física** | Faixa de velocidade linear (60 a 85 px/s), multiplicadores de velocidade para corpos pequenos (1.2x) e grandes (0.7x), limite de rotação por impacto (3.0 rad/s) e coeficiente de restituição elástica (0.6). |
| **Colisão com a Nave** | Profundidade de penetração (1 célula da nave para cada 4 do asteroide, mínimo de 1). O asteroide não perde células ao colidir com o jogador e sofre 2 pontos de dano por célula da nave destruída. Asteroides transpassam o corpo da nave sem barreira física sólida. |
| **Minério e Fragmentação** | Perda de aproximadamente 20% das células em poeira estelar. Asteroides de até 4 células não se dividem; acima disso, subdividem-se em fragmentos conectados (aproximadamente 1 fragmento extra a cada 6 células). Velocidade de dispersão das peças (20 a 55 px/s) e massa celular reduzida (0.1x a massa do asteroide). |

---

## 3. Parâmetros de Navegação e Fundo Estelar

Definidos em `config/travel.tres` e estruturados por `scripts/travel_config.gd`.

| Grupo | Descrição e Parâmetros Principais |
|---|---|
| **Fundo Estelar** | Velocidade inicial de rolagem (260 px/s), aceleração por minuto (25 px/s) e teto de velocidade (400 px/s). Efeito de profundidade com parallax de 0.12x nas camadas distantes e 1.0x nas camadas próximas. Densidade configurada em 260 estrelas. |
| **Efeitos Visuais de Deslocamento** | Linhas de velocidade de alta velocidade (fator 2.2x), rastros e linhas de vento na esteira da nave (6 linhas, 70 px de comprimento) e nos asteroides (3 linhas, 45 px). Taxa de emissão de partículas de rastro da nave: 30 partículas por segundo. |
| **Fluxo e Dinâmica** | Multiplicador global de frequência de spawn (`spawn_rate = 1.0`). Força de arraste linear de asteroides e minérios soltos para a esquerda (45 px/s). Probabilidade de 70% de surgimento no arco frontal de aproximação (120 graus). |
| **Duração da Corrida** | Tempo limite até o encontro com o chefe (`race_duration = 180.0 s`). |

---

## 4. Parâmetros dos Canhões do Jogador

Definidos em `config/cannons.tres` e estruturados por `scripts/cannon_config.gd`.

| Tipo de Arma | Configuração Atual (`cannons.tres`) | Comportamento e Dinâmica |
|---|---|---|
| **Comum** | Dano: 1.2<br>Recarga: 0.2 s<br>Alcance: 700 px<br>Velocidade: 750 px/s | Disparo direto frontal contra o asteroide mais próximo dentro do raio de alcance com antecipação de movimento. |
| **Shotgun** | Dano por projétil: 1.5<br>Recarga: 0.5 s<br>Alcance: 700 px<br>Velocidade: 450 px/s<br>Projéteis: 7 (3 por flanco + 1 central) | Disparo simultâneo em leque de 7 projéteis cobrindo um arco de dispersão de 43 graus (0.75 rad). |
| **Bomba** | Dano da explosão: 18.0<br>Recarga: 1.5 s<br>Alcance: 520 px<br>Velocidade: 150 px/s<br>Raio de detonação: 200 px | Lançamento de projétil balístico autoguiado que detona ao contato, causando dano em raio circular a todos os corpos no perímetro. |
| **Laser** | Dano por segundo: 12.0<br>Recarga: 2.0 s<br>Duração do feixe: 5.0 s<br>Alcance: 1000 px | Feixe contínuo projetado para o exterior da nave a partir do alinhamento núcleo-arma. Penetra múltiplos alvos simultaneamente. |

---

## 5. Parâmetros de Ondas Inimigas e Chefe

Definidos em `config/enemies.tres` e estruturados por `scripts/enemy_config.gd`.

### Cronograma de Ondas Hostis

| Minuto | Limite Simultâneo | Intervalo de Spawn | Armamentos Habilitados |
|---|---|---|---|
| **0:00** | 3 inimigos | 5,0 s | 1 a 3 canhões comuns |
| **1:00** | 4 inimigos | 4,0 s | Canhões comuns e 1 a 2 shotguns |
| **2:00** | 5 inimigos | 3,5 s | Adição de lançador de bombas |
| **3:00** | — | — | Chegada do MEGATRON |

### Coeficientes de Dificuldade e Combate do Chefe

| Categoria | Descrição |
|---|---|
| **Progressão de Dificuldade Inimiga** | O multiplicador de recarga dos canhões inimigos reduz de 5.0x (início) para 1.6x (final). A velocidade dos projéteis hostis sobe de 0.4x para 0.7x da velocidade do jogador, e o erro angular de mira diminui de 0.2 rad para 0.05 rad. |
| **Empurrão Físico** | Projéteis convencionais aplicam impulso físico (90 / número de células) px/s. Explosões de bombas geram repulsão radial de até 400 px/s, e feixes laser empurram continuamente a 240 px/s. |
| **Estrutura do MEGATRON** | Vida do casco por célula: 12.0 HP.<br>Vida de cada torreta auxiliar: 60.0 HP.<br>Vida do canhão laser gigante: 250.0 HP.<br>Vida do núcleo central: 400.0 HP. |
| **Laser Gigante do Chefe** | Tempo de recarga: 12.0 s.<br>Alerta visual preliminar: 3.0 s.<br>Duração do feixe: 5.0 s.<br>Comprimento do disparo: 1800 px.<br>Tempo para destruir uma célula da nave sob o raio: 0.12 s. |
