extends Node2D
## Sala técnica substituível pela torre no Inspector do menu.

func _ready() -> void:
	SaveGame.apply_pending($Player)
	$Interface/Help.text = "SALA DE INTERFACE · A/D mover · E gancho\nF5 registrar memória · Esc menu · aproxime-se da relíquia para coletar"
	$Fragment.body_entered.connect(_collect_fragment)


func _collect_fragment(body: Node2D) -> void:
	if body == $Player and not $Fragment.is_queued_for_deletion():
		$Player.fragments += 1
		$Fragment.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://features/ui/main_menu.tscn")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		var error := SaveGame.save_player($Player, scene_file_path)
		$Interface/Help.text = "MEMÓRIA REGISTRADA · Esc menu" if error == OK else "FALHA AO REGISTRAR (%d)" % error
