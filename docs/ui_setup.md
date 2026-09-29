# Interface — Godot 4.3+

## Execução

F5 abre `features/ui/main_menu.tscn`. Ferro escuro, contornos bronze, texto
pergaminho e ciano unem relicário medieval e tecnologia degradada. Em **Opções**,
desative o glitch do título e ajuste o volume. Preferências: `user://options.cfg`.
Use Tab/setas/Enter para navegar; Esc fecha opções. O foco tem contorno ciano.

**Iniciar Jogo** abre `world/levels/ui_demo.tscn`: sala técnica substituível pela
torre. A/D move, o fragmento ciano é coletável, F5 salva e Esc retorna ao menu.
O fragmento reaparece ao reabrir a sala: este slot simples não persiste objetos
coletados, inimigos ou checkpoints.

## Integração

1. Altere `game_scene` no Inspector do menu para a cena da torre.
2. Instancie `features/ui/hud.tscn` no nível e atribua `player`.
3. A prótese padrão é o gancho. Para trocar, chame
   `hud.set_active_prosthetic(componente, "NOME")` após inicialização.
4. Coletas incrementam `player.fragments`; impeça coleta duplicada no coletável.
5. Após o jogador estar pronto, chame `SaveGame.apply_pending(player)` na cena.
6. Para salvar, chame `SaveGame.save_player(player, scene_file_path)` numa
   interação/checkpoint e apresente o `Error` retornado. Morte/transição rejeitam save.

O HUD acompanha `health_changed`, `fragments_changed` e `durability_changed`.
Até 20% de durabilidade (export `warning_threshold`), usa ferrugem, pulsação
lenta e texto **RUPTURA IMINENTE**; zero mostra **QUEBRADA — REPARE**.

`user://memory.json` guarda versão, cena, posição, vida, fragmentos e durabilidade
do gancho. Leitura valida tipos, limites e existência da cena; menu aceita apenas
o slot da cena configurada. Escrita usa temporário e renomeação. Iniciar Jogo não
apaga o slot. Amplie o esquema/versionamento para checkpoints e múltiplas próteses.

## Anchors e Containers

- Projeto: viewport lógico **1280×720**, Stretch Mode **canvas_items**. Teste
  960×540, 1920×1080, 1024×768 e 2560×1080. A proporção padrão preserva a
  composição com barras quando necessário. Para preencher outras proporções,
  use Stretch Aspect **expand** e valide também o enquadramento do jogo.
- HUD: `CanvasLayer` 100 independe da câmera e fica acima do efeito de memória
  do `LevelManager` (90).
- `Root` e `SafeMargin`: preset **Full Rect**, anchors 0,0,1,1 e offsets zero.
  Margens de 24 unidades mantêm o conteúdo afastado das bordas.
- `VBoxContainer` organiza indicadores sem sobreposição; painel mínimo de 340
  unidades alinhado à esquerda, barras preenchendo a largura e contador abaixo.
- Menu: Full Rect → MarginContainer → ScrollContainer → CenterContainer
  (**Expand + Fill** nos dois eixos) → VBoxContainer. O menu fica centralizado;
  a rolagem permite acesso aos controles se faltar altura.
- Em filhos de Containers, ajuste **Size Flags**, mínimos e separação, não
  offsets/anchors: o Container controla o layout.
- HUD usa **Mouse Filter = Ignore** para não interceptar mira/ataque. Botões
  mantêm entrada de mouse e foco de teclado.
- Evite escalar Labels individualmente. Ajuste tema e tamanho lógico. Para
  menos de aproximadamente 400 unidades lógicas de largura, reduza os mínimos
  e a tipografia com um breakpoint próprio para retrato.

## Testes

```bash
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/integration/ui_test.gd
```

Verifica sinais, ruptura/quebra, troca de prótese, round-trip, sobrescrita,
corrupção do slot e opções. Preserva o slot existente. Inspecione glitch,
contraste, foco e redimensionamento no editor com renderização.
