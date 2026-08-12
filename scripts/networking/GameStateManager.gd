class_name GameStateManager_Proprietary extends Node

var network_objects: Dictionary = {}
var networked_player_scene = preload("res://scenes/NetworkedPlayer.tscn") if FileAccess.file_exists("res://scenes/NetworkedPlayer.tscn") else null

func update_entities():
	pass

func get_entire_state() -> Array:
	return network_objects.values()

func get_objects() -> Dictionary:
	return network_objects

func get_object(id: int) -> NetEntity:
	return network_objects.get(id, null)

func start_game():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func register_object(entity: NetEntity) -> void:
	network_objects[entity.id] = entity
	if entity.entity_type == NetEntity.EntityType.NETWORKED_PLAYER and networked_player_scene:
		var instance = networked_player_scene.instantiate()
		entity.node_ref = instance
		if get_tree().current_scene:
			get_tree().current_scene.add_child(instance)

func set_movement(entity, move_vec: Vector3) -> void:
	var target_id = entity.id if entity is NetEntity else entity
	if network_objects.has(target_id):
		var target: NetEntity = network_objects[target_id]
		target.dir = move_vec
		if target.node_ref and target.node_ref is CharacterBody3D:
			target.node_ref.velocity = move_vec

func set_state_data(state_data: Dictionary) -> void:
	if not state_data.has("id"):
		return
	var id = state_data["id"]
	if network_objects.has(id):
		var target: NetEntity = network_objects[id]
		if state_data.has("pos"):
			target.pos = state_data["pos"]
			if target.node_ref:
				target.node_ref.global_position = target.pos
		if state_data.has("dir"):
			target.dir = state_data["dir"]

func set_obj(entity) -> void:
	if entity is NetEntity:
		network_objects[entity.id] = entity
	elif entity is Dictionary:
		set_state_data(entity)
