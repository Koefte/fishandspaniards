class_name NetworkedPlayer extends Player

func receive_key_input_packet(key_data: Dictionary) -> void:
	push_input_command(key_data)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
