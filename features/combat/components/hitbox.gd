class_name Hitbox
extends Area2D
## Uma vítima por golpe, mesmo com múltiplas hurtboxes ou reentrada na área.

signal hit_confirmed(hurtbox: Hurtbox)

@export var source: Node2D
@export var team: StringName = &"player"
@export_range(0.0, 10000.0) var damage: float = 10.0
@export var damage_type: StringName = &"nanotube_slash"
@export var knockback: Vector2 = Vector2(180.0, -60.0)

var active: bool = false
var _victims: Dictionary = {}
var _direction: float = 1.0


func _ready() -> void:
	monitorable = false
	area_entered.connect(_on_area_entered)


func begin_strike(amount: float, kind: StringName, impulse: Vector2, direction: float) -> void:
	damage = maxf(0.0, amount)
	damage_type = kind
	knockback = impulse
	_direction = -1.0 if direction < 0.0 else 1.0
	_victims.clear()
	active = true


func end_strike() -> void:
	active = false


## Chamado pelo controlador após atualizar o estado: cobre alvos já sobrepostos.
func scan_overlaps() -> void:
	if active:
		for area: Area2D in get_overlapping_areas():
			_on_area_entered(area)


func _on_area_entered(area: Area2D) -> void:
	if not active or not area is Hurtbox:
		return
	var hurtbox := area as Hurtbox
	var victim: Node = hurtbox.receiver if is_instance_valid(hurtbox.receiver) else hurtbox
	var id := victim.get_instance_id()
	if _victims.has(id):
		return
	# Reservar antes do sinal evita impactos reentrantes.
	_victims[id] = true
	if hurtbox.receive_hit(damage, damage_type, Vector2(knockback.x * _direction, knockback.y), source, team):
		hit_confirmed.emit(hurtbox)
	else:
		_victims.erase(id)
