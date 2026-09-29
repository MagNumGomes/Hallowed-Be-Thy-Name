class_name Hurtbox
extends Area2D
## Recebe impactos; vida e resposta física pertencem ao receptor.

signal impacted(damage: float, damage_type: StringName, knockback: Vector2, source: Node)

@export var receiver: Node2D
@export var team: StringName = &"enemy"
@export var invulnerable: bool = false


func _ready() -> void:
	monitoring = false


## Retorna falso para impactos ignorados, sem emitir sinais.
func receive_hit(damage: float, damage_type: StringName, knockback: Vector2, source: Node, source_team: StringName) -> bool:
	if invulnerable or damage < 0.0 or is_queued_for_deletion():
		return false
	if source_team != &"" and source_team == team:
		return false
	if is_instance_valid(receiver):
		if receiver == source or receiver.is_queued_for_deletion():
			return false
		if receiver.has_method(&"is_invulnerable") and receiver.call(&"is_invulnerable"):
			return false
	impacted.emit(damage, damage_type, knockback, source)
	return true
