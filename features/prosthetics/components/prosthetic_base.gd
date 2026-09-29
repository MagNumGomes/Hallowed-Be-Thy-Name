class_name ProstheticBase
extends Node
## Componente de integridade de uma prótese mecânica.
## Não executa habilidades nem depende de entrada, HUD ou movimento.
## Configure pelo Inspector antes de _ready(); o estado pertence à instância.

## Um uso foi aceito. O efeito continua válido mesmo quando o restante é zero.
signal activated(remaining_durability: int)

## Emitido apenas quando a integridade realmente muda, inclusive em reparos.
signal durability_changed(current_durability: int, maximum_durability: int)

## Emitido uma vez por transição de integridade positiva para zero.
signal broken()

@export_category("Durabilidade")
## Capacidade inicial. Copiada e normalizada durante _ready().
@export_range(1, 100000, 1, "or_greater") var max_durability: int = 100
## Custo por uso aceito. Zero permite uso sem desgaste.
@export_range(0, 100000, 1, "or_greater") var degradation_per_activation: int = 10

var _durability: int = 0
var _maximum_durability: int = 0
var _activation_cost: int = 0
var _initialized: bool = false
var _is_notifying: bool = false


func _ready() -> void:
	# Preserva o estado caso request_ready() seja usado ao reanexar este nó.
	if _initialized:
		return

	if max_durability < 1 or degradation_per_activation < 0:
		push_warning("ProstheticBase: configuração inválida; limites serão normalizados.")

	_maximum_durability = maxi(1, max_durability)
	_activation_cost = maxi(0, degradation_per_activation)
	_durability = _maximum_durability
	_initialized = true


## Retorna zero antes da inicialização.
func get_durability() -> int:
	return _durability


## Restaura o estado persistido após _ready(), sem simular ativações.
func restore_durability(value: int) -> void:
	if not _initialized or _is_notifying:
		return
	var previous := _durability
	_durability = clampi(value, 0, _maximum_durability)
	if previous == _durability:
		return
	_is_notifying = true
	durability_changed.emit(_durability, _maximum_durability)
	if previous > 0 and _durability == 0:
		broken.emit()
	_is_notifying = false


## Retorna a capacidade efetiva, ou zero antes da inicialização.
func get_max_durability() -> int:
	return _maximum_durability


## Uma prótese ainda não inicializada não é considerada quebrada.
func is_broken() -> bool:
	return _initialized and _durability == 0


## Valida apenas disponibilidade local; cooldown e energia são externos.
func can_activate() -> bool:
	return _initialized and not _is_notifying and _durability > 0


## Aceita um uso, desconta o custo e publica os eventos em ordem estável.
## Qualquer integridade positiva permite o último uso, mesmo abaixo do custo.
## Retorna falso sem efeitos colaterais se indisponível.
func try_activate() -> bool:
	if not can_activate():
		return false

	var previous_durability: int = _durability
	_durability -= mini(_activation_cost, _durability)

	# Bloqueia mutações reentrantes durante callbacks de sinais síncronos.
	_is_notifying = true
	activated.emit(_durability)
	if _durability != previous_durability:
		durability_changed.emit(_durability, _maximum_durability)
	if _durability == 0:
		broken.emit()
	_is_notifying = false

	return true


## Restaura integridade e permite reutilizar uma prótese quebrada.
## Não consome itens: autorização e custo do reparo pertencem ao chamador.
## Retorna verdadeiro somente quando há mudança efetiva.
func repair(amount: int) -> bool:
	if not _initialized or _is_notifying or amount <= 0:
		return false

	# Limitar antes da soma também evita overflow com valores muito grandes.
	var restored_amount: int = mini(amount, _maximum_durability - _durability)
	if restored_amount == 0:
		return false

	_durability += restored_amount
	_is_notifying = true
	durability_changed.emit(_durability, _maximum_durability)
	_is_notifying = false
	return true
