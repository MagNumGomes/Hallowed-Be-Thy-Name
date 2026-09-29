class_name StateMachine
extends Node
## Máquina genérica conduzida pelo proprietário, sem processamento automático.
## Registra filhos State uma vez; a topologia deve permanecer estável após start().

signal state_changed(previous: State, current: State)

@export var initial_state: State

var current_state: State:
	get:
		return _current_state
var previous_state: State:
	get:
		return _previous_state

var _current_state: State
var _previous_state: State
var _states: Dictionary = {}
var _started: bool = false
var _transitioning: bool = false
var _dispatching: bool = false
var _pending_target: StringName = &""


## Chamar após injetar as dependências de todos os estados.
func start() -> bool:
	if _started or not is_instance_valid(initial_state):
		return false
	if initial_state.get_parent() != self:
		push_error("StateMachine: initial_state deve ser um filho direto.")
		return false
	for child: Node in get_children():
		if child is State:
			var state := child as State
			_states[state.name] = state
			state.transition_requested.connect(_on_transition_requested.bind(state))
	_started = true
	return transition_to(initial_state.name)


## Retorna se a transição foi aceita. Durante update/input/physics, a primeira
## solicitação válida é aplicada ao terminar o callback; não há reentrância.
## Solicitações em enter/exit/state_changed e para o próprio estado são rejeitadas.
func transition_to(target: StringName) -> bool:
	if not _started or _transitioning or not _states.has(target):
		return false
	var next_state: State = _states[target] as State
	if not is_instance_valid(next_state) or next_state.is_queued_for_deletion():
		return false
	if next_state.get_parent() != self or next_state == _current_state:
		return false
	if _dispatching:
		if _pending_target != &"":
			return false
		_pending_target = target
		return true
	_transitioning = true
	var old_state := _current_state
	if is_instance_valid(old_state):
		old_state.exit()
	_previous_state = old_state
	_current_state = next_state
	_current_state.enter(_previous_state)
	state_changed.emit(_previous_state, _current_state)
	_transitioning = false
	return true


func handle_input(event: InputEvent) -> void:
	if not _begin_dispatch():
		return
	_current_state.handle_input(event)
	_end_dispatch()


func update(delta: float) -> void:
	if not _begin_dispatch():
		return
	_current_state.update(delta)
	_end_dispatch()


func physics_update(delta: float) -> void:
	if not _begin_dispatch():
		return
	_current_state.physics_update(delta)
	_end_dispatch()


func _begin_dispatch() -> bool:
	if _dispatching or _transitioning or not is_instance_valid(_current_state):
		return false
	if _current_state.is_queued_for_deletion():
		return false
	_dispatching = true
	return true


func _end_dispatch() -> void:
	_dispatching = false
	var target := _pending_target
	_pending_target = &""
	if target != &"":
		transition_to(target)


func _on_transition_requested(target: StringName, source: State) -> void:
	if source == _current_state:
		transition_to(target)
