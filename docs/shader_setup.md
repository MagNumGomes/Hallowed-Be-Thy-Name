# Memórias corrompidas e corrosão de próteses

Shaders CanvasItem para Godot 4.3+, incluindo o renderizador **Compatibility**. Não exigem texturas de ruído externas.

## Montagem

```text
Level (Node2D)
├── Player
│   ├── ProstheticSprite (Sprite2D com a textura apenas da prótese)
│   └── Prosthetic (Node com ProstheticBase, ou uma subclasse)
├── MemoryPostProcess (CanvasLayer, layer = 10)
│   └── MemoryRect (ColorRect, Layout = Full Rect, Mouse Filter = Ignore)
├── HUD (CanvasLayer, layer = 20)
└── DecayEffects (Node com decay_effects_example.gd)
```

O jogador atual usa visuais provisórios; adicione a `Sprite2D` da prótese à montagem que receberá a arte. No Inspector de `DecayEffects`, atribua `memory_rect`, `prosthetic_sprite` e o componente `prosthetic`. O exemplo cria os materiais automaticamente. Se já houver um `ShaderMaterial` com o shader correspondente, ele será duplicado preservando os parâmetros do Inspector.

Para usar sem o controlador, crie um `ShaderMaterial` em cada item e atribua:

- ColorRect: `res://features/memories/shaders/glitch_memory.gdshader`.
- Sprite2D: `res://features/prosthetics/shaders/prosthetic_corrosion.gdshader`.

O pós-processamento lê `hint_screen_texture`, capturando os elementos desenhados antes dele. O HUD acima da camada 10 permanece legível. Se houver outro efeito que lê a tela antes deste, coloque um `BackBufferCopy` com **Copy Mode = Viewport** imediatamente antes de `MemoryRect` na ordem de desenho, para renovar a captura. O retângulo deve cobrir o viewport e estar em uma camada independente da câmera.

## Uniforms principais

### `glitch_memory.gdshader`

| Uniform | Padrão | Uso |
| --- | --- | --- |
| `glitch_intensity` | 0 | Intensidade global 0–1; zero reproduz a tela original |
| `chromatic_aberration` | 3 | Separação RGB máxima, em pixels de tela |
| `scanline_strength` | 0,06 | Escurecimento sutil das linhas; também escalado pela intensidade global |
| `scanline_spacing` | 3 | Distância entre linhas, em pixels |
| `distortion_amount` | 24 | Deslocamento horizontal máximo dos blocos, em pixels |
| `block_probability` | 0,18 | Probabilidade de deslocamento por bloco/tick na intensidade máxima |
| `block_size` | (64, 12) | Dimensões dos blocos em pixels |
| `glitch_speed` | 14 | Atualizações aleatórias por segundo |
| `seed` | 7 | Variação do padrão |

As amostras deslocadas são limitadas às bordas, evitando repetição da imagem. O filtro nearest preserva pixels; pode ser trocado por `filter_linear` para arte com filtragem suave.

### `prosthetic_corrosion.gdshader`

| Uniform | Padrão | Uso |
| --- | --- | --- |
| `durability` | 1 | Integridade normalizada: 1 íntegra, 0 quebrada |
| `corrosion_intensity` | 1 | Escala visual; zero remove toda a degradação |
| `rust_strength` / `patina_strength` | 0,85 / 0,65 | Mistura de ferrugem e pátina |
| `rust_color` / `patina_color` | Cobre / verde | Paleta da oxidação (RGB) |
| `noise_scale` | 12 | Tamanho das manchas em pixels da textura |
| `electric_strength` / `electric_speed` | 0,7 / 18 | Intensidade e frequência do ruído elétrico |
| `electric_color` | Azul claro | Cor das centelhas (RGB) |
| `seed` | 13 | Variação espacial entre próteses |

Ferrugem e pátina permanecem fixas na textura; somente as centelhas variam no tempo. O shader conserva alfa, `modulate`, `self_modulate` e iluminação 2D. A durabilidade cheia restaura a aparência original. Use uma textura dedicada à prótese: toda a área opaca do sprite é elegível para corrosão. Em spritesheets, cada frame ocupa outras coordenadas da textura e pode ter um padrão diferente.

## Controle em tempo real

O script completo está em `features/memories/controllers/decay_effects_example.gd`. Exemplo de chamadas por um controlador narrativo, após os nós estarem prontos:

```gdscript
@onready var effects: DecayEffectsExample = $DecayEffects

func play_memory() -> void:
	effects.fade_memory_to(0.75, 0.2)
	await get_tree().create_timer(1.5).timeout
	effects.fade_memory_to(0.0, 0.6)

func on_memory_cut() -> void:
	effects.set_memory_intensity(1.0)
	effects.fade_memory_to(0.0, 0.3)

func reduce_visual_effects() -> void:
	effects.memory_effects_strength = 0.3
	effects.set_corrosion_intensity(0.5)
```

O sinal `ProstheticBase.durability_changed` atualiza o uniform `durability` com `float(current) / maximum`, inclusive após reparos. O estado inicial é consultado explicitamente. Os efeitos não alteram as regras de desgaste.

Também é possível alterar parâmetros diretamente após a montagem:

```gdscript
var memory_material := $MemoryPostProcess/MemoryRect.material as ShaderMaterial
memory_material.set_shader_parameter(&"scanline_strength", 0.04)
memory_material.set_shader_parameter(&"distortion_amount", 36.0)

var corrosion_material := $Player/ProstheticSprite.material as ShaderMaterial
corrosion_material.set_shader_parameter(&"electric_strength", 0.9)
```

Fora do exemplo, duplique materiais compartilhados antes de alterar uniforms por instância. `TIME` anima o ruído no shader; não é necessário `_process()`. O `TIME` do Godot continua durante pausa da árvore; os tweens do controlador seguem a política de pausa do nó.

## Conferência visual

1. Intensidade de memória 0: imagem idêntica, sem scanlines ou aberração.
2. Intensidade 1: RGB separado aleatoriamente, linhas sutis e blocos deslocados; HUD acima do efeito permanece intacto.
3. Durabilidade 1 → 0,5 → 0: aumento da área oxidada e do ruído elétrico; pixels transparentes permanecem transparentes.
4. Reparo: corrosão recua; intensidade de corrosão 0 restaura a sprite original.
5. Duas instâncias: variar uniforms de uma não modifica a outra.
