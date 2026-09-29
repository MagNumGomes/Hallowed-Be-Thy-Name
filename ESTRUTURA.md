# Estrutura de diretórios

Organização por domínio: cenas, scripts e recursos específicos de uma funcionalidade ficam próximos. Sistemas realmente reutilizáveis ficam em `core/`; arquivos artísticos compartilhados ficam em `assets/`.

**Legenda:** `[atual]` existe nesta entrega; `[planejado]` será criado quando o módulo correspondente começar. A árvore é um mapa da arquitetura, não uma lista de funcionalidades implementadas.

```text
HallowedBeThyName/
├── .gitignore                          [atual]
├── project.godot                       [atual] configuração mínima, sem cena principal
├── README.md                           [atual]
├── MANUAL_DEV.md                       [atual]
├── ESTRUTURA.md                        [atual]
├── assets/                            [planejado]
│   ├── art/                            sprites, tilesets e interfaces
│   ├── audio/                          música, ambientes e efeitos
│   └── fonts/
├── core/                              [atual]
│   ├── state_machine/                  [atual] state.gd e state_machine.gd
│   └── components/                     [planejado] HealthComponent, Hitbox e Hurtbox
├── features/
│   ├── prosthetics/
│   │   ├── components/
│   │   │   ├── prosthetic_base.gd       [atual] estado e desgaste de uma prótese
│   │   │   └── grappling_hook_prosthetic.gd [atual] gancho mecânico
│   │   ├── shaders/                    [atual] prosthetic_corrosion.gdshader
│   │   ├── resources/                  [planejado] definições .tres/.gd
│   │   ├── abilities/                  [planejado] execução de habilidades
│   │   └── scenes/                     [planejado] montagem dos módulos
│   ├── player/                        [atual]
│   │   ├── player.tscn
│   │   ├── player.gd
│   │   └── states/                     [atual] player_state, idle, run, jump, dash, attack
│   ├── combat/                        [atual]
│   │   ├── components/                [atual] hitbox.gd e hurtbox.gd
│   │   └── ranged/                    [atual] energy_projectile.gd/.tscn
│   ├── enemies/                       [atual] enemy_base, zealot_melee, corrupted_hologram (.gd/.tscn)
│   ├── memories/                      [atual]
│   │   ├── scenes/                     [planejado]
│   │   ├── controllers/                [atual] decay_effects_example.gd
│   │   └── shaders/                    [atual] glitch_memory.gdshader
│   └── ui/                            [planejado]
│       ├── hud/
│       └── menus/
├── world/                             [atual]
│   ├── levels/                        [atual] level_manager.gd e level_trigger.gd
│   ├── interactables/                 [planejado]
│   └── transitions/                   [planejado]
├── rendering/                         [planejado]
│   ├── shaders/                        efeitos compartilhados .gdshader
│   ├── includes/                       funções comuns .gdshaderinc
│   └── materials/                      ShaderMaterial .tres
├── tests/                             [atual]
│   ├── unit/                          [planejado]
│   └── integration/                   [atual] player_controller_test, combat_prosthetics_test, enemies_test, level_manager_test
├── docs/                              [atual]
│   ├── player_setup.md                [atual] configuração e contratos do jogador
│   ├── enemy_setup.md                 [atual] montagem, contratos e testes dos inimigos
│   ├── shader_setup.md                [atual] shaders e controle em tempo real
│   ├── design/                         GDD e decisões de design
│   └── adr/                            registros de decisões arquiteturais
└── builds/                            [planejado, ignorado pelo Git]
```

## Convenções

- Arquivos e diretórios em `snake_case`; classes GDScript em `PascalCase`.
- Nós de cenas em `PascalCase`; funções, variáveis e sinais em `snake_case`.
- Caminhos internos sempre relativos a `res://`, sem caminhos absolutos locais.
- Versionar `.tscn`, `.tres`, `.gd`, `.gdshader`, `project.godot` e arquivos `.uid` gerados pelo Godot. Não versionar `.godot/`.
- Não criar diretórios vazios apenas para reproduzir a árvore: o Git não os rastreia e cada módulo será introduzido com seus arquivos reais.
- Usar Git LFS quando forem adicionados arquivos binários grandes; definir as regras em `.gitattributes` nessa etapa.
