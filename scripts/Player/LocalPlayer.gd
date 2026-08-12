class_name LocalPlayer extends Player

enum Perspective { FIRST_PERSON, THIRD_PERSON }

@export var mouse_sensitivity: float = 0.0025
@export var current_perspective: Perspective = Perspective.FIRST_PERSON

@onready var camera_pivot: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

const FIRST_PERSON_CAM_POS: Vector3 = Vector3(0, 0.02, -0.22)
const THIRD_PERSON_CAM_POS: Vector3 = Vector3(0, 0.4, 2.8)

func _ready() -> void:
	super._ready()
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_perspective()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
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
	if current_perspective == Perspective.FIRST_PERSON:
		camera.position = FIRST_PERSON_CAM_POS
		if character_model:
			_set_model_shadow_mode(character_model, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	else:
		camera.position = THIRD_PERSON_CAM_POS
		if character_model:
			_set_model_shadow_mode(character_model, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

func _set_model_shadow_mode(node: Node, mode: GeometryInstance3D.ShadowCastingSetting) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = mode
	for child in node.get_children():
		_set_model_shadow_mode(child, mode)

func _physics_process(delta: float) -> void:
	var input_dir = _get_movement_vector()
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var jump_pressed = Input.is_action_just_pressed("jump")

	push_input_command({
		"direction": direction,
		"jump": jump_pressed
	})

	if net_entity and _inputs_changed():
		net_entity.actions.append(Packet.new(
			Packet.PacketType.KEY_INPUT,
			{
				"forward": Input.is_action_pressed("move_forward") if InputMap.has_action("move_forward") else false,
				"backward": Input.is_action_pressed("move_backward") if InputMap.has_action("move_backward") else false,
				"left": Input.is_action_pressed("move_left") if InputMap.has_action("move_left") else false,
				"right": Input.is_action_pressed("move_right") if InputMap.has_action("move_right") else false,
				"jump": jump_pressed,
				"rot_y": rotation.y,
			},
			net_entity
		))

	super._physics_process(delta)

func _get_movement_vector() -> Vector2:
	if InputMap.has_action("move_left"):
		var dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if dir != Vector2.ZERO:
			return dir
	return Vector2.ZERO

func _inputs_changed() -> bool:
	return Input.is_action_just_pressed("jump") or Input.is_action_just_released("jump") or Input.is_action_just_pressed("move_left") or Input.is_action_just_released("move_left") or Input.is_action_just_pressed("move_right") or Input.is_action_just_released("move_right") or Input.is_action_just_pressed("move_forward") or Input.is_action_just_released("move_forward") or Input.is_action_just_pressed("move_backward") or Input.is_action_just_released("move_backward")
