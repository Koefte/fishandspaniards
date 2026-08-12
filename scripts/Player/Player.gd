class_name Player_Internal extends CharacterBody3D

enum Perspective { FIRST_PERSON, THIRD_PERSON }


@export var speed: float = 6
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0025
@export var current_perspective: Perspective = Perspective.FIRST_PERSON

@onready var camera_pivot: Node3D = get_node_or_null("Head")
@onready var camera: Camera3D = get_node_or_null("Head/Camera3D")
@onready var character_model: Node3D = get_node_or_null("MeshInstance3D")

var anim_player: AnimationPlayer = null
var walk_anim_name: String = ""
var net_entity: NetEntity = null

func set_net_entity(p_net_entity: NetEntity) -> void:
	net_entity = p_net_entity

const FIRST_PERSON_CAM_POS: Vector3 = Vector3(0, 0.02, -0.22)
const THIRD_PERSON_CAM_POS: Vector3 = Vector3(0, 0.4, 2.8)

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready() -> void:
	if camera != null:
		camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_apply_perspective()


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found = _find_anim_player(child)
		if found != null:
			return found
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if camera_pivot != null:
			camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			toggle_perspective()

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_perspective() -> void:
	if current_perspective == Perspective.FIRST_PERSON:
		current_perspective = Perspective.THIRD_PERSON
	else:
		current_perspective = Perspective.FIRST_PERSON
	_apply_perspective()

func _apply_perspective() -> void:
	if camera == null:
		return

	if current_perspective == Perspective.FIRST_PERSON:
		camera.position = FIRST_PERSON_CAM_POS
		if character_model != null:
			_set_model_shadow_mode(character_model, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	else:
		camera.position = THIRD_PERSON_CAM_POS
		if character_model != null:
			_set_model_shadow_mode(character_model, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

func _set_model_shadow_mode(node: Node, mode: GeometryInstance3D.ShadowCastingSetting) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = mode
	for child in node.get_children():
		_set_model_shadow_mode(child, mode)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir = _get_movement_vector()
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if _inputs_changed() and net_entity:
		net_entity.actions.append(Packet.new(Packet.PacketType.MOVEMENT, {"move_x": direction.x, "move_y": direction.y, "move_z": direction.z}, net_entity))
	
	
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	_update_character_animation()

func _get_movement_vector() -> Vector2:
	if InputMap.has_action("move_left"):
		var dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if dir != Vector2.ZERO:
			return dir

	return Vector2.ZERO

func _inputs_changed():
	return Input.is_action_just_pressed("jump") or Input.is_action_just_released("jump") or Input.is_action_just_pressed("move_left") or Input.is_action_just_released("move_left") or Input.is_action_just_pressed("move_right")  or Input.is_action_just_released("move_right") or Input.is_action_just_pressed("move_forward") or Input.is_action_just_released("move_forward") or Input.is_action_just_pressed("move_backward") or Input.is_action_just_released("move_backward")

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
