class_name LevelTrigger
extends Area2D
## Volume configurável: CollisionShape2D, máscara Player (2), camada zero.

enum Kind { CHECKPOINT, MEMORY, TRANSITION, RESPAWN }

@export var manager: LevelManager
@export var kind: Kind = Kind.CHECKPOINT
@export var destination: Marker2D
@export var checkpoint_id: StringName = &"checkpoint"
@export_range(0.0, 1.0) var memory_intensity: float = 0.7


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	if not is_instance_valid(manager):
		push_error("LevelTrigger: atribua LevelManager no Inspector.")
		return
	if kind == Kind.MEMORY:
		set_meta(&"memory_intensity", memory_intensity)
		manager.register_memory_room(self)
	else:
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(manager) or body != manager.player or manager.transitioning:
		return
	match kind:
		Kind.CHECKPOINT:
			if is_instance_valid(destination):
				manager.activate_checkpoint(checkpoint_id, destination.global_position)
			else:
				push_error("LevelTrigger: checkpoint precisa de Destination.")
		Kind.TRANSITION:
			if is_instance_valid(destination):
				manager.transition_to(destination.global_position)
			else:
				push_error("LevelTrigger: transição precisa de Destination.")
		Kind.RESPAWN:
			manager.respawn()
