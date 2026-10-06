extends Node2D
## Animação procedural sobre sprites vetoriais originais.

var actor: CharacterBody2D
var sprite: Sprite2D
var clock: float = 0.0
var slash: float = 0.0
var flash: float = 0.0

func _ready() -> void:
	actor = get_parent() as CharacterBody2D
	for child: Node in get_children():
		if child is CanvasItem:
			child.hide()
	sprite = Sprite2D.new()
	var art := "guardian" if actor is Player else ("hologram" if actor is CorruptedHologram else "zealot")
	sprite.texture = load("res://assets/art/%s.svg" % art)
	sprite.scale = Vector2.ONE * 0.85
	add_child(sprite)
	actor.health_changed.connect(func(_hp: float, _max: float) -> void: flash = 0.16)
	if actor is Player:
		actor.get_node("StateMachine/Attack").strike_started.connect(func(_index: int) -> void: slash = 0.3)

func _process(delta: float) -> void:
	clock += delta
	slash = maxf(0.0, slash - delta)
	flash = maxf(0.0, flash - delta)
	if actor is Player:
		scale.x = actor.facing_direction
	var moving := absf(actor.velocity.x) > 15.0
	sprite.position.y = sin(clock * (18.0 if moving else 3.0)) * (1.5 if moving else 0.5)
	sprite.rotation = sin(clock * 18.0) * 0.06 if moving else 0.0
	sprite.modulate = Color(2.0, 1.2, 1.2) if flash > 0.0 else Color.WHITE
	queue_redraw()

func _draw() -> void:
	if slash > 0.0:
		var progress := 1.0 - slash / 0.3
		draw_arc(Vector2(8, 0), 34, -1.6 + progress, 0.8 + progress, 20, Color(0.7, 1, 0.9, slash / 0.3), 3, true)
