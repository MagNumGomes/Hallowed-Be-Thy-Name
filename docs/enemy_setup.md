# Inimigos do protótipo

Godot **4.3+**, GDScript tipado e renderizador Compatibility. Os comportamentos seguem a descrição desta entrega; os valores abaixo são parâmetros iniciais de protótipo, ajustáveis no Inspector.

## Usar no nível

1. Instancie `features/player/player.tscn` em um nível com piso/obstáculos na camada **World**.
2. Adicione `features/enemies/zealot_melee.tscn` sobre o piso e/ou `features/enemies/corrupted_hologram.tscn` em uma posição flutuante.
3. Execute o nível com **F6**. Use **J/clique esquerdo** para a espada e **E/clique direito** para o gancho.

As cenas incluem formas físicas, referências, barras de vida e visuais geométricos provisórios. O centro dos corpos fica 16 px acima dos pés. A cena do jogador já pertence ao grupo `player`; alvos personalizados devem estar nesse grupo e ter corpo na camada Player. Configure sua `Hurtbox` na camada PlayerHurtbox para receber ataques.

## Arquivos e composição

| Arquivo | Responsabilidade |
| --- | --- |
| `features/enemies/enemy_base.gd` | Vida, barra, detecção, dano, recuo, gancho e morte |
| `features/enemies/zealot_melee.gd` | Patrulha, preparação, investida e recuperação |
| `features/enemies/corrupted_hologram.gd` | Transparência, disparos e partículas de glitch |
| `features/combat/ranged/energy_projectile.gd` | Trajetória instável, colisão, dano e expiração |

Os inimigos herdam de `enemy_base.tscn`:

```text
EnemyBase (CharacterBody2D)
├── CollisionShape2D
├── Visuals (Node2D)
│   ├── Placeholder (Polygon2D)
│   └── Facing (Polygon2D)
├── HealthBar (ProgressBar)
├── Hurtbox (Area2D + Hurtbox)
│   └── CollisionShape2D
├── VisionArea (Area2D)
│   └── CollisionShape2D
└── SightRay (RayCast2D)

ZealotMelee acrescenta:
├── MeleeHitbox (Area2D + Hitbox)
│   └── CollisionShape2D
└── GroundRay (RayCast2D)
```

As referências exportadas são atribuídas nas cenas. `EnemyBase` executa **um** `move_and_slide()` por ciclo. Subclasses usam `_update_behavior(delta)`, `_after_move()`, `_on_interrupted()` e `_on_death()`.

## Percepção, vida e integração

- `VisionArea` é circular, com visão em 360°. `vision_radius` cria uma forma independente por instância.
- `SightRay` testa World + Player, exigindo que o primeiro corpo atingido seja o alvo. Estar na área não basta para enxergar através de uma parede.
- O alvo atual é mantido enquanto visível; caso contrário, a base procura o candidato visível mais próximo. Saída da área, obstrução e remoção do alvo limpam a referência.
- `Hurtbox.receive_hit(...)` continua sendo a entrada do dano. Equipes, invulnerabilidade e deduplicação dos golpes seguem os componentes de combate existentes.
- O dano atualiza a barra e emite `health_changed(current, maximum)`. A recuperação padrão de **0,15 s** interrompe ataques e rejeita novos impactos. A transparência do holograma é somente visual.
- Vida zero bloqueia ações imediatamente e emite `defeated()` uma vez. A remoção e a criação de efeitos acontecem de forma diferida, fora dos callbacks de colisão.
- `apply_grapple_pull(pull_velocity)` guarda a intenção do gancho, aplicada depois da IA e antes do movimento. O recuo de dano também é preservado nesse passo. As cenas entram no grupo `grapple_enemies` automaticamente.
- Sinais disponíveis: `health_changed`, `target_changed(current: Node2D)` e `defeated`. Para sincronização inicial de interfaces externas, leia `health` e `max_health` após `_ready()`.

### Camadas físicas

| Nó/consulta | Camada | Máscara |
| --- | --- | --- |
| Corpo inimigo | Enemies = 4 | World = 1 |
| Hurtbox inimiga | EnemyHurtbox = 32 | 0 |
| VisionArea | 0 | Player = 2 |
| SightRay | — | World + Player = 3 |
| GroundRay | — | World = 1 |
| MeleeHitbox | 0 | PlayerHurtbox = 16 |
| Raio do projétil | — | World + PlayerHurtbox = 17 |

## Fanático corpo a corpo

`PATROL → WINDUP → CHARGE → RECOVERY → PATROL`.

- Patrulha a **65 px/s**, até **120 px** para cada lado da posição inicial. Inverte em paredes, limites e bordas detectadas pelo `GroundRay`.
- Ao avistar o jogador, prepara por **0,3 s**. Perder a visão durante a preparação cancela a investida.
- Investe a **340 px/s**, por até **0,8 s**, na direção fixada no início do ataque. Não persegue mudanças de direção durante a investida.
- A hitbox só fica ativa na investida. Um acerto causa **18** de dano (`zealot_melee`), aplica recuo e encerra o golpe.
- Parede, borda ou término da duração encerram a investida; recuperação padrão de **0,7 s**. Dano recebido também interrompe o ataque.
- `patrol_distance` mede distância à origem de nascimento, inclusive após um puxão ou uma investida.

## Holograma corrompido

- Sentinela flutuante com **40 PV**, gravidade zero e visão de **520 px**. O fanático usa **60 PV** e visão de **360 px**.
- Oscila a transparência de `Visuals` entre **0,2 e 0,85**, a **2,5 Hz**, sem alterar a barra ou as colisões.
- Prepara cada disparo por **0,35 s** e aguarda **1,4 s** entre o disparo e a próxima preparação. Perder a linha de visão ou receber dano interrompe a preparação.
- Mira na posição atual do jogador, com dispersão aleatória de **±9°**. `projectile_scene` pode ser substituída por outra cena com raiz `EnergyProjectile`.
- Emite `projectile_fired(projectile)` após adicionar o disparo ao nível.
- Ao morrer, gera **36 partículas** CPU ciano/magenta, com explosão radial e desaparecimento em **0,65 s**. O efeito é independente do inimigo e se remove ao terminar.

## Projétil de energia

`energy_projectile.tscn` tem raiz `Node2D`; a colisão é calculada pelo script, sem depender de sinais de sobreposição de uma `Area2D` rápida.

- Velocidade **300 px/s**, vida útil **3 s**, dano **12** (`unstable_energy`) e recuo de **120 px/s** na direção do tiro.
- Oscilação transversal de amplitude **12 px**, frequência **5 Hz** e fase aleatória. Com amplitude zero, a trajetória é reta.
- A colisão usa o ponto central varrido do início ao fim de cada passo físico. O primeiro World/Hurtbox atingido consome o projétil, inclusive se nascer dentro da parede ou se a vítima rejeitar o dano por dash.
- `Hurtbox.receive_hit()` aplica o contrato de equipes e invulnerabilidade; não há acesso direto à vida do jogador.
- O projétil é irmão do atirador e continua viajando se ele morrer. Referências à fonte removida são convertidas para `null` ao entregar o impacto.
- O sinal `impacted(collider)` informa colisões; expiração sem contato apenas remove o nó.

Para criar manualmente (em `_ready()` ou em chamada diferida fora de callbacks de colisão):

```gdscript
var shot := preload("res://features/combat/ranged/energy_projectile.tscn").instantiate() as EnergyProjectile
shot.configure(self, global_position.direction_to(target.global_position))
get_parent().add_child(shot)
shot.global_position = global_position
```

## Verificação

```bash
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/integration/enemies_test.gd
godot --headless --path . --script res://tests/integration/combat_prosthetics_test.gd
godot --headless --path . --script res://tests/integration/player_controller_test.gd
```

O teste dos inimigos usa física real para verificar visão obstruída/fora de alcance, remoção do alvo, espada e barra, equipes, recuperação, recuo, gancho, patrulha, investida, parede fina, dash, fonte removida, oscilação/expiração do projétil, disparos do holograma e ciclo de vida das partículas.
