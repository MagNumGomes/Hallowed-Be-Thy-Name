class_name GameHUD
extends CanvasLayer

const UI_THEME = preload("res://features/ui/decayed_theme.gd")
@export var player: Player
@export var active_prosthetic: ProstheticBase
@export var prosthetic_name: String = "GANCHO / RELÍQUIA"
@export_range(0.0, 1.0) var warning_threshold: float = 0.2
var _pulse: float = 0.0
var _critical: bool = false
@onready var health_bar: ProgressBar = %HealthBar
@onready var durability_bar: ProgressBar = %DurabilityBar


func _ready() -> void:
	$Root.theme = UI_THEME.create()
	# Elementos informativos não interceptam ataques com o mouse.
	_ignore_mouse($Root)
	if is_instance_valid(player):
		if not player.is_node_ready():
			await player.ready
		player.health_changed.connect(_update_health)
		player.fragments_changed.connect(_update_fragments)
		_update_health(player.health, player.max_health)
		_update_fragments(player.fragments)
		if not is_instance_valid(active_prosthetic):
			active_prosthetic = player.grappling_hook
	set_active_prosthetic(active_prosthetic, prosthetic_name)


func set_active_prosthetic(prosthetic: ProstheticBase, display_name: String) -> void:
	if is_instance_valid(active_prosthetic) and active_prosthetic.durability_changed.is_connected(_update_durability):
		active_prosthetic.durability_changed.disconnect(_update_durability)
	active_prosthetic = prosthetic
	prosthetic_name = display_name
	if not is_node_ready():
		return
	if is_instance_valid(prosthetic):
		if not prosthetic.is_node_ready():
			await prosthetic.ready
		prosthetic.durability_changed.connect(_update_durability)
		_update_durability(prosthetic.get_durability(), prosthetic.get_max_durability())
	else:
		_update_durability(0, 1)
		%ProstheticStatus.text = "SEM PRÓTESE"
		_critical = false


func _update_health(current: float, maximum: float) -> void:
	health_bar.max_value = maxf(1.0, maximum)
	health_bar.value = current
	%HealthText.text = "INTEGRIDADE  %d / %d" % [current, maximum]


func _update_fragments(total: int) -> void:
	%Fragments.text = "FRAGMENTOS / %06d" % total


func _update_durability(current: int, maximum: int) -> void:
	durability_bar.max_value = maxi(1, maximum)
	durability_bar.value = current
	_critical = float(current) / maxi(1, maximum) <= warning_threshold
	var status := "ESTÁVEL"
	if current == 0:
		status = "QUEBRADA — REPARE"
	elif _critical:
		status = "! RUPTURA IMINENTE"
	%ProstheticStatus.text = "%s · %d/%d\n%s" % [prosthetic_name, current, maximum, status]
	durability_bar.modulate = Color("e58e65") if _critical else Color.WHITE
	%ProstheticStatus.modulate = Color("e58e65") if _critical else Color.WHITE


func _process(delta: float) -> void:
	_pulse += delta
	# Pulsação lenta; a mensagem também comunica o estado sem depender da cor.
	%ProstheticStatus.modulate.a = 0.8 + 0.2 * sin(_pulse * 3.0) if _critical else 1.0


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)
