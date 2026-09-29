# Manual de desenvolvimento

## 1. Escopo e princípios

Este documento consolida a base técnica de **Hallowed Be Thy Name**, direcionada à demo vertical **Torre dos Combatentes Esquecidos**. Estão implementados próteses, jogador, combate, inimigos, shaders e gerenciamento local de nível. A cena jogável da torre, HUD do jogador, arte/áudio e narrativa finais ainda precisam ser montados. Consulte a árvore real e os comandos completos no [README](README.md).

### Responsabilidade única e composição

- **Jogador:** coordena entrada, movimento e estados.
- **Estado de movimento:** calcula a intenção de movimento daquele estado.
- **Prótese:** mantém durabilidade e resolve ativação, desgaste e reparo.
- **Habilidade:** executa o efeito aprovado, como disparar, golpear ou interagir.
- **Componente de vida:** recebe dano e gerencia vida; não controla durabilidade de próteses.
- **HUD:** observa dados e atualiza apresentação.
- **Controlador de memória:** coordena entrada/saída de flashbacks e seus efeitos.
- **LevelManager:** mantém checkpoint, coordena respawn/transições locais e apresenta glitch por sala.
- **LevelTrigger:** identifica entrada do jogador em volumes de checkpoint, memória, portal ou queda.

Preferir nós compostos e recursos de configuração a cadeias extensas de herança. `ProstheticBase` é um componente utilizável diretamente, apesar do sufixo `Base`.

## 2. Jogador: máquina de estados

Estrutura implementada do jogador (`Fall`, `Hurt` e `HealthComponent` separado são extensões futuras; vida e reação ao impacto estão no controlador):

```text
Player (CharacterBody2D)
├── CollisionShape2D
├── Visuals (Node2D)
├── StateMachine (Node)
│   ├── Idle
│   ├── Run
│   ├── Jump
│   ├── Dash
│   └── Attack
├── SwordHitbox (Area2D + Hitbox)
├── Hurtbox (Area2D + Hurtbox)
├── GrappleCable (Line2D)
└── ProstheticSlots (Node)
    └── GrapplingHook (Node + GrapplingHookProsthetic)
```

O contrato de `State` em `core/state_machine/state.gd` contém `enter(previous_state)`, `exit()`, `handle_input(event)`, `update(delta)` e `physics_update(delta)`. `PlayerState` injeta as referências ao controlador e ao `CharacterBody2D`. As bases são abstratas por contrato para compatibilidade com Godot 4.3. Nesta entrega, `Jump` também implementa queda; `Fall` ainda não é um estado separado.

- `StateMachine` guarda o estado ativo, valida transições e chama `exit()`/`enter()`.
- Estados solicitam transições; não modificam diretamente o estado ativo.
- Referências ao jogador são injetadas na montagem; evitar caminhos absolutos e buscas repetidas na árvore.
- O jogador chama a atualização física da máquina e, em seguida, `move_and_slide()` **uma única vez por ciclo físico**.
- Não duplicar `_physics_process()` nos estados: a máquina encaminha explicitamente a atualização.
- Separar posteriormente locomoção e ações em máquinas distintas caso combinações como correr e disparar tornem uma única máquina complexa demais.

As ações `move_left`, `move_right`, `jump`, `dash`, `attack` e `grapple` estão configuradas no Input Map. Não há dependência de entrada no componente de prótese. A cena pronta, os contratos de transição, a integração da invulnerabilidade e as instruções completas estão em [Configuração do jogador](docs/player_setup.md). O combate híbrido é descrito na seção 8.

## 3. Próteses: Observer com sinais tipados

### Fluxo de dependências

```text
Entrada → controlador de habilidade → try_activate()
                                       │
                                       ├── activated → efeito da habilidade
                                       ├── durability_changed → HUD / áudio / VFX
                                       └── broken → feedback de quebra
```

O controlador valida cooldown, energia, alvo e permissões do estado **antes** de chamar `try_activate()`. O componente cuida apenas de sua própria disponibilidade e durabilidade.

Uma ativação aceita é um compromisso de uso: o custo é consumido mesmo se o ataque errar. Um erro de execução no observador não reverte o desgaste. O efeito deve ser iniciado por **um único caminho**, preferencialmente pelo sinal `activated`, para evitar execução duplicada.

Não usar um barramento global para eventos locais. O nó que monta a cena conecta a prótese aos interessados. Autoloads futuros ficam reservados a serviços de ciclo de vida global, como persistência e transições.

### Contrato de `ProstheticBase`

Arquivo: `res://features/prosthetics/components/prosthetic_base.gd`.

| API | Contrato |
| --- | --- |
| `max_durability` | Configuração inteira, mínimo 1; copiada para o estado interno em `_ready()` |
| `degradation_per_activation` | Configuração inteira, mínimo 0; copiada em `_ready()` |
| `get_durability()` | Integridade atual; antes de `_ready()`, retorna 0 |
| `get_max_durability()` | Máximo efetivo; antes de `_ready()`, retorna 0 |
| `can_activate()` | Verdadeiro se inicializada, íntegra e fora de uma transação de sinais |
| `is_broken()` | Verdadeiro somente após inicialização e com durabilidade zero |
| `try_activate() -> bool` | Aceita ou rejeita uso; aplica desgaste imediatamente se aceito |
| `repair(amount: int) -> bool` | Restaura até o máximo; retorna falso se não houver mudança |

Durabilidade usa unidades inteiras para evitar resíduos de ponto flutuante na detecção de quebra. Configurações inválidas são normalizadas em `_ready()` com aviso. O Inspector também limita os valores. Alterar os campos exportados após a inicialização não altera a instância em execução.

Regras iniciais de balanceamento:

1. A prótese nasce com durabilidade cheia.
2. Qualquer integridade positiva permite uma última ativação, mesmo quando o custo excede o restante.
3. A ativação que chega a zero ainda produz seu efeito; usos posteriores são rejeitados.
4. Custo zero permite usos sem desgaste, mas não reativa uma prótese quebrada.
5. Quebra não remove o nó: ele permanece disponível para consulta e reparo.
6. Reparo é uma operação técnica; local permitido, consumíveis e custo pertencem a outro sistema.
7. Corrosão passiva, inventário, persistência e troca de módulos serão desenvolvidos posteriormente.

### Sinais e ordem dos eventos

```gdscript
signal activated(remaining_durability: int)
signal durability_changed(current_durability: int, maximum_durability: int)
signal broken()
```

Em uma ativação aceita, o estado interno é atualizado **antes** das notificações. A ordem é:

1. `activated`, inclusive no último uso.
2. `durability_changed`, somente se o valor mudou.
3. `broken`, apenas na transição de durabilidade positiva para zero.

Ativações rejeitadas não emitem sinais. Reparos emitem apenas `durability_changed`. Após um reparo positivo, a prótese pode voltar a quebrar e emitir um novo `broken`.

Sinais Godot são síncronos por padrão. Durante a notificação, consultas leem o estado já atualizado, mas novas chamadas de ativação/reparo são rejeitadas para impedir recursão e inconsistência na ordem dos eventos. Se uma reação precisar modificar a prótese, agende-a com `call_deferred()` e valide novamente sua disponibilidade. Observadores devem usar `queue_free()`, nunca `free()` imediato, se precisarem remover nós envolvidos na emissão.

### Exemplo de integração futura

Trecho para um controlador cujo filho `Prosthetic` possui o script base:

```gdscript
extends Node

@onready var prosthetic: ProstheticBase = $Prosthetic

func _ready() -> void:
    prosthetic.activated.connect(_on_prosthetic_activated)
    prosthetic.durability_changed.connect(_on_durability_changed)
    prosthetic.broken.connect(_on_prosthetic_broken)
    # Filhos já concluíram _ready(); sincronize o estado inicial explicitamente.
    _on_durability_changed(
        prosthetic.get_durability(), prosthetic.get_max_durability()
    )

func request_ability() -> bool:
    # Validar aqui as condições externas: cooldown, energia e estado do jogador.
    return prosthetic.try_activate()

func _on_prosthetic_activated(remaining_durability: int) -> void:
    print("Executar habilidade. Integridade restante: ", remaining_durability)

func _on_durability_changed(current: int, maximum: int) -> void:
    print("Atualizar HUD: ", current, "/", maximum)

func _on_prosthetic_broken() -> void:
    print("Reproduzir feedback de quebra")
```

Não há sinal inicial em `_ready()`: consumidores conectados posteriormente devem consultar os getters. Ao substituir um módulo, desconectar o anterior, conectar o novo e sincronizar sua apresentação.

## 4. Dados e recursos

Nesta entrega, parâmetros ficam no Inspector para manter o componente autocontido. Quando houver múltiplos modelos, introduzir um `ProstheticDefinition extends Resource` com identificador estável, nome, ícone, durabilidade máxima, custo e referências de habilidade.

Recursos `.tres` podem ser compartilhados entre instâncias. Portanto, **durabilidade corrente pertence ao nó de cada prótese**, nunca ao recurso de definição. Dois braços com a mesma definição devem se desgastar independentemente.

Persistência futura armazenará identificador do módulo e durabilidade atual. A carga deverá validar dados e respeitar limites; não serializar referências de nós como identidade permanente.

## 5. Shaders e memórias corrompidas

- Efeitos 2D usam `shader_type canvas_item` em arquivos `.gdshader`.
- Glitches exclusivos dos flashbacks ficam em `features/memories/shaders/`.
- Efeitos genéricos futuros ficarão em `rendering/shaders/`; funções compartilhadas em `.gdshaderinc` (diretório ainda não criado).
- Presets de material ficam em `.tres`, evitando grandes blocos de shader embutidos em cenas.
- O controlador de memória anima uniforms como `glitch_intensity`, `scanline_strength` e `distortion_amount`; o shader apenas apresenta o efeito.
- Se um material precisar de valores diferentes por instância, duplicá-lo ou habilitar **Local To Scene** antes de modificá-lo.
- Para pós-processamento, usar `sampler2D` com `hint_screen_texture`, conforme o Godot 4, e verificar a captura da tela e a ordem dos `CanvasLayer`.
- Manter o HUD fora da camada afetada quando a legibilidade exigir. Validar efeitos no renderizador Compatibility selecionado.
- Prever intensidade configurável para glitches e flashes, sem acoplar essa preferência à lógica narrativa.

Uma intensidade zero deve produzir apresentação sem degradação. Efeitos visuais não controlam dano, duração de habilidade ou transição narrativa.

Implementados: `features/memories/shaders/glitch_memory.gdshader`, `features/prosthetics/shaders/prosthetic_corrosion.gdshader` e o controlador de exemplo `features/memories/controllers/decay_effects_example.gd`. Consulte [Shaders de decadência](docs/shader_setup.md) para montagem das camadas, parâmetros e integração com `durability_changed`.

## 6. Convenções de implementação

- GDScript tipado, indentação por tabulação e documentação pública com `##`.
- Sinais no passado para fatos concluídos: `activated`, `broken`, `durability_changed`.
- Prefixo `_` identifica detalhes internos; GDScript não impõe privacidade real.
- Parâmetros de balanceamento exportados; referências entre módulos fornecidas pela montagem da cena.
- Usar `_physics_process(delta)` para movimento e `_process(delta)` apenas quando necessário para apresentação.
- A base de durabilidade é orientada a eventos e não exige atualização por frame. O gancho concreto recebe `physics_update(delta)` do portador.
- Evitar dependências circulares: a base não conhece jogador, HUD, arma ou mundo. O gancho conhece somente seu portador `CharacterBody2D`, cabo e contratos de alvos.

## 7. Verificação do componente

Importação e testes de integração do controlador e combate foram executados com Godot 4.3 stable, em modo headless, com zero falhas. A tabela abaixo também serve como roteiro de verificação manual dos contratos da base.

Depois de importar, crie uma cena temporária com um nó raiz `Node`, anexe o componente e execute com **F6**. Para exercitar chamadas, use um controlador temporário como no exemplo acima e execute o roteiro a partir do `_ready()` do pai, quando a prótese já estiver inicializada.

| Cenário | Resultado esperado |
| --- | --- |
| Inicialização padrão | Durabilidade 100; máximo 100; nenhum sinal inicial |
| Primeiro uso com custo 10 | Retorna verdadeiro; durabilidade 90; `activated(90)` e `durability_changed(90, 100)` |
| Décimo uso acumulado | Durabilidade 0; `activated`, `durability_changed`, `broken`, nessa ordem |
| Uso após quebra | Retorna falso; nenhum evento adicional |
| Máximo 5 e custo 10 | Um uso válido, durabilidade 0 e exatamente um `broken` |
| Custo 0 | Uso válido; apenas `activated`; durabilidade preservada |
| Reparo de 20 após quebra | Durabilidade 20; `durability_changed`; uso volta a ser permitido |
| Reparo acima do máximo | Durabilidade limitada ao máximo |
| Reparo zero/negativo ou com integridade cheia | Retorna falso; não emite sinal |
| Ativação/reparo dentro de um callback síncrono | Retorna falso; sem recursão ou eventos extras |
| Duas instâncias | Desgastar uma não altera a outra |
| Consulta/uso antes de `_ready()` | Durabilidade 0; `is_broken()` falso; ativação e reparo rejeitados |

O teste `tests/integration/combat_prosthetics_test.gd` verifica o desgaste do gancho integrado, incluindo erro de disparo, último uso, trava e reparo.

## 8. Combate híbrido e gancho mecânico

### Entrada e montagem

A cena `features/player/player.tscn` já inclui todas as referências e colisores. **J / botão esquerdo** (`attack`) inicia a espada; novos toques durante o golpe atual agendam o próximo. **E / botão direito** (`grapple`) dispara na direção do mouse; soltar libera a ligação. O gancho pode ser usado durante o combo e no ar. Dash e reação a dano cancelam o gancho; não permitem disparar durante sua proteção.

| Camada física | Valor de bit | Uso |
| --- | --- | --- |
| 1 — World | 1 | Paredes e pisos; bloqueiam o gancho |
| 2 — Player | 2 | Corpo do protagonista |
| 3 — Enemies | 4 | Corpos de inimigos detectáveis pelo gancho |
| 4 — GrappleAnchors | 8 | Corpos estáticos de âncoras |
| 5 — PlayerHurtbox | 16 | Hurtbox do protagonista |
| 6 — EnemyHurtbox | 32 | Hurtboxes de inimigos |

Hitboxes usam camada 0 e máscara da hurtbox adversária (espada: 32; inimigos: 16). Hurtboxes usam máscara 0 e permanecem detectáveis (`monitorable = true`). Configure um `CollisionShape2D` em cada área. O gancho consulta corpos com máscara **13** (World + Enemies + GrappleAnchors), excluindo o portador; hurtboxes não bloqueiam o raio.

### Hitbox e Hurtbox

- `features/combat/components/hitbox.gd`: `begin_strike(amount, kind, impulse, direction)` abre um golpe; `end_strike()` o fecha. A direção espelha o recuo horizontal. `area_entered` detecta entradas e `scan_overlaps()` cobre quem já está dentro da área. O controlador chama essa varredura após atualizar a física.
- Cada `receiver` recebe no máximo um impacto aceito por golpe, mesmo com várias hurtboxes. Sem `receiver`, a deduplicação é por área. Um impacto rejeitado por invulnerabilidade pode ser tentado novamente enquanto o golpe estiver ativo.
- `features/combat/components/hurtbox.gd`: `receive_hit(damage, damage_type, knockback, source, source_team) -> bool` rejeita a própria fonte, equipes iguais não vazias e invulnerabilidade. Consulta `receiver.is_invulnerable()` quando disponível.
- Um impacto aceito emite `impacted(damage: float, damage_type: StringName, knockback: Vector2, source: Node)`. O receptor aplica vida e recuo; a área não movimenta corpos. `Hitbox.hit_confirmed(hurtbox)` permite feedback.
- Tipos atuais: `nanotube_slash` e `nanotube_heavy`. São identificadores para resistências/feedback futuros, sem multiplicadores implícitos.
- `Player` aplica dano, emite `health_changed(current, maximum)`, interrompe o combo e preserva o impulso no próximo ciclo físico. A recuperação padrão dura **0,18 s**, suspende ações e rejeita novos impactos. Com vida zero, emite `defeated()` e bloqueia ações; respawn pertence ao nível.

### Combo da espada de nanotubos

`features/player/states/attack_state.gd` implementa **leve 1 → leve 2 → pesado**, com parâmetros exportados:

| Golpe | Dano | Preparação | Janela ativa | Recuperação |
| --- | --- | --- | --- | --- |
| Leve 1 / 2 | 12 | 0,10 s | 0,12 s | 0,20 s |
| Pesado | 30 | 0,22 s | 0,18 s | 0,35 s |

Cada golpe aceita um novo toque em qualquer fase para agendar o seguinte. Segurar o botão não repete nem completa o combo automaticamente; não há quarto golpe. A direção fica fixa por golpe e pode mudar no início do próximo. O personagem desacelera horizontalmente e mantém gravidade. Dash tem prioridade e cancela a sequência. Ao sair de `Attack`, a hitbox e o buffer sempre são limpos. Sem continuação, retorna a Idle/Run no piso ou Jump no ar. `strike_started(index)` usa índices **0, 1, 2** para integração de animação/áudio; o dano depende da janela física, não da animação.

### Gancho: alvos, desgaste e trava

`features/prosthetics/components/grappling_hook_prosthetic.gd` herda de `ProstheticBase`. A entrada pública da habilidade é **`fire_at(world_position) -> bool`**; não chamar `try_activate()` diretamente para disparar.

- Disparo instantâneo por raio, alcance padrão **480 px**, cooldown **0,35 s**, puxão **550 px/s**, duração máxima **1,5 s**, distância de parada **28 px**.
- **Inimigo:** `CharacterBody2D` na camada Enemies e grupo `grapple_enemies`. O gancho define a velocidade em direção ao portador. O inimigo deve executar seu próprio `move_and_slide()` uma vez por ciclo. Se sua IA sobrescrever velocidade, implemente `apply_grapple_pull(pull_velocity: Vector2)` para guardar e aplicar essa intenção antes do movimento.
- **Ruína high-tech:** `StaticBody2D` no grupo `grapple_anchors`, com forma física na camada World ou GrappleAnchors. O portador é puxado até o ponto local atingido. Um corpo comum bloqueia o raio, mas não serve de âncora.
- A ligação termina ao soltar entrada, receber dano, iniciar dash, atingir a distância de parada, exceder alcance/duração, perder o alvo ou encontrar obstáculo. O cabo `Line2D` acompanha a ligação.
- `physics_update(delta)` é conduzido pelo controlador **depois do estado e antes de `move_and_slide()`**. O gancho não move corpos diretamente nem duplica o passo físico.
- Cada disparo aceito consome **10 de integridade** de um máximo inicial **100**, inclusive se errar ou atingir uma parede. Direção nula, cooldown, ligação existente e integridade zero rejeitam o disparo sem custo.
- A **trava de sobreaquecimento/corrupção** corresponde a `is_broken()`: integridade zero impede novos usos, sem recuperação automática por tempo. O disparo que esgota a integridade permanece válido. `repair(amount)` positivo restaura a disponibilidade, respeitando cooldown e ligação existente. Não há medidores separados de calor/corrupção nesta versão.
- Sinais herdados: `activated`, `durability_changed`, `broken`. Sinais concretos: `fired(end_position, attached)` após resolver o raio e `released()` ao desfazer uma ligação válida. O efeito é iniciado somente por `fire_at`; não conectar `activated` a um segundo disparo.

Exemplo de inimigo mínimo que recebe espada e puxão (configure corpo/hurtbox conforme a tabela):

```gdscript
extends CharacterBody2D

var health: float = 100.0
var _grapple_velocity: Vector2 = Vector2.ZERO
var _has_grapple_pull: bool = false
var _pending_impulse: Vector2 = Vector2.ZERO

func _ready() -> void:
    add_to_group(&"grapple_enemies")
    $Hurtbox.receiver = self
    $Hurtbox.team = &"enemy"
    $Hurtbox.impacted.connect(_on_impacted)

func apply_grapple_pull(pull_velocity: Vector2) -> void:
    _grapple_velocity = pull_velocity
    _has_grapple_pull = true

func _physics_process(_delta: float) -> void:
    # Calcular aqui a velocidade normal da IA, antes do puxão.
    if _has_grapple_pull:
        velocity = _grapple_velocity
        _has_grapple_pull = false
    velocity += _pending_impulse
    _pending_impulse = Vector2.ZERO
    move_and_slide()

func _on_impacted(amount: float, _kind: StringName,
        impulse: Vector2, _source: Node) -> void:
    health = maxf(0.0, health - amount)
    _pending_impulse += impulse
    if health <= 0.0:
        queue_free()
```

### Verificação automatizada

```bash
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/integration/player_controller_test.gd
godot --headless --path . --script res://tests/integration/combat_prosthetics_test.gd
godot --headless --path . --script res://tests/integration/enemies_test.gd
godot --headless --path . --script res://tests/integration/level_manager_test.gd
```

O teste de combate usa colisões reais para verificar janelas do combo, deduplicação por vítima, dano/tipo/recuo, cancelamento, invulnerabilidade, equipes, puxão de inimigos, âncoras, paredes, alvo removido, cooldown, desgaste ao errar, último disparo, trava e reparo. Resultado nesta entrega: **zero falhas** em ambos os testes, Godot **4.3 stable**.

## 9. Inimigos do protótipo

`EnemyBase` coordena vida/barra, `Hurtbox`, visão circular com `Area2D` + `RayCast2D`, recuo e integração com o gancho. `ZealotMelee` especializa patrulha/investida com hitbox; `CorruptedHologram` adiciona transparência, disparos instáveis e partículas CPU de morte. `EnergyProjectile` faz varredura por raio a cada passo para atingir World ou Hurtbox sem atravessar paredes finas em alta velocidade.

Cenas, parâmetros, sinais, camadas e comandos de teste estão em [Inimigos do protótipo](docs/enemy_setup.md). As subclasses especializam os hooks da base e não duplicam o movimento físico. Efeitos e projéteis ficam no nível para sobreviver à remoção do emissor.

## 10. Nível, checkpoints e transições

`world/levels/level_manager.gd` é um nó **local da cena**, não um Autoload. `world/levels/level_trigger.gd` é um `Area2D` configurável. O gerenciador cria seu próprio CanvasLayer 90 com material de memória exclusivo e retângulo preto de fade. Não necessita de `DecayEffectsExample`; use esse exemplo separadamente para corrosão e não empilhe dois pós-processamentos de memória.

### Montagem da torre

Crie uma cena `Node2D` e use esta estrutura sugerida (a cena ainda não está entregue):

```text
Tower (Node2D)
├── World (pisos/paredes StaticBody2D, camada 1)
├── Player (instância de player.tscn, com Camera2D opcional)
├── LevelManager (Node + level_manager.gd)
├── Start (Marker2D)
├── CheckpointSpawn (Marker2D)
├── RoomDestination (Marker2D)
├── Checkpoint (Area2D + level_trigger.gd + CollisionShape2D)
├── MemoryRoom (Area2D + level_trigger.gd + CollisionShape2D)
├── Exit (Area2D + level_trigger.gd + CollisionShape2D)
└── FallVolume (Area2D + level_trigger.gd + CollisionShape2D)
```

1. Atribua `LevelManager.player` e, opcionalmente, `initial_spawn = Start`. Sem marcador, a posição inicial do jogador é o fallback. O marcador não reposiciona o jogador na abertura: posicione a instância no editor.
2. Em cada gatilho, atribua `manager`, escolha `kind` e crie a forma. O script define camada **0**, máscara **2 (Player)**; mantenha `monitoring` ativo. Somente o jogador referenciado pode disparar ações.
3. **CHECKPOINT:** atribua `destination = CheckpointSpawn` e um `checkpoint_id` não vazio, único por checkpoint. O marcador deve ficar em piso seguro, fora de inimigos/volumes de queda. Ativação repetida do mesmo ID e posição não emite outro evento.
4. **MEMORY:** ajuste `memory_intensity` no Inspector. A forma deve cobrir a sala inteira. Entrada, saída, teleporte, sobreposição e remoção da área são reconciliados pela física; a maior intensidade vence. Fora das salas, o glitch é zero. `memory_effects_strength = 0` desliga a apresentação sem alterar a lógica.
5. **TRANSITION:** atribua `destination = RoomDestination`. É uma passagem entre telas da **mesma cena**, não um carregamento de `.tscn`. Posicione o destino fora dos volumes de saída para evitar reentradas. Uma Camera2D seguindo o jogador pode usar smoothing; o gerenciador o reinicia após o teleporte.
6. **RESPAWN:** use para poços/limites; não exige destino. A entrada retorna ao último checkpoint.
7. Reserve camadas inferiores a 90 para o mundo e superiores a 90 para HUD legível fora do glitch/fade. Se o HUD também deve desaparecer durante o fade, ajuste a composição antes da entrega visual.

### Contratos públicos

| API | Comportamento |
| --- | --- |
| `activate_checkpoint(id, world_position) -> bool` | Guarda ID e posição global em memória; rejeita duplicatas, ID vazio, morte e transição |
| `respawn()` | Solicita fade, retorno ao checkpoint e restauração da vida; conectado a `Player.defeated` |
| `transition_to(world_position) -> bool` | Solicita fade e teleporte, preservando vida e checkpoint; retorna aceitação, não conclusão |
| `register_memory_room(area)` | Registra sala; `LevelTrigger` faz isso automaticamente e fornece metadata `memory_intensity` |
| `transitioning` | Trava síncrona contra pedidos concorrentes |
| `memory_intensity` | Intensidade lógica das salas; multiplicada pela preferência visual no shader |

Sinais: `checkpoint_activated(id, world_position)`, `transition_started()`, `player_respawned(world_position)`, `transition_finished()` e `memory_intensity_changed(intensity)`. Observe `transition_finished` para aguardar a conclusão. `player_respawned` ocorre com a tela preta, após reposicionamento e atualização das salas.

Durante o fade, `Player.begin_level_transition()` cancela espada/gancho, zera velocidade e bloqueia processamento de ações e recebimento de dano. O teleporte é diferido para fora dos callbacks de colisão; após ele, o gerenciador aguarda a atualização física das áreas antes de revelar a tela. `Player.reset_at(position, restore_health)` limpa recuo, recuperação, dash, coyote time e inputs antigos. O estado volta a Jump, que também representa queda e retorna à locomoção ao tocar o piso.

Respawn preserva instância/conexões do jogador, durabilidade e cooldown próprio do gancho. Não recria inimigos, não remove projéteis e não salva progresso em disco. O mundo continua simulando durante o fade; o jogador permanece protegido até o fim. Checkpoints se perdem ao descarregar a cena. Não introduza persistência ou recarga de mundo por efeitos colaterais de um sinal de HUD.

## 11. Checklist de debugging

- [ ] Importar com `godot --headless --editor --path . --quit` antes das suítes; verificar erros de parser, referências exportadas e versão do Godot.
- [ ] Executar as quatro suítes da seção 8/README; conferir resumo e código de saída. Headless não comprova qualidade visual de shaders.
- [ ] Usar a árvore **Remote** e **Debug → Visible Collision Shapes**: corpo, hurtbox e volumes devem estar nas camadas/máscaras da seção 8.
- [ ] Jogador parado: conferir Input Map, `_initialized`, referências da máquina e `level_transition_active`. Não mover também pelos estados.
- [ ] Combo sem dano/repetido: conferir equipe/receiver, janela de `begin_strike`/`end_strike`, `scan_overlaps()` e limpeza ao interromper.
- [ ] Dash ou dano travados: conferir `_hit_remaining`, invulnerabilidade e saída de Dash. Após respawn, velocidade/recuo devem estar zerados e a hitbox fechada.
- [ ] Gancho falha: conferir máscara 13, grupos `grapple_enemies`/`grapple_anchors`, linha de visão, alcance, cooldown e integridade. Errar um disparo aceito também desgasta.
- [ ] Inimigo não detecta: verificar grupo `player`, área de visão, raio e bloqueios World. O holograma transparente continua vulnerável.
- [ ] Checkpoint não ativa: conferir `manager`, `destination`, ID, forma, monitoring e a referência exata do jogador. Ativar não cura nem repara.
- [ ] Respawn no lugar incorreto: conferir posição **global** do marcador, fallback inicial e último checkpoint; usar ponto sem obstáculos/volumes de queda.
- [ ] Portal dispara novamente: mover destino para fora das áreas de saída. Pedidos durante fade são descartados, não enfileirados.
- [ ] Glitch persiste: procurar outras salas sobrepostas, outro ColorRect com shader ou outro controlador alterando uniforms. Verificar preferência visual e camada 90.
- [ ] Tela preta: conferir `transitioning`, pausa da árvore e erros durante coroutine; fades respeitam a pausa normal da cena. Não remover o gerenciador no meio do fluxo para navegar de cena.
- [ ] No editor com renderização: testar entrada/saída de duas salas sobrepostas, morte em sala corrompida, queda, câmera, fade completo e opção visual zero.
- [ ] Ao reportar regressão: registrar versão, cena, passos mínimos, resultado esperado, logs e suíte que falhou.

## 12. Guia de expansão: novas próteses

1. Crie `features/prosthetics/components/<habilidade>_prosthetic.gd`, herdando `ProstheticBase`, ou componha um controlador com essa base. Use o gancho como referência de uma habilidade concreta.
2. Exporte balanceamento e referências; configure corpo, mira, efeitos e recursos na cena. Se sobrescrever `_ready()`, chame `super._ready()` para inicializar a durabilidade.
3. Defina uma entrada pública como `fire_at(target) -> bool`. Valide portador, cooldown, estado, energia e alvo **antes** de `try_activate()`. Após aceitação, cobre o custo mesmo se o efeito errar.
4. Execute o efeito por um único caminho: pelo retorno aceito **ou** pelo sinal `activated`. Não combine os dois. Preserve o último uso que esgota a integridade e rejeite usos seguintes até reparo.
5. Para habilidades contínuas, exponha `release()`/cancelamento e atualização explícita. Integre cancelamento a dano, dash, morte e `begin_level_transition`/`reset_at`; acrescente a nova referência ao controlador ou extraia um coordenador de slots quando necessário. O jogador atual conhece somente o gancho.
6. Não faça `move_and_slide()` na prótese. Forneça intenção de velocidade ao portador/alvo e mantenha um passo físico por corpo.
7. Conecte HUD/VFX a `durability_changed` e sincronize o estado inicial com getters. Materiais e durabilidade devem ser independentes por instância.
8. Acrescente testes comportamentais de último uso, rejeição sem custo, cooldown, erro de alvo, reparo e cancelamento por transição. Atualize Input Map/documentação se houver nova ação.

Para múltiplos modelos, extraia configurações imutáveis para `Resource`; não coloque integridade atual em `.tres` compartilhado. Inventário, desbloqueio e troca de slots ainda exigem implementação própria.

## 13. Guia de expansão: novos inimigos

1. Crie script e cena em `features/enemies/`, usando `EnemyBase` e a montagem de `enemy_base.tscn`. Configure `Hurtbox`, `HealthBar`, `VisionArea/CollisionShape2D`, `SightRay` e `Visuals` nas referências exportadas.
2. Use corpo na camada **4 (Enemies)**, hurtbox na **32 (EnemyHurtbox)** e equipe `enemy`. A base registra `grapple_enemies`. Se sobrescrever `_ready()`, chame `super._ready()`.
3. Implemente `_update_behavior(delta)` para decisões e velocidade desejada. Use `target` e `can_see()`; não replique aquisição de alvo ou atravesse paredes por ignorar o raio.
4. Use `_after_move()` para varredura de ataques após a física; `_on_interrupted()` para cancelar preparação/golpe; `_on_death()` para efeitos finais. **Não duplique `_physics_process()`/`move_and_slide()`**: a base já aplica gravidade, puxão e recuo.
5. Ataques corpo a corpo usam `Hitbox` com máscara 16, equipe `enemy`, fonte correta e janelas finitas. Disparos podem instanciar `EnergyProjectile`, configurar fonte/direção e adicioná-lo ao nível, para sobreviver à remoção do emissor.
6. Efeitos de morte também pertencem ao nível e devem se remover ao terminar. Não deixe hitboxes ativas após interrupção/morte.
7. Teste percepção bloqueada por parede, perda/remoção do alvo, equipe, recuperação, morte única, puxão e interrupção; acrescente casos específicos da nova IA à suíte de inimigos.
8. Instancie na torre com caminho de patrulha/posições seguros e documente parâmetros, dano e telegráficos em `docs/enemy_setup.md`.
