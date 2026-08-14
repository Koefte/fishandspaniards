extends Node
class_name KrakenBoss

@export_group("Spawning Config")
@export var tentacle_scene: PackedScene
@export var ship_node: Node3D
@export var tentacle_base_point: Marker3D

@export_group("Targeting")
## The master list of all possible suction points on the ship
@export var all_suction_points: Array[Node3D] = []

var cur_tentacles: Array = []

# Our internal counter 'n'
var _current_suction_idx: int = 0
func _ready() -> void:
	spawn_tentacle()
## Spawns a tentacle and assigns it suction points n and n+1
func spawn_tentacle() -> void:
	# 1. Safety check: ensure we have at least 2 points left in the array for n and n+1
	if _current_suction_idx + 1 >= all_suction_points.size():
		push_warning("KrakenBoss: Not enough suction points left to spawn a tentacle!")
		return

	# 2. Instantiate the tentacle
	var tentacle: TentacleWrapper = tentacle_scene.instantiate() as TentacleWrapper
	if not tentacle:
		return
		
	# 3. Configure the tentacle BEFORE adding it to the tree
	# This ensures that when tentacle._ready() fires, all variables are properly set.
	tentacle.ship_node = ship_node
	tentacle.base_point = tentacle_base_point
	
	# Extract points n and n+1
	var point_n: Node3D = all_suction_points[_current_suction_idx]
	var point_n_plus_1: Node3D = all_suction_points[_current_suction_idx + 1]
	
	# Assign exactly these two points to the tentacle
	tentacle.suction_points = [point_n, point_n_plus_1]
	
	# 4. Add to the scene tree (This triggers _ready() and wrap_around_ship() automatically)
	add_child(tentacle)
	tentacle.wrap_around_ship()
	cur_tentacles.append(tentacle)
	
	# 5. Increment the internal counter 'n'
	# Use += 2 if you want the next tentacle to grab a completely fresh pair of points.
	# Use += 1 if you want the next tentacle to overlap (e.g., T1 gets 0,1. T2 gets 1,2).
	_current_suction_idx += 2
	
