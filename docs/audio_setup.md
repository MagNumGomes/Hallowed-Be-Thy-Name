# Áudio: atmosfera e integração

`core/audio_manager.gd` é o Autoload `AudioManager`. O layout versionado
`default_bus_layout.tres` contém Master, BGM (−6 dB), SFX (0 dB) e Glitch
(−9 dB); os três últimos enviam diretamente para Master. A opção de volume
existente continua a controlar Master, incluindo mute.

## Música e memórias

No Inspector de `LevelManager`, atribua `exploration_music`, `memory_music`
e `music_fade_duration` (2 s por padrão). As salas existentes selecionam memória
quando a intensidade é maior que zero; ao sair de todas, regressa exploração.
Essa seleção independe da preferência de efeitos visuais. Faixa ausente implica
silêncio nesse contexto; se ambas estiverem ausentes, o nível não controla BGM.

Também é possível chamar `AudioManager.transition_music(stream, 2.0)` e
`AudioManager.stop_music(1.0)`. O crossfade interpola amplitude linear entre
vozes, sem reiniciar um destino repetido. Inverter a transição reaproveita a
faixa ainda em reprodução e parte dos volumes atuais. Vozes inaudíveis são
paradas e removidas. Depois de removida, uma faixa regressa desde o início.
O singleton mantém música e transições durante mudanças de cena e pausa.
No menu, chame `stop_music()` se desejar silêncio.

Exploração: pulsação industrial lenta (60–80 BPM), metal grave e drones de
viela de roda, alaúde e sinos distantes. Memória: motivos medievais fragmentados,
percussão rarefeita e textura degradada. Preserve espaço para passos e combate.
Os ficheiros de áudio ainda precisam de ser produzidos e atribuídos.

## SFX pontuais

Exporte um `AudioStream` no componente que possui o evento e invoque, por exemplo:

```gdscript
@export var step_sound: AudioStream
@export var static_sound: AudioStream

func on_footstep() -> void:
	AudioManager.play_sfx(step_sound, -4.0, 0.04)

func on_memory_pulse() -> void:
	AudioManager.play_sfx(static_sound, -8.0, 0.03, &"Glitch")
```

Dispare passos por marcador de animação e golpes no início da janela do ataque,
não a cada frame. O pitch varia ±4% por padrão, limitado a ±15%; use zero para
sons tonais que precisem de afinação fixa. Até 24 SFX simultâneos; excedentes
substituem o mais antigo. Vozes terminadas são removidas automaticamente.
São efeitos globais não posicionais; os recursos pontuais devem estar sem loop.

## Requisitos dos ficheiros

Caminhos propostos em `assets/audio/`. `{01..03}` indica três ficheiros distintos;
combine variantes escolhidas pelo componente com a variação de pitch.

| Ficheiro | Evento / caráter | Duração | Bus | Formato / variantes |
| --- | --- | --- | --- | --- |
| `sfx/prosthetic_creak_{01..03}.wav` | Rangido de prótese sob carga; metal e couro tensionados | 0,2–0,7 s | SFX | WAV mono, 3 |
| `sfx/prosthetic_break.wav` | Ruptura; estalo mecânico e engrenagem solta | 0,7–1,5 s | SFX | WAV mono, 1 |
| `sfx/electric_discharge_{01..03}.wav` | Descargas elétricas instáveis; arco irregular, falhas curtas | 0,15–0,8 s | SFX | WAV mono, 3 |
| `sfx/nanotube_swing_{01..03}.wav` | Lâmina de nanotubos; corte de ar fino e ressonância metálica | 0,15–0,4 s | SFX | WAV mono, 3 |
| `sfx/nanotube_heavy.wav` | Golpe pesado; ataque grave e cauda metálica | 0,4–0,8 s | SFX | WAV mono, 1 |
| `sfx/nanotube_impact_{01..03}.wav` | Impacto em armadura/corpo; fricção e corte seco | 0,1–0,5 s | SFX | WAV mono, 3 |
| `glitch/static_burst_{01..03}.wav` | Ruídos de estática nas memórias; impulsos granulados | 0,1–0,6 s | Glitch | WAV estéreo, 3 |
| `glitch/memory_enter.ogg` / `memory_exit.ogg` | Entrada/saída de flashback; sintonia quebrada | 1–2 s | Glitch | OGG estéreo, 2 |
| `sfx/footstep_stone_{01..04}.wav` | Passos na torre; pedra úmida e peso mecânico | 0,1–0,3 s | SFX | WAV mono, 4 |
| `sfx/land.wav` / `dash.wav` | Aterragem e esquiva; peso/arrasto | 0,2–0,5 s | SFX | WAV mono, 2 |
| `sfx/grapple_fire.wav` / `grapple_latch.wav` | Disparo do gancho e fixação; cabo e trava | 0,2–0,6 s | SFX | WAV mono, 2 |
| `sfx/hurt_{01..02}.wav` / `death.wav` | Dano e morte; impacto e expiração abafada | 0,3–2 s | SFX | WAV mono, 3 |
| `sfx/checkpoint.wav` | Ancoragem; sino medieval com pulso elétrico | 1–2 s | SFX | WAV estéreo, 1 |
| `bgm/tower_exploration.ogg` | Batidas industriais + instrumentos medievais | 60–120 s | BGM | OGG estéreo, loop |
| `bgm/tower_memory.ogg` | Variação fragmentada do mesmo tema | 45–90 s | BGM | OGG estéreo, loop |

Entrega: 48 kHz, WAV PCM 16-bit para transientes curtos; OGG Vorbis para música
e caudas longas. Sem clipping, picos até −3 dBFS e loudness coerente entre
variantes. Remova silêncio inicial, preserve caudas e elimine clicks nas bordas.
Ative Loop na importação das músicas e valide a emenda; desative nos SFX.
Registre autoria/licença dos recursos. Valide a mistura com auscultadores:
crossfade rápido A→B→A, mute Master, inteligibilidade dos golpes e estática baixa.
