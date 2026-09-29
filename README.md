# Hallowed Be Thy Name

> Em um mundo que confunde tecnologia com divindade, cada poder deixa uma marca no corpo — e cada lembrança pode esconder uma mentira.

Jogo 2D de ação e suspense narrativo, com exploração metroidvania e combate inspirado em soulslikes. A primeira demo vertical tem como cenário a **Torre dos Combatentes Esquecidos**.

**Estado da entrega:** sistemas reutilizáveis, gerenciador de nível, HUD e menu principal implementados. F5 abre o menu e uma sala técnica de UI com save/load. A montagem da torre, arte, áudio e sequência narrativa ainda estão pendentes. Consulte [Interface e ancoragem](docs/ui_setup.md).

## Implementado

| Sistema | Recursos disponíveis |
| --- | --- |
| Jogador | Máquina de estados Idle/Run/Jump/Dash/Attack, aceleração, salto variável, coyote time, dash com invulnerabilidade, vida, recuo e morte |
| Combate | Combo leve → leve → pesado, janelas de dano, hitbox/hurtbox, equipes e deduplicação de impactos |
| Próteses | Durabilidade, desgaste, quebra, reparo e sinais; gancho com raio, cabo, cooldown, puxão de inimigos e deslocamento até âncoras |
| Inimigos | Base com percepção por área/linha de visão e barra de vida; fanático com patrulha/investida; holograma com disparos, transparência e partículas de morte |
| Projéteis | Energia com oscilação, vida útil e varredura para evitar atravessar paredes finas |
| Apresentação | Shaders de memória corrompida e corrosão; controlador de exemplo ligado à durabilidade |
| Nível | Checkpoints em memória, respawn automático, volumes de queda, portais entre salas da mesma cena, fade de tela, proteção durante transições e glitch por sala |
| Interface | HUD reativo, aviso de ruptura, fragmentos, menu com glitch, opções e slot JSON; sala técnica executável |
| Áudio | Autoload, buses Master/BGM/SFX/Glitch, crossfade de exploração/memória e SFX com pitch aleatório; ficheiros sonoros pendentes |

O respawn restaura a vida e limpa ações/recuo; preserva durabilidade e inimigos existentes. Portais preservam vida e checkpoint. Salas de memória sobrepostas usam a maior intensidade. O menu oferece save/load simples em JSON; o gerenciador de nível mantém checkpoints apenas em memória.

## Requisitos e execução

- **Godot 4.3+ da série 4.x**, edição padrão (sem .NET); validação automatizada em **4.3 stable**.
- Renderizador **Compatibility**, viewport 1280 × 720.
- Sem plugins ou dependências externas.

Importe `project.godot` no editor ou execute na raiz:

```bash
godot --editor --path .
```

O executável pode se chamar `godot4`; substitua `godot` pelo nome/caminho instalado. No PowerShell, use `& "C:\caminho\Godot_console.exe"` antes dos argumentos.

Use **F5** para o menu e a sala técnica de UI. Para montar a torre, siga [Configuração do jogador](docs/player_setup.md) e a [montagem do nível](MANUAL_DEV.md#10-nível-checkpoints-e-transições), e configure `game_scene` no menu.

### Controles

| Ação | Entrada |
| --- | --- |
| Movimento | A/D ou setas esquerda/direita |
| Salto | Espaço; soltar reduz a altura |
| Dash | Shift |
| Espada | J ou botão esquerdo; novos toques encadeiam o combo |
| Gancho | E ou botão direito, mirando com o mouse; soltar libera |

## Testes

Execute na raiz, importando antes para registrar classes globais:

```bash
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/integration/player_controller_test.gd
godot --headless --path . --script res://tests/integration/combat_prosthetics_test.gd
godot --headless --path . --script res://tests/integration/enemies_test.gd
godot --headless --path . --script res://tests/integration/level_manager_test.gd
godot --headless --path . --script res://tests/integration/ui_test.gd
godot --headless --path . --script res://tests/integration/audio_manager_test.gd
```

Cada suíte imprime a quantidade de falhas e retorna **0** em sucesso ou **1** em falha. A importação isolada não substitui testes comportamentais. Os testes usam cenas e colisões reais, sem framework externo. Shaders, composição de camadas e conforto visual precisam também de inspeção no editor com renderização.

**Validação desta entrega:** importação e quatro suítes executadas em Godot **4.3 stable**, modo headless, com **zero falhas**. A suíte de nível verifica checkpoint por colisão, morte/respawn único, limpeza de combate, preservação de durabilidade, portais, sobreposição/remoção de salas, preferência visual zero e volumes de queda.

## Árvore final desta entrega

Arquivos-fonte da base; `.godot/` é cache gerado e ignorado. A interface acrescenta
`features/ui/`, `core/save_game.gd`, `world/levels/ui_demo.gd/.tscn`,
`tests/integration/ui_test.gd` e `docs/ui_setup.md` à árvore abaixo.

```text
GAME/
├── .gitignore
├── project.godot
├── README.md
├── MANUAL_DEV.md
├── ESTRUTURA.md
├── core/
│   └── state_machine/
│       ├── state.gd
│       └── state_machine.gd
├── features/
│   ├── player/
│   │   ├── player.gd
│   │   ├── player.tscn
│   │   └── states/
│   │       ├── player_state.gd
│   │       ├── idle_state.gd
│   │       ├── run_state.gd
│   │       ├── jump_state.gd
│   │       ├── dash_state.gd
│   │       └── attack_state.gd
│   ├── combat/
│   │   ├── components/
│   │   │   ├── hitbox.gd
│   │   │   └── hurtbox.gd
│   │   └── ranged/
│   │       ├── energy_projectile.gd
│   │       └── energy_projectile.tscn
│   ├── prosthetics/
│   │   ├── components/
│   │   │   ├── prosthetic_base.gd
│   │   │   └── grappling_hook_prosthetic.gd
│   │   └── shaders/
│   │       └── prosthetic_corrosion.gdshader
│   ├── enemies/
│   │   ├── enemy_base.gd
│   │   ├── enemy_base.tscn
│   │   ├── zealot_melee.gd
│   │   ├── zealot_melee.tscn
│   │   ├── corrupted_hologram.gd
│   │   └── corrupted_hologram.tscn
│   └── memories/
│       ├── controllers/
│       │   └── decay_effects_example.gd
│       └── shaders/
│           └── glitch_memory.gdshader
├── world/
│   └── levels/
│       ├── level_manager.gd
│       └── level_trigger.gd
├── tests/
│   └── integration/
│       ├── player_controller_test.gd
│       ├── combat_prosthetics_test.gd
│       ├── enemies_test.gd
│       └── level_manager_test.gd
└── docs/
    ├── player_setup.md
    ├── enemy_setup.md
    └── shader_setup.md
```

## Documentação e contribuição

- [Configuração do GitHub e Git LFS](docs/github_setup.md): primeiro push, assets binários e limites de armazenamento.

- [Manual de desenvolvimento](MANUAL_DEV.md): contratos, montagem de nível, debugging e expansão de próteses/inimigos.
- [Jogador](docs/player_setup.md), [inimigos](docs/enemy_setup.md) e [shaders](docs/shader_setup.md): guias especializados.
- [Estrutura e evolução prevista](ESTRUTURA.md): diretórios atuais e planejados.
- [Áudio](docs/audio_setup.md): integração e tabela de requisitos WAV/OGG.

Use GDScript tipado, parâmetros de balanceamento exportados e composição por domínio. Verifique alterações com a suíte correspondente; ao alterar contratos compartilhados, execute todas. Não versione caches ou builds.

## Próximos passos da demo

1. Montar a torre com plataformas, âncoras, inimigos e gatilhos.
2. Instanciar o HUD na torre e adicionar feedback de checkpoint/morte.
3. Integrar narrativa, arte e áudio; validar efeitos com renderização.
4. Apontar o menu para a torre e configurar presets de exportação.

## Licença e créditos

A licença de distribuição será definida pelo responsável. Nenhuma licença de código aberto é concedida nesta entrega. Registre autoria e licença dos assets de terceiros antes de incorporá-los.
