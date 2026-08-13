extends Node3D

class_name TentacleWrapper

## Emitted when a suction cup locks onto a suction point
signal suction_attached(point_index: int, point_node: Node3D)
## Emitted when a suction cup releases a suction point
signal suction_detached(point_index: int, point_node: Node3D)
## Emitted when the tentacle has fully wrapped around the ship
signal wrapping_completed
## Emitted when the tentacle has fully unwrapped and released
signal unwrapping_completed

@export_group("Target Settings")
## Target ship node containing suction points
@export var ship_node: Node3D
## First suction attachment point on ship
@export var suction_point_1: Node3D
## Second suction attachment point on ship
@export var suction_point_2: Node3D

@export_group("Wrap Animation")
## Current wrap progress from 0.0 (idle/free) to 1.0 (fully sucked & wrapped)
@export_range(0.0, 1.0) var wrap_progress: float = 0.0:
	set(val):
		wrap_progress = clamp(val, 0.0, 1.0)
		_update_wrapping_pose()

## Speed of wrapping/unwrapping transition
@export var wrap_speed: float = 1.2
## Auto start wrapping on scene load
@export var auto_wrap_on_start: bool = true
## Frequency of breathing/tugging motion when attached to ship
@export var breathe_frequency: float = 2.5
## Amplitude of breathing/tugging motion
@export var breathe_amplitude: float = 0.12

@export_group("Debug Controls")
## Toggle this checkbox in Inspector to trigger tentacle suction wrap/unwrap
@export var debug_toggle_suction: bool = false:
	set(val):
		if val:
			toggle_wrap()
			debug_toggle_suction = false

# Internal references
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var bone_ids: Array[int] = []
var bone_names: Array[String] = []
var bone_rest_transforms: Array[Transform3D] = []

var is_wrapping: bool = false
var target_progress: float = 0.0

# Suction status tracking
var _latched_p1: bool = false
var _latched_p2: bool = false
var _time_passed: float = 0.0

func _ready() -> void:
	_setup_skeleton_references()
	_setup_ship_references()
	
	if auto_wrap_on_start:
		wrap_around_ship()

func _setup_skeleton_references() -> void:
	var found_skel: Node = _find_child_of_type(self, "Skeleton3D")
	if found_skel and found_skel is Skeleton3D:
		skeleton = found_skel as Skeleton3D
	else:
		skeleton = null

	if not skeleton:
		push_error("TentacleWrapper: Skeleton3D node not found in tentacle scene!")
		return

	animation_player = _find_child_of_type(self, "AnimationPlayer") as AnimationPlayer

	bone_ids.clear()
	bone_names.clear()
	bone_rest_transforms.clear()

	var num_bones: int = skeleton.get_bone_count()
	for i in range(num_bones):
		var b_name: String = skeleton.get_bone_name(i)
		if b_name.begins_with("Tentacle_Bone") or b_name.begins_with("Bone") or b_name.begins_with("Tentacle_"):
			bone_ids.append(i)
			bone_names.append(b_name)
			bone_rest_transforms.append(skeleton.get_bone_rest(i))

	print("TentacleWrapper: Registered ", bone_ids.size(), " bones in skeleton.")

func _setup_ship_references() -> void:
	if not ship_node:
		ship_node = get_node_or_null("../ship-large") as Node3D
		if not ship_node:
			ship_node = get_node_or_null("../Ship") as Node3D

	if not ship_node:
		push_warning("TentacleWrapper: No ship_node assigned or found in scene parent!")
		return

	if not suction_point_1:
		suction_point_1 = ship_node.get_node_or_null("SuctionPoint1") as Node3D
		if not suction_point_1:
			suction_point_1 = ship_node.get_node_or_null("SuctionPoint_1") as Node3D

	if not suction_point_2:
		suction_point_2 = ship_node.get_node_or_null("SuctionPoint2") as Node3D
		if not suction_point_2:
			suction_point_2 = ship_node.get_node_or_null("SuctionPoint_2") as Node3D

	if not suction_point_1:
		suction_point_1 = Marker3D.new()
		suction_point_1.name = "SuctionPoint1"
		ship_node.add_child(suction_point_1)
		suction_point_1.position = Vector3(2.4, 1.2, 0.5)
		print("TentacleWrapper: Created default SuctionPoint1 on ship.")

	if not suction_point_2:
		suction_point_2 = Marker3D.new()
		suction_point_2.name = "SuctionPoint2"
		ship_node.add_child(suction_point_2)
		suction_point_2.position = Vector3(-1.8, 3.2, -1.5)
		print("TentacleWrapper: Created default SuctionPoint2 on ship.")

func _process(delta: float) -> void:
	_time_passed += delta
	
	if not is_equal_approx(wrap_progress, target_progress):
		var step: float = wrap_speed * delta
		wrap_progress = move_toward(wrap_progress, target_progress, step)
		
		if wrap_progress >= 1.0 and is_wrapping:
			is_wrapping = false
			wrapping_completed.emit()
		elif wrap_progress <= 0.0 and not is_wrapping:
			unwrapping_completed.emit()

	_check_suction_events()

## Begin smooth wrapping sequence around the ship
func wrap_around_ship() -> void:
	is_wrapping = true
	target_progress = 1.0
	print("TentacleWrapper: Wrapping around ship...")

## Release suction and return tentacle to free stance
func release_ship() -> void:
	is_wrapping = false
	target_progress = 0.0
	print("TentacleWrapper: Releasing ship...")

## Toggle wrapping state
func toggle_wrap() -> void:
	if target_progress > 0.5:
		release_ship()
	else:
		wrap_around_ship()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			toggle_wrap()

func _check_suction_events() -> void:
	if wrap_progress >= 0.5 and not _latched_p1:
		_latched_p1 = true
		suction_attached.emit(1, suction_point_1)
		print("TentacleWrapper: [SUCTION LOCKED] SuctionPoint1 latched!")
	elif wrap_progress < 0.45 and _latched_p1:
		_latched_p1 = false
		suction_detached.emit(1, suction_point_1)
		print("TentacleWrapper: [SUCTION RELEASED] SuctionPoint1 released!")

	if wrap_progress >= 0.85 and not _latched_p2:
		_latched_p2 = true
		suction_attached.emit(2, suction_point_2)
		print("TentacleWrapper: [SUCTION LOCKED] SuctionPoint2 latched!")
	elif wrap_progress < 0.80 and _latched_p2:
		_latched_p2 = false
		suction_detached.emit(2, suction_point_2)
		print("TentacleWrapper: [SUCTION RELEASED] SuctionPoint2 released!")

func _update_wrapping_pose() -> void:
	if not skeleton or bone_ids.is_empty():
		return

	if not suction_point_1 or not suction_point_2:
		return

	var num_bones: int = bone_ids.size()
	
	var p_base: Vector3 = global_position
	var p_suck1: Vector3 = suction_point_1.global_position
	var p_suck2: Vector3 = suction_point_2.global_position
	var ship_center: Vector3 = ship_node.global_position if ship_node else (p_suck1 + p_suck2) * 0.5

	var breathe_offset: Vector3 = Vector3.ZERO
	if wrap_progress > 0.3:
		var pulse: float = sin(_time_passed * breathe_frequency) * breathe_amplitude * wrap_progress
		breathe_offset = Vector3(0.0, pulse, 0.0)

	for b_idx in range(num_bones):
		var bone_id: int = bone_ids[b_idx]
		var t: float = float(b_idx) / float(num_bones - 1)
		
		# Position along suction path
		var target_pos: Vector3 = _evaluate_suction_path(t, p_base, p_suck1, p_suck2)
		target_pos += breathe_offset * (1.0 - abs(t - 0.5))

		# Determine next position to calculate bone forward direction
		var next_target_pos: Vector3
		if b_idx < num_bones - 1:
			var next_t: float = float(b_idx + 1) / float(num_bones - 1)
			next_target_pos = _evaluate_suction_path(next_t, p_base, p_suck1, p_suck2)
		else:
			var dir_past: Vector3 = (p_suck2 - p_suck1).normalized()
			next_target_pos = target_pos + dir_past * 0.5

		# Bone forward tangent vector in world space (+Y)
		var bone_forward: Vector3 = (next_target_pos - target_pos).normalized()
		if bone_forward.length_squared() < 0.001:
			bone_forward = Vector3.UP

		# Target point on boat surface for suction cups to face towards
		var boat_target: Vector3
		if t <= 0.5:
			boat_target = p_suck1
		elif t <= 0.85:
			var line_vec: Vector3 = p_suck2 - p_suck1
			var proj_factor: float = clamp((target_pos - p_suck1).dot(line_vec) / max(line_vec.length_squared(), 0.001), 0.0, 1.0)
			boat_target = p_suck1 + line_vec * proj_factor
			boat_target = boat_target.lerp(ship_center, 0.35)
		else:
			boat_target = p_suck2

		# Vector from bone towards boat surface
		var to_boat_dir: Vector3 = (boat_target - target_pos).normalized()
		if to_boat_dir.length_squared() < 0.001:
			to_boat_dir = -bone_forward.cross(Vector3.UP).normalized()

		# Project to_boat_dir perpendicular to bone_forward (suction cup belly normal)
		var belly_normal: Vector3 = to_boat_dir - (to_boat_dir.dot(bone_forward)) * bone_forward
		if belly_normal.length_squared() < 0.001:
			belly_normal = Vector3.UP - (Vector3.UP.dot(bone_forward)) * bone_forward
		belly_normal = belly_normal.normalized()

		# Form orthonormal world basis (Side = +X, Forward = +Y, Belly = +Z)
		var side_vector: Vector3 = bone_forward.cross(belly_normal).normalized()
		belly_normal = side_vector.cross(bone_forward).normalized()

		var world_target_basis: Basis = Basis(side_vector, bone_forward, belly_normal)

		# Convert to skeleton local space
		var local_target_pos: Vector3 = skeleton.to_local(target_pos)
		var skel_basis: Basis = skeleton.global_transform.basis
		var local_target_basis: Basis = skel_basis.inverse() * world_target_basis

		var wrap_bone_transform: Transform3D = Transform3D(local_target_basis, local_target_pos)

		# Interpolate smoothly between rest pose and boat-facing wrap pose
		var current_rest: Transform3D = skeleton.get_bone_rest(bone_id)
		var final_bone_transform: Transform3D = current_rest.interpolate_with(wrap_bone_transform, wrap_progress)

		skeleton.set_bone_global_pose_override(bone_id, final_bone_transform, wrap_progress, true)

func _evaluate_suction_path(t: float, p_base: Vector3, p_suck1: Vector3, p_suck2: Vector3) -> Vector3:
	if t <= 0.5:
		return p_base.lerp(p_suck1, t / 0.5)
	elif t <= 0.85:
		return p_suck1.lerp(p_suck2, (t - 0.5) / 0.35)
	else:
		var dir: Vector3 = (p_suck2 - p_suck1).normalized()
		var dist: float = p_suck1.distance_to(p_suck2)
		return p_suck2 + dir * (((t - 0.85) / 0.15) * dist * 0.3)

func _find_child_of_type(parent: Node, type_name: String) -> Node:
	for child in parent.get_children():
		if child.is_class(type_name) or child.get_class() == type_name:
			return child
		var res: Node = _find_child_of_type(child, type_name)
		if res:
			return res
	return null
