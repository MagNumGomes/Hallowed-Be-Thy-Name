class_name DecayEffectsExample
extends Node
## Exemplo de apresentação: anima a memória e observa a integridade da prótese.
## Atribua as três referências no Inspector; materiais são isolados por instância.

const MEMORY_SHADER: Shader = preload("res://features/memories/shaders/glitch_memory.gdshader")
const CORROSION_SHADER: Shader = preload("res://features/prosthetics/shaders/prosthetic_corrosion.gdshader")

@export var memory_rect: ColorRect
@export var prosthetic_sprite: Sprite2D
@export var prosthetic: ProstheticBase
## Preferência visual independente da intensidade solicitada pela narrativa.
@export_range(0.0, 1.0, 0.01) var memory_effects_strength: float = 1.0:
	set(value):
		memory_effects_strength = clampf(value, 0.0, 1.0)
		_apply_memory_intensity(_memory_intensity)

var _memory_material: ShaderMaterial
var _corrosion_material: ShaderMaterial
var _memory_intensity: float = 0.0
var _memory_tween: Tween


func _ready() -> void:
	if memory_rect == null or prosthetic_sprite == null or prosthetic == null:
		push_error("DecayEffectsExample: atribua ColorRect, Sprite2D e ProstheticBase no Inspector.")
		return

	_memory_material = _prepare_material(memory_rect, MEMORY_SHADER)
	_corrosion_material = _prepare_material(prosthetic_sprite, CORROSION_SHADER)
	memory_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_memory_intensity(_memory_intensity)

	# Também funciona se a prótese for um irmão que ainda não recebeu _ready().
	if not prosthetic.is_node_ready():
		await prosthetic.ready
	prosthetic.durability_changed.connect(_on_durability_changed)
	_on_durability_changed(prosthetic.get_durability(), prosthetic.get_max_durability())


## Altera o glitch imediatamente, por exemplo em um corte narrativo.
func set_memory_intensity(value: float) -> void:
	_stop_memory_tween()
	_apply_memory_intensity(value)


## Faz uma transição suave. Uma nova chamada substitui a transição anterior.
func fade_memory_to(target: float, duration: float = 0.35) -> void:
	_stop_memory_tween()
	if duration <= 0.0:
		_apply_memory_intensity(target)
		return
	_memory_tween = create_tween()
	_memory_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_memory_tween.tween_method(_apply_memory_intensity, _memory_intensity,
		clampf(target, 0.0, 1.0), duration)


## Ajusta a apresentação da corrosão sem alterar a durabilidade real.
func set_corrosion_intensity(value: float) -> void:
	if _corrosion_material != null:
		_corrosion_material.set_shader_parameter(&"corrosion_intensity", clampf(value, 0.0, 1.0))


func _apply_memory_intensity(value: float) -> void:
	_memory_intensity = clampf(value, 0.0, 1.0)
	if _memory_material != null:
		_memory_material.set_shader_parameter(&"glitch_intensity",
			_memory_intensity * memory_effects_strength)


func _on_durability_changed(current: int, maximum: int) -> void:
	var ratio: float = clampf(float(current) / float(maxi(maximum, 1)), 0.0, 1.0)
	_corrosion_material.set_shader_parameter(&"durability", ratio)


func _stop_memory_tween() -> void:
	if _memory_tween != null and _memory_tween.is_valid():
		_memory_tween.kill()


func _prepare_material(item: CanvasItem, shader: Shader) -> ShaderMaterial:
	var material: ShaderMaterial
	if item.material is ShaderMaterial and (item.material as ShaderMaterial).shader == shader:
		# Preserva os parâmetros configurados no Inspector, sem modificar outras sprites.
		material = item.material.duplicate() as ShaderMaterial
	else:
		material = ShaderMaterial.new()
		material.shader = shader
	item.use_parent_material = false
	item.material = material
	return material
