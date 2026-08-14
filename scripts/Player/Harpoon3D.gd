class_name Harpoon3D extends Node3D

signal harpoon_hit(point: Vector3, normal: Vector3, collider: Node)
signal harpoon_retracted

enum State {
	READY,
	FLYING,
	LATCHED,
	RETRACTING
}

@export var shoot_speed: float = 40.0
@export var retract_speed: float = 50.0
@export var max_distance: float = 35.0
@export var latch_duration: float = 0.4
@export var rope_radius: float = 0.03

var current_state: int = State.READY

# References
@onready var launcher_mount: Node3D = $LauncherMount
@onready var tip_node: Node3D = $HarpoonTip
@onready var raycast: RayCast3D = $HarpoonTip/RayCast3D
@onready var rope_mesh_instance: MeshInstance3D = $RopeMesh

var immediate_mesh: ImmediateMesh
var rope_material: StandardMaterial3D

var shoot_dir: Vector3 = Vector3.FORWARD
var distance_traveled: float = 0.0
var latch_timer: float = 0.0
var original_tip_transform: Transform3D

func _ready() -> void:
	_ensure_nodes()
	if tip_node:
		original_tip_transform = tip_node.transform
	_setup_rope()

func _ensure_nodes() -> void:
	if not launcher_mount:
		launcher_mount = get_node_or_null("LauncherMount")
	if not tip_node:
		tip_node = get_node_or_null("HarpoonTip")
	if not raycast and tip_node:
		raycast = tip_node.get_node_or_null("RayCast3D")
	if not rope_mesh_instance:
		rope_mesh_instance = get_node_or_null("RopeMesh")

func _setup_rope() -> void:
	_ensure_nodes()
	if not rope_mesh_instance:
		rope_mesh_instance = MeshInstance3D.new()
		rope_mesh_instance.name = "RopeMesh"
		add_child(rope_mesh_instance)
	
	if not immediate_mesh:
		immediate_mesh = ImmediateMesh.new()
		rope_mesh_instance.mesh = immediate_mesh
	
	if not rope_material:
		rope_material = StandardMaterial3D.new()
		rope_material.albedo_color = Color(0.55, 0.38, 0.22)
		rope_material.roughness = 0.8
		rope_mesh_instance.material_override = rope_material


func shoot(aim_transform: Transform3D) -> bool:
	_ensure_nodes()
	if current_state != State.READY:
		if current_state == State.FLYING or current_state == State.LATCHED:
			start_retracting()
			return true
		return false
	
	current_state = State.FLYING
	distance_traveled = 0.0
	shoot_dir = -aim_transform.basis.z.normalized()
	
	if tip_node:
		tip_node.top_level = true
		tip_node.global_transform = aim_transform
	
	if raycast:
		raycast.enabled = true
		raycast.force_raycast_update()
	
	return true


func start_retracting() -> void:
	current_state = State.RETRACTING

func _physics_process(delta: float) -> void:
	match current_state:
		State.READY:
			if tip_node and tip_node.top_level:
				tip_node.top_level = false
				tip_node.transform = original_tip_transform
			_clear_rope()

		State.FLYING:
			var step: float = shoot_speed * delta
			var move_vec: Vector3 = shoot_dir * step
			
			# Check collision along move path using RayCast
			if raycast and is_inside_tree():
				raycast.target_position = Vector3(0, 0, -step - 0.5)
				raycast.force_raycast_update()

				
				if raycast.is_colliding():
					var hit_pt: Vector3 = raycast.get_collision_point()
					var hit_norm: Vector3 = raycast.get_collision_normal()
					var collider: Node = raycast.get_collider() as Node
					
					tip_node.global_position = hit_pt
					harpoon_hit.emit(hit_pt, hit_norm, collider)
					
				
					
					current_state = State.LATCHED
					latch_timer = latch_duration
					_update_rope()
					return

			
			tip_node.global_position += move_vec
			distance_traveled += step
			
			if distance_traveled >= max_distance:
				start_retracting()
			
			_update_rope()

		State.LATCHED:
			latch_timer -= delta
			if latch_timer <= 0.0:
				start_retracting()
			_update_rope()

		State.RETRACTING:
			var origin_pos: Vector3 = launcher_mount.global_position if launcher_mount else global_position
			var cur_pos: Vector3 = tip_node.global_position
			var target_vec: Vector3 = origin_pos - cur_pos
			var dist: float = target_vec.length()
			
			if dist <= retract_speed * delta + 0.3:
				current_state = State.READY
				tip_node.top_level = false
				tip_node.transform = original_tip_transform
				if raycast:
					raycast.enabled = false
				harpoon_retracted.emit()
				_clear_rope()
			else:
				var move_dir: Vector3 = target_vec.normalized()
				tip_node.global_position += move_dir * retract_speed * delta
				_update_rope()


func _clear_rope() -> void:

	if immediate_mesh:
		immediate_mesh.clear_surfaces()

func _update_rope() -> void:
	if not immediate_mesh or not launcher_mount or not tip_node:
		return
		
	immediate_mesh.clear_surfaces()
	
	var start_g: Vector3 = launcher_mount.global_position
	var end_g: Vector3 = tip_node.global_position
	
	var start_l: Vector3 = rope_mesh_instance.to_local(start_g)
	var end_l: Vector3 = rope_mesh_instance.to_local(end_g)
	
	_draw_rope_cylinder(start_l, end_l, rope_radius, 6)

func _draw_rope_cylinder(p1: Vector3, p2: Vector3, radius: float, sides: int) -> void:
	var dir: Vector3 = p2 - p1
	var len: float = dir.length()
	if len < 0.01:
		return
		
	var forward: Vector3 = dir.normalized()
	var up: Vector3 = Vector3.UP if abs(forward.y) < 0.9 else Vector3.RIGHT
	var side: Vector3 = forward.cross(up).normalized()
	var normal_up: Vector3 = side.cross(forward).normalized()
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, rope_material)
	
	for i in range(sides):
		var angle1: float = (float(i) / float(sides)) * TAU
		var angle2: float = (float(i + 1) / float(sides)) * TAU
		
		var offset1: Vector3 = (side * cos(angle1) + normal_up * sin(angle1)) * radius
		var offset2: Vector3 = (side * cos(angle2) + normal_up * sin(angle2)) * radius
		
		var v1: Vector3 = p1 + offset1
		var v2: Vector3 = p1 + offset2
		var v3: Vector3 = p2 + offset1
		var v4: Vector3 = p2 + offset2
		
		# Quad 1: v1, v2, v3
		immediate_mesh.surface_add_vertex(v1)
		immediate_mesh.surface_add_vertex(v2)
		immediate_mesh.surface_add_vertex(v3)
		
		# Quad 2: v2, v4, v3
		immediate_mesh.surface_add_vertex(v2)
		immediate_mesh.surface_add_vertex(v4)
		immediate_mesh.surface_add_vertex(v3)
		
	immediate_mesh.surface_end()
