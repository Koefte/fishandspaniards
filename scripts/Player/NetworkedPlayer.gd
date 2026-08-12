class_name NetworkedPlayer extends Player

func push_network_input(move_dir: Vector3, new_pos: Vector3 = Vector3.ZERO) -> void:
	push_input_command({
		"direction": move_dir,
		"position": new_pos
	})

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
