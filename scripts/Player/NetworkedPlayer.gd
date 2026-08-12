class_name NetworkedPlayer extends Player

var active_key_state: Dictionary = {
	"forward": false,
	"backward": false,
	"left": false,
	"right": false,
	"jump": false,
	"rot_y": 0.0
}

func receive_key_input_packet(key_data: Dictionary) -> void:
	push_input_command(key_data)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var target_pos

	while not input_queue.is_empty():
		var cmd: Dictionary = input_queue.pop_front()
		for key in ["forward", "backward", "left", "right", "jump", "rot_y"]:
			if cmd.has(key):
				active_key_state[key] = cmd[key]
		if cmd.has("position"):
			target_pos = cmd["position"]

	if target_pos != null:
		global_position = target_pos

	rotation.y = active_key_state.get("rot_y", rotation.y)

	var input_vec = Vector2.ZERO
	if active_key_state.get("left", false): input_vec.x -= 1.0
	if active_key_state.get("right", false): input_vec.x += 1.0
	if active_key_state.get("forward", false): input_vec.y -= 1.0
	if active_key_state.get("backward", false): input_vec.y += 1.0
	input_vec = input_vec.normalized()

	var current_direction = (Basis(Vector3.UP, rotation.y) * Vector3(input_vec.x, 0, input_vec.y)).normalized()

	if active_key_state.get("jump", false) and is_on_floor():
		velocity.y = jump_velocity
		active_key_state["jump"] = false

	if current_direction != Vector3.ZERO:
		velocity.x = current_direction.x * speed
		velocity.z = current_direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	if net_entity:
		net_entity.pos = global_position

	_update_character_animation()
