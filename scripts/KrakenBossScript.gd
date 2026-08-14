extends Node
class_name KrakenBoss

@export var tentacle_scene: PackedScene = preload("res://scenes/kraken_tentacle.tscn")
@export var tentacle_paths: Array[Path3D] = []

func _ready() -> void:
	# Automatically collect child Path3D nodes if array is empty
	if tentacle_paths.is_empty():
		for child in get_children():
			if child is Path3D:
				tentacle_paths.append(child)
	print("KrakenBoss initialized with ", tentacle_paths.size(), " tentacle paths along the ship.")
	for i in 6:
		generate_tentacle()

func generate_tentacle() -> Node3D:
	if tentacle_paths.is_empty():
		push_warning("KrakenBoss: No Path3D curves available to generate tentacle.")
		return null

	var chosen_path: Path3D = tentacle_paths.pick_random()
	if not chosen_path or not tentacle_scene:
		push_warning("KrakenBoss: Selected path or tentacle scene is invalid.")
		return null

	var tentacle_instance = tentacle_scene.instantiate()
	add_child(tentacle_instance)

	# Match transform to chosen path
	tentacle_instance.global_transform = chosen_path.global_transform

	var internal_path: Path3D = tentacle_instance.get_node_or_null("Path3D")
	var path_mesh = tentacle_instance.get_node_or_null("PathMesh3D")

	if internal_path and chosen_path.curve:
		internal_path.curve = chosen_path.curve.duplicate()

	if path_mesh and internal_path:
		path_mesh.set("path_3d", internal_path.get_path())

	print("KrakenBoss generated a tentacle at path: ", chosen_path.name)
	return tentacle_instance
