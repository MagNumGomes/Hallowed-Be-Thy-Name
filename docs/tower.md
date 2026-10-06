# Primeiro percurso da torre

Execute o projeto (F5) e inicie pelo menu, ou abra `world/levels/tower.tscn` e use F6. A sala técnica `ui_demo.tscn` continua disponível para os testes de interface.

## Percurso

- **Vestíbulo:** movimentação, primeiro fanático, escadaria e anéis de gancho.
- **Arsenal:** fanático no piso e holograma sobre a plataforma superior.
- **Câmara de memória:** último par de inimigos, efeito de memória corrompida e altar de conclusão.

Colete o losango dourado de cada setor e derrote os cinco inimigos. No último setor, pressione **W junto à porta direita** para concluir. W também permite avançar pelas portas direitas e retornar pelo limite esquerdo dos setores seguintes.

As plataformas podem ser alcançadas por saltos; o gancho oferece uma rota alternativa. Mire nos anéis verdes e segure E ou botão direito. Nos santuários, R restaura vida e durabilidade. Morrer retorna ao último santuário; inimigos derrotados e fragmentos coletados permanecem no estado atual.

**F5 dentro do jogo** grava posição, vida, prótese, fragmentos, inimigos derrotados, checkpoint e conclusão no slot existente. Esc retorna ao menu; não há salvamento automático. O menu só habilita carregar para saves da torre.

## Organização

- `world/levels/tower.gd`: montagem em execução, geometria, encontros, apresentação, narrativa e objetivos. `SPAWNS`, `RELICS`, `_build_geometry()` e `_build_encounters()` concentram o layout.
- `world/levels/level_manager.gd`: física de transição, proteção, fade, respawn e shader de memória, reutilizados pela torre.
- `features/player/tower_actor_visual.gd`: sprites, oscilação de movimento/repouso, flash de impacto e arco de espada.
- `assets/art/{guardian,zealot,hologram}.svg`: arte vetorial original criada para este projeto, sem assets de terceiros.
- `world/levels/tower_sound.gd`: geração de recursos PCM WAV em memória para ambientes e efeitos originais. Não requer download nem bibliotecas. Usa os buses existentes e respeita o volume do menu.

A opção de glitch do menu controla a distorção de memória da torre. A apresentação atual é uma primeira direção visual estilizada, com animação procedural.

## Validação

Godot 4.3 stable: sete suítes de integração passaram, incluindo `tower_test.gd`. A suíte da torre verifica saltos reais pelos três degraus, conexão do gancho, coleta por colisão, bloqueio/liberação do final, portal, checkpoint, respawn e restauração de progresso sem duplicar relíquias ou inimigos. O teste preserva o slot existente. A composição inicial também foi inspecionada com renderização OpenGL Compatibility.
