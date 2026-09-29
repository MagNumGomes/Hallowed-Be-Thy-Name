# Controlador do jogador — Godot 4.3+

A cena pronta está em `res://features/player/player.tscn` (equivalente à `Player.tscn` solicitada, usando `snake_case` conforme a arquitetura). Abra-a para editar o controlador ou instancie-a em uma cena de nível.

## Montagem no editor

```text
Player (CharacterBody2D)                  player.gd
├── CollisionShape2D                      CapsuleShape2D: raio 10, altura 32
├── Visuals (Node2D)
│   └── Placeholder (Polygon2D)           substituir pelo sprite/animações
├── StateMachine (Node)                   core/state_machine/state_machine.gd
│   ├── Idle (Node)                       states/idle_state.gd
│   ├── Run (Node)                        states/run_state.gd
│   ├── Jump (Node)                       states/jump_state.gd
│   ├── Dash (Node)                       states/dash_state.gd
│   └── Attack (Node)                     states/attack_state.gd
├── SwordHitbox (Area2D + CollisionShape2D)
├── Hurtbox (Area2D + CollisionShape2D)
├── GrappleCable (Line2D)
└── ProstheticSlots (Node)
    └── GrapplingHook (Node)
```

1. Anexe os scripts acima. Mantenha os nomes **Idle**, **Run**, **Jump**, **Dash** e **Attack**, usados como destinos das transições.
2. No Inspector de **Player**, atribua `state_machine`, `sword_hitbox`, `hurtbox` e `grappling_hook`. Atribua Player como `source` da espada, `receiver` da hurtbox e `carrier` do gancho; atribua GrappleCable como `cable`. Tudo já está configurado em `player.tscn`.
3. No Inspector de **StateMachine**, arraste **Idle** para `initial_state`. As referências físicas dos estados são injetadas automaticamente em `Player._ready()` antes de `start()`.
4. Use **Motion Mode = Grounded**, **Up Direction = (0, -1)** e **Floor Snap Length = 4**. O personagem usa camada 2 (`Player`) e máscara 1 (`World`). O piso precisa estar na camada 1 e ter colisão.
5. Em **Project Settings → Input Map**, configure as ações abaixo (já incluídas em `project.godot`). Para controle, adicione eventos de joystick às mesmas ações.

| Ação | Entrada padrão |
| --- | --- |
| `move_left` | A / seta esquerda |
| `move_right` | D / seta direita |
| `jump` | Espaço |
| `dash` | Shift |
| `attack` | J / botão esquerdo do mouse |
| `grapple` | E / botão direito do mouse; mira pelo mouse |

6. Crie uma cena `Node2D` de teste, instancie `player.tscn` em `(300, 200)` e adicione um `StaticBody2D` em `(500, 400)` com `CollisionShape2D` retangular de tamanho `(1000, 40)`. Execute essa cena com **F6**. A cena do jogador isolada não possui piso nem câmera; ela cairá se executada sozinha.

Os parâmetros de movimento, salto e dash ficam no Inspector de Player. Unidades: pixels, segundos e pixels por segundo. A gravidade é configurada no jogador, independente da gravidade global para corpos rígidos.

## Contratos e comportamento

- `State` é a interface genérica; `PlayerState` a especializa com `body: CharacterBody2D` e `player: Player`. Ambas são bases abstratas **por contrato**, com métodos virtuais herdados `enter(previous_state)`, `exit()`, `handle_input(event)`, `update(delta)` e `physics_update(delta)`. Godot 4.3 não oferece `@abstract`.
- A máquina é iniciada explicitamente, registra os filhos diretos `State` e expõe `current_state`, `previous_state` e `state_changed(previous, current)`. Não remova/reparentalize os estados após iniciar. Para remover nós durante sinais, use `queue_free()`, nunca `free()` imediato.
- Estados chamam `request_transition(&"Nome")`. A máquina ignora pedidos de estados inativos, destinos inválidos e autotransições. Durante um callback, aceita o primeiro pedido válido e o aplica depois do retorno. Durante `enter`, `exit` e `state_changed`, rejeita transições reentrantes. Se um observador precisar reagir com outra transição, use `call_deferred()` e revalide o contexto.
- `transition_to()` retorna se o pedido foi aceito; `enter()` recebe o estado anterior, inicialmente `null`. Estados não escrevem diretamente o estado atual.
- Player amostra entradas e atualiza temporizadores na física, chama `state_machine.physics_update(delta)` e executa `move_and_slide()` **uma vez**. `update()` é encaminhado em `_process()` para apresentação; `handle_input()` recebe eventos não consumidos. As ações de movimento usam polling na física.
- Idle/Run aceleram e desaceleram. Jump representa tanto subida quanto queda. Ao sair de uma borda, há **0,12 s** de coyote time; saltar consome a janela. Soltar Espaço durante a subida aumenta a gravidade e reduz a altura; a queda tem multiplicador próprio e velocidade terminal. Não há salto duplo nem jump buffer.
- Dash tem prioridade sobre salto simultâneo, segue a última direção horizontal, dura **0,16 s**, suspende gravidade e não atravessa paredes. Pode ser usado no ar. Seu cooldown de **0,45 s** começa na saída, inclusive se interrompido; a precisão temporal é a do ciclo físico.
- `Dash.exit()` sempre remove sua invulnerabilidade e limita o impulso horizontal à velocidade de corrida. Paredes bloqueiam o corpo normalmente, sem encerrar antecipadamente o temporizador.

### Integração com dano, próteses e animação

`player.is_invulnerable()` informa a proteção do dash, recuperação de impacto e vida esgotada; `dash_invulnerability_changed(active)` permite feedback visual específico do dash. A hurtbox já consulta esse getter **antes** de emitir o impacto:

```gdscript
if player.is_invulnerable():
	return
# Aceitar impacto e notificar o receptor.
```

A proteção não desativa o `CollisionShape2D` nem altera camadas do corpo. Player aplica vida e recuo, e expõe `health_changed` e `defeated`. Animações podem observar `state_changed` e `Attack.strike_started`; não precisam controlar a física. Montagem dos inimigos, camadas, combo, consumo/reparo e trava do gancho estão na [seção 8 do manual](../MANUAL_DEV.md#8-combate-híbrido-e-gancho-mecânico).

## Verificação

```bash
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/integration/player_controller_test.gd
godot --headless --path . --script res://tests/integration/combat_prosthetics_test.gd
```

O teste usa colisões reais e entradas simuladas: inicialização/transições seguras, estado anterior, corrida/parada, pouso, salto no coyote time, prevenção de salto duplo, gravidade variável, velocidade terminal, dash, cooldown e limpeza da invulnerabilidade por término/interrupção.

Importação e teste de integração executados com **Godot 4.3 stable**, em modo headless, com **zero falhas**.

No editor, verifique também salto curto/longo, salto após expirar o coyote, dash contra paredes e troca de direção antes do dash.
