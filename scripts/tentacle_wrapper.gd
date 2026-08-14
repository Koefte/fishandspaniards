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
@export var ship_node: Node3D
@export var base_point: Marker3D
## Array of N suction points on the ship (in sequence from base to tip)
@export var suction_points: Array[Node3D] = []

@export_group("Wrap Animation")
@export_range(0.0, 1.0) var wrap_progress: float = 0.0:
	set(val):
		wrap_progress = clamp(val, 0.0, 1.0)
		_update_wrapping_pose()

## Speed of wrapping/unwrapping transition
@export var wrap_speed: float = 1.2

@export_group("Procedural Wobble")
@export var enable_wobble: bool = true
@export var wobble_speed: float = 3.0
@export var wobble_intensity: float = 0.15

@export_group("Debug Controls")
@export var debug_toggle_suction: bool = false:
	set(val):
		if val:
			toggle_wrap()
			debug_toggle_suction = false

# Internal references
@onready var skeleton: Skeleton3D = $Tentacle_Armature/Skeleton3D
var bone_ids: Array[int] = []
var bone_names: Array[String] = []

# State Tracking
var is_wrapping: bool = false
var target_progress: float = 0.0
var _latched_points: Dictionary = {}
var _time_passed: float = 0.0

func _ready() -> void:
	# Snap to the anchor point so our global_position math matches
	if base_point:
		global_position = base_point.global_position
		
	_setup_skeleton_references()

func _setup_skeleton_references() -> void:
	bone_ids.clear()
	bone_names.clear()

	var num_bones: int = skeleton.get_bone_count()
	for i in range(num_bones):
		var b_name: String = skeleton.get_bone_name(i)
		if b_name.begins_with("Tentacle_Bone") or b_name.begins_with("Bone") or b_name.begins_with("Tentacle_"):
			bone_ids.append(i)
			bone_names.append(b_name)

	print("TentacleWrapper: Registered ", bone_ids.size(), " bones in skeleton.")

func _process(delta: float) -> void:
	_time_passed += delta
	
	# 1. Handle Smooth Wrapping Progress
	if not is_equal_approx(wrap_progress, target_progress):
		var step: float = wrap_speed * delta
		wrap_progress = move_toward(wrap_progress, target_progress, step)
		
		if wrap_progress >= 1.0 and is_wrapping:
			is_wrapping = false
			wrapping_completed.emit()
		elif wrap_progress <= 0.0 and not is_wrapping:
			unwrapping_completed.emit()

	# 2. Procedural Wobble (Updates the pose locally every frame based on time)
	if enable_wobble and wrap_progress > 0.0:
		_update_wrapping_pose()
		
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

func _check_suction_events() -> void:
	var active_pts: Array[Node3D] = suction_points
	var num_pts: int = active_pts.size()
	if num_pts == 0:
		return

	for idx in range(num_pts):
		var lock_threshold: float = float(idx + 1) / float(num_pts + 1)
		var is_latched: bool = _latched_points.get(idx, false)
		
		if wrap_progress >= lock_threshold and not is_latched:
			_latched_points[idx] = true
			suction_attached.emit(idx + 1, active_pts[idx])
			print("TentacleWrapper: [SUCTION LOCKED] Point ", idx + 1, " latched!")
		elif wrap_progress < (lock_threshold - 0.05) and is_latched:
			_latched_points[idx] = false
			suction_detached.emit(idx + 1, active_pts[idx])
			print("TentacleWrapper: [SUCTION RELEASED] Point ", idx + 1, " released!")

func _get_waypoints() -> Array[Vector3]:
	# The tentacle path MUST start at its own physical root
	var waypoints: Array[Vector3] = [global_position] 
	for pt in suction_points:
		if is_instance_valid(pt):
			waypoints.append(pt.global_position)
	return waypoints

func _evaluate_suction_path(t: float, waypoints: Array[Vector3]) -> Vector3:
	var num_pts: int = waypoints.size()
	if num_pts < 2: return waypoints[0]

	var num_segments: int = num_pts - 1
	if t <= 0.85:
		var t_scaled: float = (t / 0.85) * num_segments
		var seg_idx: int = clampi(int(t_scaled), 0, num_segments - 1)
		var u: float = t_scaled - seg_idx
		
		var p1: Vector3 = waypoints[seg_idx]
		var p2: Vector3 = waypoints[seg_idx + 1]
		
		var pre_a: Vector3 = waypoints[seg_idx - 1] if seg_idx > 0 else p1 - (p2 - p1)
		var post_b: Vector3 = waypoints[seg_idx + 2] if seg_idx + 2 < num_pts else p2 + (p2 - p1)

		# ORGANIC CURVE: Cubic interpolation creates the smooth spline
		return p1.cubic_interpolate(p2, pre_a, post_b, u)
	else:
		var u: float = (t - 0.85) / 0.15
		var last_pt: Vector3 = waypoints[num_pts - 1]
		var prev_pt: Vector3 = waypoints[num_pts - 2]
		var dir: Vector3 = (last_pt - prev_pt).normalized()
		return last_pt + dir * (u * prev_pt.distance_to(last_pt) * 0.3)

func _update_wrapping_pose() -> void:
	if not skeleton or bone_ids.is_empty(): return
	
	var waypoints: Array[Vector3] = _get_waypoints()
	if waypoints.size() < 2: return

	var num_bones: int = bone_ids.size()
	var ship_center: Vector3 = ship_node.global_position if is_instance_valid(ship_node) else waypoints[1]
	var current_time = Time.get_ticks_msec() / 1000.0 # Used for wobble

	for b_idx in range(num_bones):
		var bone_id: int = bone_ids[b_idx]
		var t: float = float(b_idx) / float(num_bones - 1)
		
		var target_pos: Vector3 = _evaluate_suction_path(t, waypoints)
		var next_target_pos: Vector3 = _evaluate_suction_path(min(t + 0.05, 1.0), waypoints)
		
		# 1. Safe Bone Forward (+Y)
		var bone_forward: Vector3 = (next_target_pos - target_pos)
		if bone_forward.length_squared() < 0.001:
			bone_forward = Vector3.UP
		bone_forward = bone_forward.normalized()

		# Target point on boat surface for suction cups to face towards
		var boat_target: Vector3 = target_pos.lerp(ship_center, 0.35)
		
		# 2. Direction to boat
		var to_boat_dir: Vector3 = (boat_target - target_pos)
		if to_boat_dir.length_squared() < 0.001:
			to_boat_dir = bone_forward.cross(Vector3.UP)
			if to_boat_dir.length_squared() < 0.001:
				to_boat_dir = bone_forward.cross(Vector3.RIGHT)
		to_boat_dir = to_boat_dir.normalized()

		# 3. Safe Side Vector (+X)
		var side_vector: Vector3 = bone_forward.cross(to_boat_dir)
		
		# If bone_forward and to_boat_dir are perfectly parallel, the cross product is zero.
		if side_vector.length_squared() < 0.001:
			side_vector = bone_forward.cross(Vector3.UP)
			if side_vector.length_squared() < 0.001:
				side_vector = bone_forward.cross(Vector3.RIGHT)
		side_vector = side_vector.normalized()

		# 4. Safe Belly Normal (+Z)
		# Crossing two normalized, perfectly perpendicular vectors guarantees a valid 3rd vector!
		var belly_normal: Vector3 = side_vector.cross(bone_forward).normalized()

		var world_target_basis: Basis = Basis(side_vector, bone_forward, belly_normal)
		var local_target_pos: Vector3 = skeleton.to_local(target_pos)
		
		# SPACE FIX 1: Strip scale from editor transform
		var skel_basis: Basis = skeleton.global_transform.basis.orthonormalized() 
		var local_target_basis: Basis = skel_basis.inverse() * world_target_basis

		# ORGANIC WOBBLE: Inject a sine wave into the rotation before applying
		if enable_wobble:
			var wobble = sin(current_time * wobble_speed + (b_idx * 0.5)) * wobble_intensity
			# Gently twist the bone around its local Z and X axes
			local_target_basis = local_target_basis.rotated(local_target_basis.z, wobble)
			local_target_basis = local_target_basis.rotated(local_target_basis.x, wobble * 0.5)

		var wrap_bone_transform: Transform3D = Transform3D(local_target_basis, local_target_pos)

		# SPACE FIX 2: Use global_rest so local spaces match perfectly
		var current_rest: Transform3D = skeleton.get_bone_global_rest(bone_id)
		var final_bone_transform: Transform3D = current_rest.interpolate_with(wrap_bone_transform, wrap_progress)

		skeleton.set_bone_global_pose_override(bone_id, final_bone_transform, wrap_progress, true)
