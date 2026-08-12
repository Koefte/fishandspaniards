class_name NetworkedPlayer extends Player

func receive_key_input_packet(key_data: Dictionary) -> void:
	push_input_command(key_data)

func push_network_input(move_dir: Vector3, new_pos: Vector3 = Vector3.ZERO, jump: bool = false) -> void:
	push_input_command({
		"direction": move_dir,
		"position": new_pos,
		"jump": jump
	})

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
