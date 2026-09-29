class_name State
extends Node
## Contrato virtual de estado, compatível com Godot 4.3.
## Instancie subclasses: esta base não implementa comportamento.

signal transition_requested(target: StringName)


func enter(_previous_state: State) -> void:
	pass


func exit() -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


## A máquina aceita solicitações somente do estado ativo.
func request_transition(target: StringName) -> void:
	transition_requested.emit(target)
