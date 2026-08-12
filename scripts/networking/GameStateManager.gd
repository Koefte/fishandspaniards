class_name GameStateManager_Proprietary extends Node

var network_objects: Dictionary = {}
var networked_player_scene = preload("res://scenes/NetworkedPlayer.tscn")

func update_entities():
	for entity in network_objects.values():
		if entity.node_ref and is_instance_valid(entity.node_ref):
			entity.pos = entity.node_ref.global_position

func get_entire_state() -> Array:
	update_entities()
	return network_objects.values()

func get_objects() -> Dictionary:
	return network_objects

func get_object(id: int) -> NetEntity:
	return network_objects.get(id, null)

func start_game():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func register_object(entity: NetEntity) -> void:
	network_objects[entity.id] = entity
	if entity.entity_type == NetEntity.EntityType.NETWORKED_PLAYER and entity.node_ref == null:
		var instance = networked_player_scene.instantiate()
		entity.node_ref = instance
		if get_tree().current_scene:
			get_tree().current_scene.add_child(instance)
		instance.global_position = entity.pos

func set_movement(entity, move_vec: Vector3, new_pos: Vector3 = Vector3.ZERO) -> void:
	var target_id = entity.id if entity is NetEntity else entity
	if network_objects.has(target_id):
		var target: NetEntity = network_objects[target_id]
		target.dir = move_vec
		if target.node_ref and is_instance_valid(target.node_ref):
			if target.node_ref.has_method("push_network_input"):
				target.node_ref.push_network_input(move_vec, new_pos)
			elif new_pos != Vector3.ZERO:
				target.pos = new_pos
				target.node_ref.global_position = new_pos
			elif target.node_ref is CharacterBody3D:
				target.node_ref.velocity = move_vec
				target.pos = target.node_ref.global_position

func set_state_data(state_data: Dictionary) -> void:
	if not state_data.has("id"):
		return
	var id = state_data["id"]
	if not network_objects.has(id):
		var initial_pos = state_data.get("pos", Vector3(0, 1.03, 0))
		var new_entity = NetEntity.new(id, initial_pos, NetEntity.EntityType.NETWORKED_PLAYER, NetEntity.AuthorityRole.SIMULATED_PROXY)
		register_object(new_entity)

	var target: NetEntity = network_objects[id]
	if state_data.has("pos"):
		target.pos = state_data["pos"]
		if target.node_ref and is_instance_valid(target.node_ref) and target.authority_role != NetEntity.AuthorityRole.AUTONOMOUS_PROXY:
			if target.node_ref.has_method("push_network_input"):
				target.node_ref.push_network_input(target.dir if state_data.has("dir") else Vector3.ZERO, target.pos)
			else:
				target.node_ref.global_position = target.pos
	if state_data.has("dir"):
		target.dir = state_data["dir"]

func set_obj(entity) -> void:
	if entity is NetEntity:
		network_objects[entity.id] = entity
	elif entity is Dictionary:
		set_state_data(entity)
