class_name NetEntity extends RefCounted

enum AuthorityRole {
	HOST_AUTHORITY,
	AUTONOMOUS_PROXY,
	SIMULATED_PROXY
}

enum EntityType {
	PLAYER,
	NETWORKED_PLAYER,
	WORLD_OBJECT
}

var id: int
var pos: Vector3
var dir: Vector3
var authority_role: AuthorityRole = AuthorityRole.SIMULATED_PROXY
var entity_type: EntityType = EntityType.WORLD_OBJECT
var actions: Array = []
var node_ref: Node3D = null

func _init(p_id: int = 0, p_pos: Vector3 = Vector3.ZERO, p_type: EntityType = EntityType.WORLD_OBJECT, p_role: AuthorityRole = AuthorityRole.SIMULATED_PROXY) -> void:
	id = p_id
	pos = p_pos
	entity_type = p_type
	authority_role = p_role

func poll_actions() -> Array:
	var current_actions = actions.duplicate()
	actions.clear()
	return current_actions
