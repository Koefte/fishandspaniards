class_name Player extends CharacterBody3D

@export var speed: float = 6.0
@export var jump_velocity: float = 4.5
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var input_queue: Array = []
var net_entity: NetEntity = null

var character_model: Node3D = null
var anim_player: AnimationPlayer = null
var walk_anim_name: String = ""

func _ready() -> void:
	if has_node("MeshInstance3D"):
		character_model = get_node("MeshInstance3D")
	anim_player = _find_anim_player(self)

func set_net_entity(p_net_entity: NetEntity) -> void:
	net_entity = p_net_entity

func push_input_command(command: Dictionary) -> void:
	input_queue.append(command)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found = _find_anim_player(child)
		if found != null:
			return found
	return null

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var current_direction = Vector3.ZERO
	var should_jump = false
	var target_pos = Vector3.ZERO

	while not input_queue.is_empty():
		var cmd: Dictionary = input_queue.pop_front()
		if cmd.has("direction"):
			current_direction = cmd["direction"]
		if cmd.has("jump") and cmd["jump"]:
			should_jump = true
		if cmd.has("position") and cmd["position"] != Vector3.ZERO:
			target_pos = cmd["position"]

	if target_pos != Vector3.ZERO:
		global_position = target_pos

	if should_jump and is_on_floor():
		velocity.y = jump_velocity

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

func _update_character_animation() -> void:
	if anim_player == null or walk_anim_name == "":
		return

	var horizontal_speed = Vector2(velocity.x, velocity.z).length()

	if horizontal_speed > 0.5 and is_on_floor():
		if not anim_player.is_playing() or anim_player.current_animation != walk_anim_name:
			anim_player.play(walk_anim_name)
			anim_player.speed_scale = 1.0
	else:
		if anim_player.is_playing() and anim_player.current_animation == walk_anim_name:
			anim_player.pause()
